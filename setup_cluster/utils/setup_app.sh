set -eu

deploy_application() {
    gcloud compute scp --zone $ZONE utils/servers.yaml $DEPLOYMENT_NAME-k8s-controller:~/ &>> $LOGFILE &
    gcloud compute ssh --zone $ZONE $DEPLOYMENT_NAME-k8s-controller --command="sudo kubectl apply -f servers.yaml" &>> $LOGFILE &
}


deploy_application &>> $LOGFILE &
loading $! "--> deploy api-server and core-server k8s pods and services manifest"
