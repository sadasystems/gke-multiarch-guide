 gcloud container node-pools create arm --cluster-1 \
                                        --machine-type=t2a-standard-4 \
                                        --enable-gvnic \
                                        --node-version=1.23.6-gke.1700 \
                                        --no-enable-shielded-nodes
