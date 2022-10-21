# Create a basic GKE cluster with 10 nodes to prescale the control plane.
gcloud container clusters create multiarch-${LABUID} \
    --machine-type=n1-standard-4 \
    --num-nodes=10 \
    --no-enable-shielded-nodes \
    --cluster-version=latest \
    --zone=${ZONE}
