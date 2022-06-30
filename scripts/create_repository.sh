# Create a Docker Artifact Repository in multiple redundant US regions.
gcloud artifacts repositories create envspitter-${USER} --repository-format=docker --location=us
