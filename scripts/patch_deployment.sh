# Detect system architecture
export SYSTEM_ARCH=$(uname -m)

# Patch deployment to only run on your local machine's architecture
kubectl patch deployment envspitter --patch-file=k8s-objects/envspitter-dp-patch-${SYSTEM_ARCH}.yaml
