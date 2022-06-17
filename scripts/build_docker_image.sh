# Build the docker image
docker build . -t us-docker.pkg.dev/${PROJECT_ID}/envspitter/envspitter:${TAG_NAME}

# Push the docker image
docker push  us-docker.pkg.dev/${PROJECT_ID}/envspitter/envspitter:${TAG_NAME}
