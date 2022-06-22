# Delete the GKE cluster
gcloud container clusters delete multiarch

# Delete the Docker registry
gcloud artifacts repositories delete envspitter --location=us
