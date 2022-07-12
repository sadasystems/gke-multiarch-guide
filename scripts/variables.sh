# Attempt to grab your current project. If this fails manually set the PROJECT_ID variable to your project id.
export PROJECT_ID=$(gcloud config get-value project)

# We'll be working in us-central1-a
export ZONE=us-central1-a

# A unique ID based on our username to uniquely identify our lab resources
export LABUID=$(shasum <<< $USER | cut -c1-8)
