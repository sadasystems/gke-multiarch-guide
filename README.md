
# Working with ARM64 Machines on Google Kubernetes Engine

Google has recently announced their ARM CPU machines types (t2a). Kubernetes has had support for ARM machines for some time(as evidenced by the myriad Pi clusters out there), however running a mixed architexture cluster can pose some challenges.

This guide will cover how to run CPU-specific workloads on mixed clusters, and an example of how to make workloads CPU-agnostic.


Table of Contents
=================

  * [Prerequisites](#prerequisites)
  * [Provisioning a Kubernetes Cluster](#provisioning-a-kubernetes-cluster)
  * [Building and Deploying our App](#building-and-deploying-our-app)
    * [Examining our Deployment](#examining-our-deployment)
    * [Fixing the Deployment](#fixing-the-deployment)
  * [Multiarch Builds](#multiarch-builds)
    * [Submit a Build](#submit-a-build)
  * [Conclusions](#conclusions)
  * [Further Reading](#further-reading)



## Prerequisites

The following utilities need to be installed to run through this guide:

1. Install [`gcloud`](https://cloud.google.com/sdk/docs/downloads-interactive#mac)
1. Configure `gcloud`: Run `gcloud init` and follow its prompts to configure the target GCP Project, region and other settings
1. Download Kubernetes CLI, [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (if not already installed by gcloud)
1. Install [Docker](https://www.docker.com/products/docker-desktop)
1. Install [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html), typically via the gettext package, `brew install gettext` or `apt-get install gettext`

This guide also assumes:

1. A project has been created in GCP
1. A network in that project exists
1. You have permissions to create GKE clusters, Artifact Repisotires, and submit Cloud Builds.

## Provisioning a Kubernetes Cluster

First we'll provision a Google Kubernetes Engine (GKE) cluster:

```bash
# Create a basic GKE cluster with 3 nodes.
gcloud container clusters create multiarch --machine-type=n1-standard-4 --num-nodes=3 --no-enable-shielded-nodes --cluster-version=1.23.6-gke.1700

```

Next we'll add a node pool of `t2a-standard-4` machines, Google's ARM offering.

```bash
# Add a node pool to our cluster. t2a machines only support Google Virtual NIC
gcloud container node-pools create arm --cluster=multiarch \
                                        --machine-type=t2a-standard-4 \
                                        --enable-gvnic \
                                        --num-nodes=3 \
                                        --node-version=1.23.6-gke.1700

```

Let's check on our nodes:

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

Our cluster is up and ready for use!

## Building and Deploying our App

We need something to run on our cluster, so let's build our demo app and push it to our repo.

We'll need somewhere to host our image, so let's create a new Artifact Repository.

```bash
# Create a Docker Artifact Repository in the US region.
gcloud artifacts repositories create envspitter --repository-format=docker --location=us

```

Now we build and push our Docker image:

```bash
# Build the docker image
docker build . -t us-docker.pkg.dev/${PROJECT_ID}/envspitter/envspitter:${TAG_NAME}

# Push the docker image
docker push  us-docker.pkg.dev/${PROJECT_ID}/envspitter/envspitter:${TAG_NAME}

```

With our image pushed, we can now deploy it to our GKE cluster.

```bash
# Create a Deployment for our app
envsubst < k8s-objects/envspitter-dp.yaml | kubectl apply -f -

# Create a Loadbalancer service for our app
kubectl apply -f k8s-objects/envspitter-svc.yaml

```

### Examining our Deployment

Our application has been deployed, let's check on it:

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

Looks like many of the pods are in a bad state.

Pick a pod from the deployment and examine the logs.

```
$ kubectl logs envspitter-899c74bd9-77zsw
exec /app/envspitter: exec format error
``` 

It turns out our local machine didn't quite match the architecture of some of our nodes.

### Fixing the Deployment

A quick fix would be to make our app only run on compatible machines. Fortunately the nodes are labeled with their CPU architecture, so we can use a simple node selector to restrict pods to compatible nodes:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64

```

Let's patch the deployment with the appropriate snippet.

```bash
# Detect system architecture
export SYSTEM_ARCH=$(uname -m)

# Patch deployment to only run on your local machine's architecture
kubectl patch deployment envspitter --patch-file=k8s-objects/envspitter-dp-patch-${SYSTEM_ARCH}.yaml

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

We got our pods off the incompatible nodes, but some of the Pods are stuck pending because there aren't enough nodes compatible with our workload. Let's get it compatible.

## Multiarch Builds

Docker images are actually a manifest that can consist of one or more images. If the container image manifest is built properly, clients will simply run the appropriate image for the host's CPU architecture and OS. Docker's buildx tool makes this easy, however Cloud Build makes it easier.

### Submit a Build

We previously created our container registry, so now we just need to submit our build with the included [cloudbuild.yaml](cloudbuild.yaml)

```bash
# Submit our multiarch build to Cloud Build with a specific tag.
gcloud builds submit --substitutions TAG_NAME=1.1

```

After the build completes, there should be images for amd64 and arm64 in the manifest for the envspitter:1.1 image.

### Updating our deployment

Let's update our Deployment with the new image.

```bash
# Update the container image in our deployment to 1.1
kubectl set image deployment/envspitter envspitter=us-docker.pkg.dev/${PROJECT_ID}/envspitter/envspitter:1.1

```

While the deployment has a new image that is compatible with both arm64 and amd64, we still have a node restriction in place. We must remove the node selector to get pods to schedule everywhere.

```bash
# Patch deployment to remove nodeselector 
kubectl patch deployment envspitter --patch-file=k8s-objects/envspitter-dp-patch-noselector.yaml

```

Our pods should now be scheduled across all nodes.

```
sada-hq-macpro89:multiarch elsonrodriguez$ kubectl get pod -o wide
NAME                          READY   STATUS    RESTARTS   AGE   IP           NODE                                       NOMINATED NODE   READINESS GATES
envspitter-75cd4bdd68-58q4x   1/1     Running   0          13s   10.76.4.7    gke-multiarch-arm-9afe67fe-hkn9            <none>           <none>
envspitter-75cd4bdd68-5pz24   1/1     Running   0          13s   10.76.3.4    gke-multiarch-arm-9afe67fe-g0db            <none>           <none>
envspitter-75cd4bdd68-5zjbn   1/1     Running   0          13s   10.76.5.5    gke-multiarch-arm-9afe67fe-cpxn            <none>           <none>
envspitter-75cd4bdd68-dc4q8   1/1     Running   0          9s    10.76.1.16   gke-multiarch-default-pool-7efc8129-9lw5   <none>           <none>
envspitter-75cd4bdd68-g8sgw   1/1     Running   0          10s   10.76.0.12   gke-multiarch-default-pool-7efc8129-7qgw   <none>           <none>
envspitter-75cd4bdd68-k4q7b   1/1     Running   0          10s   10.76.4.8    gke-multiarch-arm-9afe67fe-hkn9            <none>           <none>
envspitter-75cd4bdd68-mks74   1/1     Running   0          13s   10.76.4.6    gke-multiarch-arm-9afe67fe-hkn9            <none>           <none>
envspitter-75cd4bdd68-q49l8   1/1     Running   0          9s    10.76.2.12   gke-multiarch-default-pool-7efc8129-zf0n   <none>           <none>
envspitter-75cd4bdd68-t4b92   1/1     Running   0          13s   10.76.3.5    gke-multiarch-arm-9afe67fe-g0db            <none>           <none>
envspitter-75cd4bdd68-zv24x   1/1     Running   0          10s   10.76.5.6    gke-multiarch-arm-9afe67fe-cpxn            <none>           <none>
```

## Conclusions 

The lower cost of ARM processers on GCP offers an opportunity to reduce compute costs while maintaining performance for many workloads. The main challenge is the availability of software built for ARM. While most official Docker images have support for multiple architectures, you may find gaps. Using Kubernetes provides a way to save money where possible, and maintain compatibility where it's not. The increasing popularity of ARM and Docker's buildx toolkit will make it increasingly rare o encounter a workload which needs any special consideration at all. Those same tools will also the transisions for your own organization's applications.

Compatiblity aside, you may find some workloads work faster on arm64 or x86_64, in which case Kubernetes offers simple semantics for making sure those workloads run where they are most performant.


## Further Reading

TBD
