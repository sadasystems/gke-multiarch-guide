# Add a node pool to our cluster. t2a machines must use Google Virtual NIC
gcloud container node-pools create arm \
    --cluster=multiarch-${LABUID} \
    --machine-type=t2a-standard-4 \
    --enable-gvnic \
    --num-nodes=3 \
    --node-version=1.23.6-gke.1700 \
    --zone=${ZONE}

# Cluster should be warmed up, resize default pool down to 3 nodes.
gcloud container clusters resize multiarch-${LABUID} \
    --node-pool=default-pool \
    --num-nodes=3 \
    --zone=${ZONE}
