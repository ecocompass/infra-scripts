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

### Deploying
1. Edit setup.sh and modify the global variables on top
2. Execute script using `bash setup.sh`
    - script will provide name of the log file which you can track `tail -f run-*.log`

### Destroying cluster
1. `terraform destroy -var-file=deployment.tfvars -auto-approve`