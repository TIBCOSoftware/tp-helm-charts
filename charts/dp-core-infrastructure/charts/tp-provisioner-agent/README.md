<!-- 
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

# Tibtunnel Helm Chart
This chart is subchart of dp-core-infrastructure helm chart

## NOTE :
If user provided service account is empty then default service account is created as part of tp provisioner operator helm chart.

# Sample values
global:
  tibco:
    dataPlaneId: "abcd" # Mandatory
    subscriptionId: "abcd" # Mandatory

## Installing the Chart

```console
$ helm install tp-provisioner-agent tibco-platform/tp-provisioner-agent