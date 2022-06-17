changequote(`{{', `}}')
# Working with ARM64 machines on Google Kubernetes Engine

Google has recently announced their ARM CPU machines types (t2a). Kubernetes has had support for ARM machines for some time, however running a mixed architexture cluster can pose some challenges.

This guide will cover how to run CPU-specific workloads on mixed clusters, and an example of how to make workloads CPU-agnostic.

undivert({{toc.md}})

## Prerequisites

## Provisioning a Kubernetes Cluster

First we'll provision a Google Kubernetes Engine (GKE) cluster:
```bash
undivert({{scripts/create_cluster.sh})
```

Next we'll add a node pool of `t2a-standard-4` machines, Google's ARM offering.
```bash
undivert({{scripts/create_nodepool.sh})
```

Let's check on our nodes
```
$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE   VERSION
gke-multiarch-arm-9afe67fe-cpxn            Ready    <none>   31m   v1.23.6-gke.1700
gke-multiarch-arm-9afe67fe-g0db            Ready    <none>   31m   v1.23.6-gke.1700
gke-multiarch-arm-9afe67fe-hkn9            Ready    <none>   31m   v1.23.6-gke.1700
gke-multiarch-default-pool-7efc8129-7qgw   Ready    <none>   33m   v1.23.6-gke.1700
gke-multiarch-default-pool-7efc8129-9lw5   Ready    <none>   33m   v1.23.6-gke.1700
gke-multiarch-default-pool-7efc8129-zf0n   Ready    <none>   33m   v1.23.6-gke.1700
```

## Building and Deploying our App

```bash
undivert({{scripts/build_docker_image.sh}}
```

```bash
undivert({{scripts/deploy_app.sh}}
```

### Examining our Deployment

uh oh, errors

```
$ kubectl get pod  -o wide
NAME                         READY   STATUS             RESTARTS     AGE   IP          NODE                                       NOMINATED NODE   READINESS GATES
envspitter-899c74bd9-77zsw   0/1     CrashLoopBackOff   1 (5s ago)   8s    10.76.4.4   gke-multiarch-arm-9afe67fe-hkn9            <none>           <none>
envspitter-899c74bd9-9pzmf   0/1     CrashLoopBackOff   1 (5s ago)   8s    10.76.3.3   gke-multiarch-arm-9afe67fe-g0db            <none>           <none>
envspitter-899c74bd9-cl75j   0/1     CrashLoopBackOff   1 (5s ago)   9s    10.76.3.2   gke-multiarch-arm-9afe67fe-g0db            <none>           <none>
envspitter-899c74bd9-cpgrp   1/1     Running            0            8s    10.76.2.4   gke-multiarch-default-pool-7efc8129-zf0n   <none>           <none>
envspitter-899c74bd9-gm78h   0/1     CrashLoopBackOff   1 (4s ago)   8s    10.76.5.4   gke-multiarch-arm-9afe67fe-cpxn            <none>           <none>
envspitter-899c74bd9-mmwz8   1/1     Running            0            8s    10.76.0.5   gke-multiarch-default-pool-7efc8129-7qgw   <none>           <none>
envspitter-899c74bd9-p5fxk   1/1     Running            0            8s    10.76.2.5   gke-multiarch-default-pool-7efc8129-zf0n   <none>           <none>
envspitter-899c74bd9-prjfv   0/1     CrashLoopBackOff   1 (4s ago)   8s    10.76.5.3   gke-multiarch-arm-9afe67fe-cpxn            <none>           <none>
envspitter-899c74bd9-qtd4n   1/1     Running            0            8s    10.76.1.9   gke-multiarch-default-pool-7efc8129-9lw5   <none>           <none>
envspitter-899c74bd9-rjq7w   0/1     CrashLoopBackOff   1 (5s ago)   8s    10.76.4.5   gke-multiarch-arm-9afe67fe-hkn9            <none>           <none>
```

Pick a pod from the deployment and examine the logs.

```
$ kubectl logs envspitter-899c74bd9-77zsw
exec /app/envspitter: exec format error
``` 

It turns out our local machine didn't quite match the architecture of some of our nodes.

### Fixing the Deployment

A quick fix would be to make our app only run on compatible machines. Fortunately the nodes are labeled with their CPU architecture, so we can use a simple node selector to restrict pods to compatible nodes:

```yaml
undivert({{k8s-objects/envspitter-dp-patch-x86_64.yaml}})
```

Let's patch the deployment with the appropriate snippet.

```bash
undivert({{scripts/patch_deployment.sh}}
```

Now let's check on our Pods.

```
NAME                          READY   STATUS    RESTARTS   AGE   IP           NODE                                       NOMINATED NODE   READINESS GATES
envspitter-6474f96d8c-785lm   0/1     Pending   0          18s   <none>       <none>                                     <none>           <none>
envspitter-6474f96d8c-7tldz   1/1     Running   0          19s   10.76.0.8    gke-multiarch-default-pool-7efc8129-7qgw   <none>           <none>
envspitter-6474f96d8c-9k465   1/1     Running   0          21s   10.76.0.6    gke-multiarch-default-pool-7efc8129-7qgw   <none>           <none>
envspitter-6474f96d8c-9r7lt   1/1     Running   0          20s   10.76.1.11   gke-multiarch-default-pool-7efc8129-9lw5   <none>           <none>
envspitter-6474f96d8c-jx4kq   1/1     Running   0          19s   10.76.1.12   gke-multiarch-default-pool-7efc8129-9lw5   <none>           <none>
envspitter-6474f96d8c-l5xpg   1/1     Running   0          21s   10.76.1.10   gke-multiarch-default-pool-7efc8129-9lw5   <none>           <none>
envspitter-6474f96d8c-pnsz7   1/1     Running   0          19s   10.76.2.7    gke-multiarch-default-pool-7efc8129-zf0n   <none>           <none>
envspitter-6474f96d8c-scbdl   1/1     Running   0          21s   10.76.2.6    gke-multiarch-default-pool-7efc8129-zf0n   <none>           <none>
envspitter-6474f96d8c-vfhff   1/1     Running   0          19s   10.76.2.8    gke-multiarch-default-pool-7efc8129-zf0n   <none>           <none>
envspitter-6474f96d8c-x4bvl   1/1     Running   0          20s   10.76.0.7    gke-multiarch-default-pool-7efc8129-7qgw   <none>           <none>
```
Well, we got our pods off the incompatible nodes, but some of the Pods are stuck pending because there aren't enough nodes compatible with our workload. Let's get it compatible.

## Multiarch Builds

Docker images are actually a manifest that can consist of one or more images. If the container image manifest is built properly, clients will simply run the appropriate image for the host's CPU architecture and OS. Docker's buildx tool makes this easy, however Cloud Build makes it easier.

### Create our registry

We'll need somewhere to host our image, so let's create a new Artifact Repository.

```bash
undivert({{scripts/create_repository.sh}}
```

### Submit our build

Now we submit our build with the included [cloudbuild.yaml](cloudbuild.yaml)

```bash
undivert({{scripts/submit_build.sh}}
```bash

After the build completes, there should be images for amd64 and arm64 in the manifest for the envspitter:1.1 image.

### Updating our deployment

Let's update our Deployment with the new image.

```bash
undivert({{scripts/update_deployment_image.sh}}
```

While the deployment has a new image that is compatible with both ARM64 and AMD64, we still have a node restriction in place. We must remove the node selector to get pods to schedule everywhere.

```bash
undivert({{scripts/unpatch_deployment.sh}}
```
woop.
