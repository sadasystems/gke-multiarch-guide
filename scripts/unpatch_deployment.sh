# Patch deployment to remove nodeselector 
kubectl patch deployment envspitter --patch-file=k8s-objects/envspitter-dp-patch-noselector.yaml
