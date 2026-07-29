<!-- 
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

Table of Contents
=================
<!-- TOC -->
* [Table of Contents](#table-of-contents)
* [Air-Gapped System Deployment](#air-gapped-system-deployment)
  * [Introduction](#introduction)
  * [Scope](#scope)
* [Prerequisites](#prerequisites)
  * [Virtual Machine with Internet Connectivity](#virtual-machine-with-internet-connectivity)
  * [Tools Required](#tools-required)
  * [JFrog Credentials](#jfrog-credentials)
* [Download TIBCO® Platform Container Images](#download-tibco-platform-container-images)
  * [Source Registry Authentication](#source-registry-authentication)
  * [Option 1: Sync using sync-images.sh (Recommended)](#option-1-sync-using-sync-imagessh-recommended)
  * [Option 2: Sync using skopeo (not validated)](#option-2-sync-using-skopeo-not-validated)
  * [Option 3: Sync using other tools](#option-3-sync-using-other-tools)
  * [Verifying Image Integrity After Transfer](#verifying-image-integrity-after-transfer)
* [Download Helm Charts](#download-helm-charts)
  * [Push to Chart Museum](#push-to-chart-museum)
    * [Using cURL Command](#using-curl-command)
    * [Using helm cm-push](#using-helm-cm-push)
  * [Push to OCI Registry](#push-to-oci-registry)
* [Email Server Configuration](#email-server-configuration)
* [Next Steps](#next-steps)
<!-- TOC -->

# Air-Gapped System Deployment

The goal of this document is to specify the prerequisites required to deploy TIBCO® Control Plane and register a Data Plane on an air-gapped system.

> [!Note]
> This workshop is NOT meant for production deployment.

## Introduction

An air-gapped Virtual Machine (or any air-gapped system) is a virtual machine isolated from external networks (internet and other specific networks). It's often used in security-sensitive environments.

## Scope

The scope of this document is limited to:
- Deploying TIBCO® Control Plane
- Registering a Data Plane
on an air-gapped Virtual Machine

# Prerequisites

## Virtual Machine with Internet Connectivity

In addition to the air-gapped Virtual Machine, the customer should have an additional Virtual Machine with internet connectivity which can be used to:
- Pull container images from JFrog Edge repository
- Pull the helm charts from [TIBCOSoftware GitHub public repository](https://github.com/TIBCOSoftware/tp-helm-charts)

> [!NOTE]
> If required, TIBCO® can provide the specific public IPs of the container registry for you to whitelist and pull the images, rather than blanket internet access. For the requests please use https://csg-engops.atlassian.net/servicedesk/customer/portals. However, please note that we do not have any control over the IP addresses of JFrog SaaS.

From this Virtual Machine with internet connectivity, you should:
- Push the images to the container registry which air-gapped Virtual Machine has access to
- Push the helm charts to the helm registry which air-gapped Virtual Machine has access to

## Tools Required

The following tools are required to be installed on:

**Virtual Machine with Internet Connectivity:**
- Docker CLI
- Docker Buildx (required for Option 1; bundled with Docker Desktop and Docker Engine 19.03+)
- Helm
- Kubectl / OpenShift client (oc)
- skopeo (optional, required for Option 2 if not using Docker Buildx)

**air-gapped Virtual Machine:**
- Helm
- Kubectl / OpenShift client (oc)

## JFrog Credentials

As an end-user, you must create a subscription and obtain the Username, Password, Docker Registry URL and Repository details from SRE / Account Details.

# Download TIBCO® Platform Container Images

The complete list of images for your release is available under [TIBCO Platform Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/pushing-images-to-registry.htm?TocPath=Installation%257CDeploying%2520TIBCO%2520Control%2520Plane%2520in%2520a%2520Kubernetes%2520Cluster%257C_____2). Images are also enumerated per capability in the [`artifacts/`](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/artifacts) directory of the tp-helm-charts repository as `*-<RELEASE_VERSION>-images.txt` files.

## Source Registry Authentication

Log in to TIBCO's JFrog Registry using details obtained from Subscription Account Details.

Depending on your subscription region, choose one of the following:

For EU Region:
```bash
docker login csgprdeuwrepoedge.jfrog.io -u tibco-platform-sub-<id> -p "xxxxxxxxxxxxxx"
```

For US Region:
```bash
docker login csgprduswrepoedge.jfrog.io -u tibco-platform-sub-<id> -p "xxxxxxxxxxxxxx"
```

## Option 1: Sync using sync-images.sh (Recommended)

The [`scripts/sync-artifacts/sync-images.sh`](../../../scripts/sync-artifacts/sync-images.sh) script copies images **directly between registries** using `docker buildx imagetools create`. It reads the `*-images.txt` [`artifact files`](../../../artifacts) and handles all images for a given release in a single automated pass.

### Sample Usage

```bash
# From the cloned repo, switch to the sync-artifacts directory
cd scripts/sync-artifacts

export SOURCE_REGISTRY="csgprdeuwrepoedge.jfrog.io"   # or US endpoint
export SOURCE_REGISTRY_USERNAME="tibco-platform-sub-<id>"
export SOURCE_REGISTRY_PASSWORD="xxxxxxxxxxxxxx"
export RELEASE_VERSION="1.18.0"                        # adjust to your version
export TARGET_REGISTRY="your-registry.example.com"
export TARGET_REGISTRY_USERNAME="your-username"        # optional
export TARGET_REGISTRY_PASSWORD="your-password"        # optional
export TARGET_REGISTRY_REPO="tibco-platform"           # optional

./sync-images.sh
```

To sync images for a single capability only, set `CAPABILITY_NAME`:

```bash
export CAPABILITY_NAME="control-plane"
./sync-images.sh
```

## Option 2: Sync using skopeo (not validated)

If Docker Buildx is unavailable in your environment, skopeo can also perform a direct registry-to-registry copy.

[`skopeo`](https://github.com/containers/skopeo) is purpose-built for registry-to-registry image operations. The `--all` flag copies every architecture variant in a single command, preserving the full multi-arch manifest list. The `--preserve-digests` flag keeps the copied image digests identical to the source and fails the copy if a digest cannot be preserved — this avoids the layer re-encoding described in [Verifying Image Integrity After Transfer](#verifying-image-integrity-after-transfer) and is recommended for OpenShift/Podman environments.

```bash
# Copy a single image (all architectures)
skopeo copy --all --preserve-digests \
  --src-creds  "tibco-platform-sub-<id>:xxxxxxxxxxxxxx" \
  --dest-creds "your-username:your-password" \
  docker://csgprdeuwrepoedge.jfrog.io/tibco-platform-docker-prod/core-cp-scripts:9474 \
  docker://your-registry.example.com/tibco-platform/core-cp-scripts:9474
```

To bulk-copy all images listed in a release file:

```bash
SOURCE_REGISTRY="csgprdeuwrepoedge.jfrog.io"
SOURCE_REPO="tibco-platform-docker-prod"
TARGET_REGISTRY="your-registry.example.com"
TARGET_REPO="tibco-platform"

while IFS= read -r image || [[ -n "$image" ]]; do
  [[ -z "$image" || "$image" == \#* ]] && continue
  skopeo copy --all --preserve-digests \
    --src-creds  "tibco-platform-sub-<id>:xxxxxxxxxxxxxx" \
    --dest-creds "your-username:your-password" \
    "docker://${SOURCE_REGISTRY}/${SOURCE_REPO}/${image}" \
    "docker://${TARGET_REGISTRY}/${TARGET_REPO}/${image}"
done < ../../artifacts/control-plane/control-plane-1.18.0-images.txt
```

## Option 3: Sync using other tools

Please note that other tools like `oc mirror` and `podman` may also be used for image synchronization, depending on your 
environment and requirements, but our testing and validation is limited to the above [Option 1](#option-1-sync-using-sync-imagessh-recommended). 
If you choose to use other tools, please ensure that you verify the integrity of the images after transfer.


## Verifying Image Integrity After Transfer

> [!CAUTION]
> A `docker pull` + `docker push` cycle re-encodes gzip layers, producing images that appear valid but may fail at runtime. Spot-check at least one image after mirroring.

Set your registry details and run the following snippet to inspect the first layer's gzip header directly from the registry (no image pull needed):

```bash
REGISTRY="your-registry.example.com"
REPO="tibco-platform"
IMAGE="core-cp-scripts"
TAG="9474"

TOKEN=$(curl -s -u "username:password" \
  "https://$REGISTRY/v2/token?service=$REGISTRY&scope=repository:$REPO/$IMAGE:pull" \
  | jq -r '.token')

DIGEST=$(curl -s -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://$REGISTRY/v2/$REPO/$IMAGE/manifests/$TAG" | jq -r '.layers[0].digest')

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://$REGISTRY/v2/$REPO/$IMAGE/blobs/$DIGEST" -o /tmp/check_header.tar.gz

xxd /tmp/check_header.tar.gz | head -1
```

**Expected output (intact image):**
```
00000000: 1f8b 0800 0000 0000 00ff ecf2 638c 2f40  ................
```

Bytes 10–11 should be non-zero (e.g. `ec f2`). If you see `00 ff`, the layer was re-encoded — re-mirror using `sync-images.sh` or `skopeo copy --all --preserve-digests` before proceeding.

# Download Helm Charts

Helm Charts for TIBCO® Platform are available in the [TIBCOSoftware GitHub public repository](https://github.com/TIBCOSoftware/tp-helm-charts/tree/gh-pages).

Depending on your requirement, please download all the charts related to:
- TIBCO® Control Plane
- Data Plane

Add the Helm Charts repository for TIBCO® Platform as the "tibco-platform" Helm repo:

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm pull "tibco-platform/platform-base" --version "1.12.0"
# platform-base-1.12.0.tgz should get pulled as a tgz file
```

To demonstrate options for a custom Helm registry, the sample commands include 
- ChartMuseum
- OCI Registry

> [!NOTE]
> There is no recommendation to use ChartMuseum per se, you can use any helm registry offering.

Depending on your requirements, you can use either of the following approaches:

## Push to Chart Museum

### Using cURL Command

```bash
# Ensure that <CHARTMUSEUM_URL> & <CHART_REPO_PATH> are exported
curl -X POST --data-binary @"platform-base-1.12.0.tgz" $CHARTMUSEUM_URL/api/$CHART_REPO_PATH/charts

# You can add optional authentication to the command above as follows
curl -X POST --data-binary @"platform-base-1.12.0.tgz" $CHARTMUSEUM_URL/api/$CHART_REPO_PATH/charts -u $CHARTMUSEUM_USERNAME:$CHARTMUSEUM_PASSWORD
```

### Using helm cm-push

```bash
# Ensure that <CHARTMUSEUM_URL> & <CHART_REPO_PATH> are exported
helm repo add custom-repo ${CHARTMUSEUM_URL}/${CHART_REPO_PATH}

# You can add optional authentication to the command above as follows
helm repo add custom-repo ${CHARTMUSEUM_URL}/${CHART_REPO_PATH} -u ${CHARTMUSEUM_USERNAME} -p ${CHARTMUSEUM_PASSWORD}

# Ensure that you have installed cm-push plugin
# helm plugin install https://github.com/chartmuseum/helm-push
helm cm-push platform-base-1.12.0.tgz custom-repo
```

## Push to OCI Registry

```bash
export HELM_EXPERIMENTAL_OCI=1

# Ensure that you are logged in to the Helm registry
helm push platform-base-1.12.0.tgz oci://${CUSTOM_HELM_REGISTRY}/${CUSTOM_HELM_REGISTRY_PATH}
```

> [!IMPORTANT]
> Please make sure that you use the Custom Helm Chart Repository to deploy TIBCO® Control Plane charts and configure the same Custom Helm Chart Repository in Data Plane.

# Email Server Configuration

The TIBCO® Control Plane Orchestrator tries to validate the admin email domain for the specified email server details. This requires the orchestrator service to reach the domain over the internet.
This will fail on the air-gapped Virtual Machine if the domain is not accessible within the network.

> [!IMPORTANT]
> As an alternative, you can provide the following under `global.external` of platform-base values

```yaml
adminInitialPassword: "" ## Add password here

## Keep following email related section empty
emailServerType: ""
emailServer:
  ses:
    arn: ""
    smtp:
      server: ""
      port: ""
      username: ""
      password: ""
    sendgrid:
      apiKey: ""
fromAndReplyToEmailAddress: "" ## Keep empty
```

You can login to admin with the initial password and reset it.

For subscription provisioning, also provide the "password" under userDetails:

```json
{
  "userDetails": {
    "firstName": "",
    "lastName": "",
    "email": "",
    "password": "<set_password_here>",  
    "country": "",
    "state": ""
  },
  "subscriptionDetails": {
    "companyName": "",
    "ownerLimit": <number>,
    "hostPrefix": "",
    "comment": ""
  },
  "useDefaultIDP": true
}
```

# Next Steps

Based on your deployment target
- For TIBCO® Control Plane, please follow the steps from the subtopics listed on the [TIBCO Public Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Installation/installation.htm)
- For Data Plane, please follow the steps from appropriate directory under [workshop](../../workshop/)
