#!/bin/bash

# sleep in case the volume is still being mounted by GCP
sleep 120

# add mount steps here
lsblk
sudo mkfs.ext4 /dev/sdb
sudo mkdir /mnt/data
sudo mount /dev/sdb /mnt/data
# add line in /etc/fstab
echo -e "/dev/sdb /mnt/data ext4 defaults 0 0" >> /etc/fstab

# setup db services - postgres, mongodb, redis (sudo apt stuff)
# -- mongodb
    sudo apt install software-properties-common gnupg apt-transport-https ca-certificates -y
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc |  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    sudo echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt update
    sudo apt install mongodb -y
    sudo systemctl start mongodb
    sudo systemctl enable mongodb

    sudo mongo admin --eval 'db.createUser({ user: "admin", pwd: "", roles: ["root"] })'

# -- postgres
    sudo apt install postgresql postgresql-contrib -y
    sudo -u postgres psql -c "CREATE USER admin WITH PASSWORD ''; ALTER USER admin WITH SUPERUSER;"
    hbafile_path=$(sudo -u postgres psql -c "SHOW hba_file;" | awk 'NR==3')
    hbafile_path="${hbafile_path#"${hbafile_path%%[![:space:]]*}"}"
    temp_file=$(mktemp)
    echo "local   all             admin                                   md5" | cat - "$hbafile_path" > "$temp_file"
    mv "$temp_file" "$hbafile_path"

# -- redis
    sudo apt install redis-server -y
    sudo systemctl enable redis-server
    sudo systemctl start redis-server

