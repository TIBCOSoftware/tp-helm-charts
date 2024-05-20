### TP CP proxy
Dataplane proxy to expose control plane endpoints to dataplane

# Sample values
global:
  tibco:
    dataplaneId: "abcd" # Mandatory
    subscriptionId: "abcd" # Mandatory

## Installing the Chart

```console
$ helm install tp-cp-proxy tibco-platform/tp-cp-proxy