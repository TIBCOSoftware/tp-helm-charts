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
- Docker cli
- Helm
- Kubectl / OpenShift client (oc)

**air-gapped Virtual Machine:**
- Helm
- Kubectl / OpenShift client (oc)

## JFrog Credentials

As an end-user, you must create a subscription and obtain the Username, Password, Docker Registry URL and Repository details from SRE / Account Details.

# Download TIBCO® Platform Container Images

Log in to TIBCO's JFrog Registry using details obtained from Subscription Account Details.

Depending on your subscription region, choose one of the following:
For EU Region:
```bash
docker login csgprdeuwrepoedge.jfrog.io -u tibco-platform-sub-<id> -p "xxxxxxxxxxxxxx" ## For EU Region
```

For US Region:
```bash
docker login csgprduswrepoedge.jfrog.io -u tibco-platform-sub-<id> -p "xxxxxxxxxxxxxx" ## For US Region
```

This command logs your Docker client into TIBCO's container image registry using the provided username and password. This authentication is required to pull proprietary TIBCO® Platform container images.

The list of images is available under [TIBCO Platform Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#UserGuide/pushing-images-to-registry.htm?TocPath=Installation%257CDeploying%2520TIBCO%2520Control%2520Plane%2520in%2520a%2520Kubernetes%2520Cluster%257C_____2)

> [!IMPORTANT]
> Please take a note of the architecture of the machine with internet connectivity used for pulling container images and that of the air-gapped Virtual Machine.
> This is important since you need to pull the image which can run on the air-gapped Virtual Machine.

There can be multiple approaches to copy over the images to your custom container registry.
In the example, we are using following 3 steps:
1. Pull the images from TIBCO® Platform container registry (for example, csgprdeuwrepoedge.jfrog.io)
2. Tag the images with your custom registry (for example, x.x.x.x:5000)
3. Push the images to your custom registry

You can simply run the following commands from the Virtual Machine which can access the TIBCO® Platform container registry:

```bash
docker pull csgprdeuwrepoedge.jfrog.io/tibco-platform-docker-prod/core-cp-scripts:8707 --platform linux/amd64

docker tag csgprdeuwrepoedge.jfrog.io/tibco-platform-docker-prod/core-cp-scripts:8707 x.x.x.x:5000/tibco-platform-docker-prod/core-cp-scripts:8707

docker push x.x.x.x:5000/tibco-platform-docker-prod/core-cp-scripts:8707
```
Please make sure to adjust the Docker engine configuration to allow insecure registries, if you are using one.

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
