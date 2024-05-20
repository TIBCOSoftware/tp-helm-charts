# Tibtunnel Helm Chart
This chart is subchart of dp-core-infrastructure helm chart

# Sample values
global:
  tibco:
    dataPlaneId: "abcd" # Mandatory
    subscriptionId: "abcd" # Mandatory
configure:
  profile: "" #The name of the profile to create or update
  accessKey: "abc" #Specify the TIBCO AccessKey secret to be used for authenticationd
connect:
  url: "" # Connect Url generated from TIBCO Cloud Control plane
  onPremHost: "" #service name of on prem host
  onPremPort: "80" #port number of the service.

## Installing the Chart

```console
$ helm install tp-tibtunnel tibco-platform/tp-tibtunnel