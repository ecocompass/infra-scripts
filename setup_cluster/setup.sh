export GCP_PROJECT_NAME="ecocompass-sakshi"
export DEPLOYMENT_NAME="ec-23032024"
export REGION="europe-west2"
export ZONE="europe-west2-a"
export VPC_CIDR="10.10.0.0/24"
export LOGFILE="run-$(date +%Y%m%d%H%M%S).log"

set -eu

loading() {
  echo -n "$2 "
  list=("⡿" "⣟" "⣯" "⣷" "⣾" "⣽" "⣻" "⢿")
  tput civis
  while kill -0 $1 &> /dev/null
  do
    for s in "${list[@]}"; do
      tput setaf $(shuf -i 1-10 -n 1)
      echo -n "$s"
      sleep 0.1
      echo -ne "\b"
    done
  done
  tput sgr0
  tput cnorm
  echo
}
export -f loading

echo -e "Logging all output to file $LOGFILE\n"

echo "--> creating deployment.tfvars"
cat > deployment.tfvars <<EOF
gcp_project_name = "$GCP_PROJECT_NAME"
deployment_name  = "$DEPLOYMENT_NAME"
region           = "$REGION"
zone             = "$ZONE"
vpc_cidr         = "$VPC_CIDR"
EOF

terraform apply -var-file=deployment.tfvars -auto-approve &>> $LOGFILE &
loading $! "--> deploying using terraform"

sleep 300 &
loading $! "--> sleeping for 5 minutes : wait for controller to setup cluster"

gcloud compute ssh --zone $ZONE $DEPLOYMENT_NAME-k8s-controller --command="sudo kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml" &>> $LOGFILE &
loading $! "--> configure calico CRDs"
gcloud compute ssh --zone $ZONE $DEPLOYMENT_NAME-k8s-controller --command="sudo kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/custom-resources.yaml" &>> $LOGFILE &
loading $! "--> deploy calico pods"

sleep 60 &
loading $! "--> sleeping for 1 minute : wait for calico pods to come up"

echo "--> fetch cluster join command from controller"
cluster_join_command=$(gcloud compute ssh --zone $ZONE $DEPLOYMENT_NAME-k8s-controller --command="sudo kubeadm token create --print-join-command")
echo "$cluster_join_command" >> $LOGFILE

echo "--> join workers to cluster"
instance_names=$(gcloud compute instances list --zones $ZONE --format="value(name)" --filter="name~^$DEPLOYMENT_NAME-k8s-worker")

for instance in $instance_names; do
  gcloud compute ssh --zone $ZONE $instance --command="sudo $cluster_join_command" &>> $LOGFILE &
  loading $! "  joining $instance"
done

# bash utils/setup_app.sh