# Build the docker image
docker build . -t us-docker.pkg.dev/${PROJECT_ID}/envspitter-${USER}/envspitter:1.0

# Push the docker image
docker push us-docker.pkg.dev/${PROJECT_ID}/envspitter-${USER}/envspitter:1.0
