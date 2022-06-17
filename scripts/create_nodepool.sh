# Add a node pool to our cluster. t2a machines only support Google Virtual NIC

 gcloud container node-pools create arm --cluster=multiarch \
                                        --machine-type=t2a-standard-4 \
                                        --enable-gvnic \
                                        --num-nodes=3 \
                                        --node-version=1.23.6-gke.1700
