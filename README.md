# Infra Scripts
All infrastructure scripts/automation will be organized here.

## Setup Cluster
1. Deploy networking, worker, controller VMs and setup application load balancer object to front data traffic.
2. Setup k8s on controller and worker VMs
3. Deploy application manifest on cluster

### Prerequisites
- gcloud cli tool
- gcloud ssh keys
- terraform

### Prepping GCP account
Run this command locally to provide access to API client library.
```
gcloud auth application-default login
```

### Deploying
1. Edit setup.sh and modify the global variables on top
2. Execute script using `bash setup.sh`
    - script will provide name of the log file which you can track `tail -f run-*.log`

### Destroying cluster
1. `terraform destroy -var-file=deployment.tfvars -auto-approve`

### Postgres config
- access psql cli
    ```
    sudo -u postgres psql
    ```
- create pastav user
    ```
    CREATE USER pastav WITH PASSWORD '***'; ALTER USER pastav WITH SUPERUSER;
    ```
- change port and listen on all addresses `sudo -u postgres vim /etc/postgresql/12/main/postgresql.conf`
    ```
    listen_addresses = '*'
    port = 8086
    ```
- allow login for user and from all IPs `sudo -u postgres vim /etc/postgresql/12/main/pg_hba.conf`
    ```
    local   all             pastav                                  md5
    host    all             all             0.0.0.0/0               md5
    ```

### Redis config
- add password `sudo -u redis vim /etc/redis/redis.conf`
    - add `requirepass ***`
    - change `bind 127.0.0.1 ::1` to `bind 0.0.0.0`

### Miscellaneous
```
(routing-engine)
(api-server)                                         (redis) (postgresql)
----------------- k8s --------------                 -------- DB --------
[WORKER]                 [CONTROLLER]                      [DB VM]
 
+++++++++++++++++++++++++++++++++++ FW ++++++++++++++++++++++++++++++++++
================================GCP======================================
 
 
             80      30000
user_req -> ALB -> [WORKER]
			6969                 8080                   8080
                     (api-server) -> $routing-engine-svc$ -> (routing-enging)
```

#### check open ports
```
sudo ss -tlnp
```

#### check services
```
sudo systemctl status postgresql
sudo systemctl status redis
```

#### kubectl get details
```
kubectl get pods
kubectl get svc
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

#### redeploy if docker image is updated
```
kubectl delete -f servers.yaml
kubectl apply -f servers.yaml
```