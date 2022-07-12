# Create a Docker Artifact Repository in multiple redundant US regions.
gcloud artifacts repositories create envspitter-${LABUID} --repository-format=docker --location=us

# Log on to Google's docker registry
gcloud auth configure-docker us-docker.pkg.dev
