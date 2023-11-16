# Istiod Helm Chart

This chart installs the istiod components of Istio Service mesh.

- [Requirements](#requirements)
- [Configuration](#configuration)

## Setup Repo Info

```console
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

## Installing the Chart

Before installing, ensure CRDs are installed in the cluster (from the `istio/istio-crd` chart).

To install the chart with the release name `istiod`:

```console
helm upgrade --install istio-istiod "./istio-istiod" --values "./istio-istiod/override.yaml" -n istio-system --create-namespace 
```

## Uninstalling the Chart

To uninstall/delete the `istiod` deployment:

```console
helm delete istio-istiod --namespace istio-system
```

## Configuration

To view support configuration options and documentation, run:

```console
helm show values istio/istiod
```

### Examples

#### Configuring mesh configuration settings

## Requirements

* Kubernetes >= 1.24
* Helm >= 3.9.0
* CPU >= 500m 
* Memory >= 1GiB 

## Configuration

### Configuration for namespace
```yaml
global:
  # Used to locate istiod.
  istioNamespace: istio-system
```

### Configuration for pilot
```yaml
pilot:
  # general setting
  replicaCount: 1
  traceSampling: 1.0
  nodeSelector: {}
  
```


### Configuration for trusted domain
```yaml
meshConfig:
  accessLogFile: /dev/stdout
  
  # The trust domain corresponds to the trust root of a system
  # Refer to https://github.com/spiffe/spiffe/blob/master/standards/SPIFFE-ID.md#21-trust-domain
  trustDomain: "cluster.local"
```
  
### Configuration for extension provider
```yaml
meshConfig:
  extensionProviders: 
  - name: otel
    envoyOtelAls:
      service: opentelemetry-collector.istio-system.svc.cluster.local
      port: 4317
  - name: opentelemetry
    opentelemetry:
      service: opentelemetry-collector.istio-system.svc.cluster.local
      port: 4317  
```
  
### Configuration for namespace
```yaml
```

### Configuration for tracer
```yaml
global:
```
    zipkin:
      # Host:Port for reporting trace data in zipkin format. If not specified, will default to
      # zipkin service (port 9411) in the same namespace as the other istio components.
      address: ""
```


### Configuration for revision
Control plane revisions allow deploying multiple versions of the control plane in the same cluster.
This allows safe [canary upgrades](https://istio.io/latest/docs/setup/upgrade/canary/)
```yaml
revision: my-revision-name
```

### Configuration for multi cluster
```yaml
global:
  multiCluster:
    # Set to true to connect two kubernetes clusters via their respective
    # ingressgateway services when pods in each cluster cannot directly
    # talk to one another. All clusters should be using Istio mTLS and must
    # have a shared root CA for this model to work.
    enabled: false
    # Should be set to the name of the cluster this installation will run in. This is required for sidecar injection
    # to properly label proxies
    clusterName: ""
```

### Configuration for proxy 
```yaml
global:
  proxy:
    # CAUTION: It is important to ensure that all Istio helm charts specify the same clusterDomain value cluster domain. 
    # Default value is "cluster.local".
    clusterDomain: "cluster.local"
  
    # Log level for proxy, applies to gateways and sidecars.
    # Expected values are: trace|debug|info|warning|error|critical|off
    logLevel: warning
    # Resources for the sidecar.
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi    
```


 
