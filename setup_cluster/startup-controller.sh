#!/bin/bash

# install k8s dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io
sudo systemctl enable docker.service
sudo apt install -y apt-transport-https curl
curl -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update

# install k8s core
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# create k8s cluster
sudo kubeadm init --pod-network-cidr 192.168.0.0/16

# move kube config to root home dir
mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config

# move kube config to users home dir
mkdir -p /home/sakshi-dhingra/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/sakshi-dhingra/.kube/config
sudo chown sakshi-dhingra:sakshi-dhingra /home/sakshi-dhingra/.kube/config

# create calico pods to support CNI and coredns
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/custom-resources.yaml -O
kubectl create -f custom-resources.yaml
kubectl get pods --all-namespaces

