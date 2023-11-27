# Helm Charts for TIBCO® Platform
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Release Charts](https://github.com/TIBCOSoftware/tp-helm-charts/actions/workflows/release-chart.yaml/badge.svg)](https://github.com/TIBCOSoftware/tp-helm-charts/actions/workflows/release-chart.yaml)

Helm Charts for TIBCO® Platform contains a list of Helm charts for TIBCO® Platform data plane components.

## Introduction
TIBCO Platform provides a single pane of glass for the management, monitoring, and observability of TIBCO applications and capabilities. It provides a unified view of all TIBCO applications and capabilities deployed across multiple Kubernetes clusters and cloud environments.

TIBCO Platform consists of two main components:
* TIBCO® Control Plane is the central monitoring and management interface for n-number of data planes running TIBCO applications and capabilities.
* Data Plane is the runtime environment for TIBCO applications and capabilities. It contains a set of helm charts that can be deployed on any Kubernetes cluster on-premises or in the cloud.

This repository contains Helm charts for Data Plane components that can be deployed on the customer's Kubernetes cluster.

## Installing

Most of the Helm charts in this repository will be installed by the TIBCO® Control Plane. In most cases, customers will not need to install these Helm charts manually.

There are some charts that can help customers set up cluster ingress, storage class, observability stack, etc. Customers can install these charts manually.

### Prerequisites
1. [x] Helm **v3 > 3.12.0** [installed](https://helm.sh/docs/using_helm/#installing-helm): `helm version`
2. [x] Chart repository: `helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts`

## Contributing

The source code is under <https://github.com/TIBCOSoftware/tp-helm-charts>

# Licenses

This project (_Helm Charts for TIBCO® Platform_) is licensed under the [Apache 2.0 License](https://github.com/TIBCOSoftware/tp-helm-charts/blob/main/LICENSE).

## Other Software

When you use some of the Helm charts, you fetch and use other charts that might fetch other container images, each with their own licenses.
A partial summary of the third party software and licenses used in this project is available [here](https://github.com/TIBCOSoftware/tp-helm-charts/blob/main/docs/third-party-software-licenses.md).

---
Copyright 2023 Cloud Software Group, Inc.

License. This project is Licensed under the Apache License, Version 2.0 (the "License").
You may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.