changequote(`{{', `}}')
# Working with ARM64 Machines on Google Kubernetes Engine

Google has recently [announced](http://cloud.google.com/blog) their ARM CPU machines types. Kubernetes has had support for ARM machines for some time(as evidenced by the [proliferation](https://www.google.com/search?as_q=kubernetes+raspberry+pi+cluster&tbm=isch) of Raspberry Pi clusters), however running a mixed architecture cluster can pose some challenges.

This guide will cover how to run CPU-specific workloads on mixed clusters, and an example of how to make workloads CPU-agnostic.

## Table of Contents
undivert({{toc.md}})

## Prerequisites

The following utilities need to be installed to run through this guide:

1. Install [`gcloud`](https://cloud.google.com/sdk/docs/downloads-interactive#mac)
1. Configure `gcloud`: Run `gcloud init` and follow its prompts to configure the target GCP Project, region and other settings
1. Install [Docker](https://www.docker.com/products/docker-desktop)
1. Install [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html), typically via the gettext package, `brew install gettext` or `apt-get install gettext`

This guide also assumes:

1. A project has been created in GCP
1. A network in that project exists
1. You have permissions to create GKE clusters, Artifact Repositories, and submit Cloud Builds.

## Provisioning a Kubernetes Cluster

First we'll provision a Google Kubernetes Engine (GKE) cluster:

```bash
undivert({{scripts/create_cluster.sh}})
```

Next we'll add a node pool of `t2a-standard-4` machines(t2a is Google's ARM offering).

```bash
undivert({{scripts/create_nodepool.sh}})
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

We need something to run on our cluster, so let's build a demo app and push it to a repo.

First we'll need somewhere to host our image, so let's create a new Artifact Repository.

```bash
undivert({{scripts/create_repository.sh}})
```

Now we build and push our Docker image:

```bash
undivert({{scripts/build_docker_image.sh}})
```

With our image pushed, we can now deploy it to our GKE cluster.

```bash
undivert({{scripts/deploy_app.sh}})
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
undivert({{k8s-objects/envspitter-dp-patch-x86_64.yaml}})
```

Let's patch the deployment with the appropriate snippet.

```bash
undivert({{scripts/patch_deployment.sh}})
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

Docker images are a [manifest](https://docs.docker.com/registry/spec/manifest-v2-2/) that can reference one or more images. If the container image manifest is built properly, clients will simply run the appropriate image for their CPU architecture and OS. Docker's [buildx](https://docs.docker.com/buildx/working-with-buildx/) tool makes this easy, however Cloud Build makes it easier.

### Submit a Build

We previously created our container registry, so now we just need to submit our build with the included [cloudbuild.yaml](cloudbuild.yaml)(based on Google's [IoT multiarch build guide](https://cloud.google.com/architecture/building-multi-architecture-container-images-iot-devices-tutorial)).

```bash
undivert({{scripts/submit_build.sh}})
```

After the build completes, there should be images for amd64 and arm64 in the manifest for the envspitter:1.1 image.

```
$ docker manifest inspect us-docker.pkg.dev/${PROJECT_ID}/envspitter/envspitter:1.1
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 740,
         "digest": "sha256:d2716ba313ad3fb064c43e3fe5c30711931d2d2ec267481f0de31f2395833261",
         "platform": {
            "architecture": "amd64",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 740,
         "digest": "sha256:0046dcbceaa44c9cdc5ef209bc2e0168a86b734bd39f1834037bd5288c25f67c",
         "platform": {
            "architecture": "arm64",
            "os": "linux"
         }
      }
   ]
}
```

### Updating our deployment

Let's update our Deployment with the new image.

```bash
undivert({{scripts/update_deployment_image.sh}})
```

While the deployment has a new image that is compatible with both arm64 and amd64, we still have a node restriction in place. We must remove the node selector to get pods to schedule everywhere.

```bash
undivert({{scripts/unpatch_deployment.sh}})
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

The lower cost of ARM processors on GCP offers an opportunity to reduce compute costs while maintaining performance for many workloads. The main challenge is the availability of software built for ARM. While most official Docker images have support for multiple architectures, you may find gaps. Using Kubernetes provides a way to save money where possible, and maintain compatibility where it's not. The increasing popularity of ARM and Docker's buildx toolkit will make it increasingly rare to encounter a workload which needs any special consideration at all. Those same tools will also enable your own applications to use ARM where it makes sense.

Compatibility aside, you may find some workloads work faster on arm64 or x86_64, in which case Kubernetes offers simple semantics for making sure those workloads run where they are most performant.

## Further Reading

- [GCP Announces ARM Machine Blog Thing](http://cloud.google.com)
- [Docker: Multi-CPU Architecture Support](https://docs.docker.com/desktop/multi-arch/)
- [GKE Docs](https://cloud.google.com/kubernetes-engine/docs/)
- [Kubernetes up and Running](http://shop.oreilly.com/product/0636920043874.do)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) (low-level infrastructure)
