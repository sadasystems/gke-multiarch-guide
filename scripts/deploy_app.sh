# Create a Deployment for our app
envsubst < k8s-objects/envspitter-dp.yaml | kubectl apply -f -

# Create a Loadbalancer service for our app
kubectl apply -f k8s-objects/envspitter-svc.yaml
