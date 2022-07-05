# Delete the GKE cluster
gcloud container clusters delete multiarch-${USER} --zone=${ZONE}

# Delete the Docker registry
gcloud artifacts repositories delete envspitter-${USER} --location=us
