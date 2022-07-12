# Submit our multiarch build to Cloud Build with a specific tag.
gcloud builds submit --substitutions TAG_NAME=1.1,_LABUID=${LABUID}
