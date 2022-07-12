# Delete the GKE cluster
gcloud container clusters delete multiarch-${LABUID} --zone=${ZONE}

# Delete the Docker registry
gcloud artifacts repositories delete envspitter-${LABUID} --location=us
