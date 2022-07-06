# Grab the first external IP
export EXTERNAL_IP=$(kubectl get svc envspitter --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Hit the app a few times forever
watch -n 1 curl -s  http://${EXTERNAL_IP}/
