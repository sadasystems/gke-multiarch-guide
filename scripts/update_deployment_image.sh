# Update the container image in our deployment to 1.1
kubectl set image deployment/envspitter envspitter=us-docker.pkg.dev/${PROJECT_ID}/envspitter-${USER}/envspitter:1.1
