# Create a basic GKE cluster with 3 nodes.
gcloud container clusters create multiarch-${USER} --machine-type=n1-standard-4 \
                                           --num-nodes=3 \
                                           --no-enable-shielded-nodes \
                                           --cluster-version=1.23.6-gke.1700
