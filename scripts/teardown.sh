# Delete the GKE cluster
gcloud container clusters delete multiarch-${USER}

# Delete the Docker registry
gcloud artifacts repositories delete envspitter-${USER} --location=us
