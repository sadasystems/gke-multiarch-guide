changequote(`{{', `}}')
# Working with ARM64 Machines on Google Kubernetes Engine

Google has recently [announced](https://cloud.google.com/blog/products/compute/tau-t2a-is-first-compute-engine-vm-on-an-arm-chip) their ARM CPU machines types. Kubernetes has had support for ARM machines for some time (as evidenced by the [proliferation](https://www.google.com/search?as_q=kubernetes+raspberry+pi+cluster&tbm=isch) of Raspberry Pi clusters), however running a mixed architecture cluster can pose some challenges.

This guide covers how to run CPU-specific workloads on mixed clusters, and provides an example of how to make workloads CPU-agnostic.

## Table of Contents
undivert({{toc.md}})

## Prerequisites

Install and configure the following utilities:

1. Install [`gcloud`](https://cloud.google.com/sdk/docs/downloads-interactive#mac).
    1. Configure `gcloud` by running `gcloud init` and following its prompts to configure the target Google Cloud project, region and other settings.
1. Install [Docker](https://www.docker.com/products/docker-desktop).
1. Install [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html), typically via the gettext package, `brew install gettext` or `apt-get install gettext`.

This guide also assumes:

1. A project has been created in Google Cloud.
1. A network in that project exists.
1. You have permissions to create GKE clusters, Artifact Repositories, and submit Cloud Builds.

## Setup

This guide assumes you are in a working clone of this repo:

```bash
git clone https://github.com/sadasystems/gke-multiarch-guide
cd gke-multiarch-guide
```

We also need to set some variables for later use:

```bash
undivert({{scripts/variables.sh}})
```

## Provisioning a Kubernetes Cluster

First we'll provision a Google Kubernetes Engine (GKE) cluster:

```bash
undivert({{scripts/create_cluster.sh}})
```

Next we'll add a node pool of `t2a-standard-4` machines (t2a is Google's ARM offering):

```bash
undivert({{scripts/create_nodepool.sh}})
```

Let's check on our nodes:

```
$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE   VERSION
gke-multiarch-arm-4f67b11b-3rjq            Ready    <none>   9m6s   v1.23.6-gke.1700
gke-multiarch-arm-4f67b11b-bxnh            Ready    <none>   9m8s   v1.23.6-gke.1700
gke-multiarch-arm-4f67b11b-l44s            Ready    <none>   9m8s   v1.23.6-gke.1700
gke-multiarch-default-pool-8ace7592-072c   Ready    <none>   11m    v1.23.6-gke.1700
gke-multiarch-default-pool-8ace7592-94x5   Ready    <none>   11m    v1.23.6-gke.1700
gke-multiarch-default-pool-8ace7592-j4l0   Ready    <none>   11m    v1.23.6-gke.1700
```

Our cluster is up and ready for use!

## Building and Deploying our App

We need something to run on our cluster, so let's build a demo app and push it to a repo.

First we'll need somewhere to host our container image. To do this, let's create a new [Artifact Repository](https://cloud.google.com/artifact-registry/docs/docker/store-docker-container-images):

```bash
undivert({{scripts/create_repository.sh}})
```

Now we build and push our Docker image:

```bash
undivert({{scripts/build_docker_image.sh}})
```

With our image pushed, we can now deploy it to our GKE cluster:

```bash
undivert({{scripts/deploy_app.sh}})
```

### Examining our Deployment

Our application has been deployed, let's check on it:

```
$ kubectl get pod  -o wide
NAME                         READY   STATUS             RESTARTS     AGE   IP          NODE                                       NOMINATED NODE   READINESS GATES
envspitter-5b6dd6dd47-b2q2b   0/1     CrashLoopBackOff   1 (2s ago)   4s    10.40.12.23   gke-multiarch-b8b9bfa3-arm-d1c499f7-ng1x            <none>           0/1
envspitter-5b6dd6dd47-kkb9m   0/1     CrashLoopBackOff   1 (2s ago)   4s    10.40.10.14   gke-multiarch-b8b9bfa3-arm-d1c499f7-z7hb            <none>           0/1
envspitter-5b6dd6dd47-qn45t   0/1     CrashLoopBackOff   1 (3s ago)   4s    10.40.11.16   gke-multiarch-b8b9bfa3-arm-d1c499f7-x585            <none>           1/1
envspitter-5b6dd6dd47-x4hcl   1/1     Running            0            4s    10.40.3.26    gke-multiarch-b8b9bfa3-default-pool-1d21cf40-5fvn   <none>           0/1
```

Looks like many of the pods are in a bad state.

Let's examine the pod logs.

```
$ kubectl logs -l app=envspitter
exec /app/envspitter: exec format error
``` 

It turns out our local machine didn't quite match the architecture of some of our nodes.

### Fixing the Deployment

A quick fix would be to make our app run only on compatible machines. Fortunately the nodes are labeled with their CPU architecture, so we can use a simple node selector to restrict pods to compatible nodes:

```yaml
undivert({{k8s-objects/envspitter-dp-patch-x86_64.yaml}})
```

Let's patch the deployment with the appropriate snippet:

```bash
undivert({{scripts/patch_deployment.sh}})
```

Now let's check on our Pods.

```
$ kubectl get pods -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP          NODE                                       NOMINATED NODE   READINESS GATES
envspitter-59899589d9-7rxch   1/1     Running   0          9s    10.40.1.24   gke-multiarch-b8b9bfa3-default-pool-1d21cf40-6673   <none>           1/1
envspitter-59899589d9-dcd2p   0/1     Pending   0          4s    <none>       <none>                                              <none>           0/1
envspitter-59899589d9-hk226   0/1     Pending   0          4s    <none>       <none>                                              <none>           0/1
envspitter-59899589d9-llr8t   1/1     Running   0          9s    10.40.5.24   gke-multiarch-b8b9bfa3-default-pool-1d21cf40-20vc   <none>           1/1
envspitter-5b6dd6dd47-x4hcl   1/1     Running   0          74s   10.40.3.26   gke-multiarch-b8b9bfa3-default-pool-1d21cf40-5fvn   <none>           1/1
```

Our pods are now off of the incompatible nodes, but some of the Pods are stuck pending because there aren't enough nodes compatible with our workload. Let's get our workload compatible.

## Multiarch Builds

Docker images are a [manifest](https://docs.docker.com/registry/spec/manifest-v2-2/) that references one or more images. If the container image manifest is built properly, clients will simply run the appropriate image for their CPU architecture and OS. Docker's [buildx](https://docs.docker.com/buildx/working-with-buildx/) tool makes this easy, however Cloud Build makes it easier.

### Submit a Build

We previously created our container registry, so now we just need to submit our build with the included [cloudbuild.yaml](cloudbuild.yaml) based on Google's [IoT multiarch build guide](https://cloud.google.com/architecture/building-multi-architecture-container-images-iot-devices-tutorial).

```bash
undivert({{scripts/submit_build.sh}})
```

After the build completes, there should be images for amd64 and arm64 in the manifest for the envspitter:1.1 image.

```
$ docker manifest inspect us-docker.pkg.dev/${PROJECT_ID}/envspitter-${LABUID}/envspitter:1.1
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

### Updating our Deployment

Let's update our deployment with the new image:

```bash
undivert({{scripts/update_deployment_image.sh}})
```

While the deployment has a new image that is compatible with both arm64 and amd64, we still have a node restriction in place. In order to get pods to schedule everywhere we must remove the node selector:

```bash
undivert({{scripts/unpatch_deployment.sh}})
```

Our pods should now be scheduled across all nodes.

```
$ kubectl get pod -o wide
NAME                          READY   STATUS    RESTARTS   AGE   IP          NODE                              NOMINATED NODE   READINESS GATES
envspitter-5fdbfcc76-292rb   1/1     Running   0          8s    10.40.3.27    gke-multiarch-b8b9bfa3-default-pool-1d21cf40-5fvn   <none>           1/1
envspitter-5fdbfcc76-lwbnf   1/1     Running   0          16s   10.40.11.17   gke-multiarch-b8b9bfa3-arm-d1c499f7-x585            <none>           1/1
envspitter-5fdbfcc76-pnhzc   1/1     Running   0          10s   10.40.10.15   gke-multiarch-b8b9bfa3-arm-d1c499f7-z7hb            <none>           1/1
envspitter-5fdbfcc76-ssx7l   1/1     Running   0          16s   10.40.12.24   gke-multiarch-b8b9bfa3-arm-d1c499f7-ng1x            <none>           1/1
```

Now that we're compatible with all nodes in the cluster, we might as well scale our deployment up.

```bash
undivert({{scripts/scale_deployment.sh}})
```

### Testing our Application

Our app is now deployed across all nodes. Let's hit it via the external loadbalancer and see what it does.

```shell
undivert({{scripts/check_app.sh}})
```

The output should change every few seconds, and you'll see that the app is being served from multiple hosts running amd64 and arm64 CPUs.

## Conclusions 

The lower cost of ARM processors on Google Cloud offers an opportunity to reduce compute costs while maintaining or improving performance for many workloads. The main challenge is the availability of software built for ARM. While most official Docker images have support for multiple architectures, you may find gaps. Using Kubernetes provides a way to save money where possible, and maintain compatibility where it's not. The increasing popularity of ARM and Docker's buildx toolkit will make it increasingly rare to encounter a workload which needs any special consideration at all. Those same tools will also enable your own applications to use ARM where it makes sense.

Compatibility aside, you may find some workloads work faster on arm64 or x86_64, in which case Kubernetes offers simple semantics for making sure those workloads run where they are most performant.

## Teardown

To delete the resources created in this guide:

```bash
undivert({{scripts/teardown.sh}})
```

## Further Reading

- [Google Cloud: Arm Workloads on GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/arm-on-gke)
- [Docker: Multi-CPU Architecture Support](https://docs.docker.com/desktop/multi-arch/)
- [GKE Docs](https://cloud.google.com/kubernetes-engine/docs/)
- [Kubernetes up and Running](http://shop.oreilly.com/product/0636920043874.do)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) (low-level infrastructure)
