# Attempt to grab your current project. If this fails manually set the PROJECT_ID variable to your project id.
export PROJECT_ID=$(gcloud config get-value project)

# Same, set manually if this fails, for example us-central1-a
export ZONE=$(gcloud config get-value compute/zone)
