### Manual Setup

1. Setup up network objects and firewall rules in GCP
2. Create 1 control node, and 2 worker VMs
3. SSH to VMs and configure Kubernetes dependencies
4. Initialize cluster on Control node
5. Join workers to cluster
6. Setup Container networking using Calico (essential)

All steps work as expected as of Dec 5, 2023

### Prerequisites
1. Active GCP account
2. Gcloud CLI is setup on your personal machine

---

### Steps

#### create vpc
```
gcloud compute networks create ec1-vpc --project=ecocompass-project --subnet-mode=custom --mtu=1460 --bgp-routing-mode=regional
```

#### create network
```
gcloud compute networks subnets create ec1-subnet-main --project=ecocompass-project --description=default\ network --range=10.10.0.0/24 --stack-type=IPV4_ONLY --network=ec1-vpc --region=europe-west1
```
#### setup firewall rules to allow internal k8s comm
```
gcloud compute --project=ecocompass-project firewall-rules create ec1-fw-k8s-internal --direction=INGRESS --priority=1000 --network=ec1-vpc --action=ALLOW --rules=tcp,udp,icmp,ipip --source-ranges=10.10.0.0/24

gcloud compute --project=ecocompass-project firewall-rules create ec1-fw-k8s-external --direction=INGRESS --priority=1000 --network=ec1-vpc --action=ALLOW --rules=tcp:22,tcp:6443,icmp --source-ranges=0.0.0.0/0
```
#### reserve ip
```
gcloud compute addresses create ec1-k8s-public-ip --region $(gcloud config get-value compute/region)
```
#### create control node

```
gcloud compute instances create ec1-k8s-controller \
	--async \
	--project=ecocompass-project \
	--zone=europe-west1-b \
	--machine-type=e2-custom-medium-4096 \
	--scopes=compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
	--boot-disk-size 32GB \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --can-ip-forward \
	--private-network-ip 10.10.0.21 \
	--subnet ec1-subnet-main
```
#### create worker node
```
gcloud compute instances create ec1-k8s-worker-0 \
	--async \
	--project=ecocompass-project \
	--zone=europe-west1-b \
	--machine-type=e2-custom-medium-4096 \
	--scopes=compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
	--boot-disk-size 32GB \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --can-ip-forward \
	--private-network-ip 10.10.0.31 \
	--subnet ec1-subnet-main
	
gcloud compute instances create ec1-k8s-worker-1 \
	--async \
	--project=ecocompass-project \
	--zone=europe-west1-b \
	--machine-type=e2-custom-medium-4096 \
	--scopes=compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
	--boot-disk-size 32GB \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --can-ip-forward \
	--private-network-ip 10.10.0.32 \
	--subnet ec1-subnet-main
```


---
### SSH
```
gcloud compute ssh ec1-k8s-controller
gcloud compute ssh ec1-k8s-worker-0
gcloud compute ssh ec1-k8s-worker-1
```
### Setup K8s
#### install k8s services
```
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io
sudo systemctl enable docker.service
sudo apt install -y apt-transport-https curl
curl -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```
#### init controller
```
sudo kubeadm init --pod-network-cidr 192.168.0.0/16
```

#### join workers to cluster
*Note: copy this command from the output of 'kubeadm init'*
```
sudo kubeadm join 10.10.0.21:6443 --token <> --discovery-token-ca-cert-hash <>
```

#### setup kubectl on controller
```
mkdir -p $HOME/.kube  
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config  
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
#### setup calico for Container networking
```
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/custom-resources.yaml -O
kubectl create -f custom-resources.yaml
```
#### check all pods - they should be in READY state
```
kubectl get pods --all-namespaces
```