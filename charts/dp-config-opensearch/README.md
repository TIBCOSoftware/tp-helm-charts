# dp-config-opensearch

Helm chart to configure OpenSearch cluster and OpenSearch Dashboards for TIBCO Data Plane.

## Description

This chart deploys:
- **OpenSearch** - A distributed search and analytics engine (fork of Elasticsearch)
- **OpenSearch Dashboards** - Visualization and user interface for OpenSearch (fork of Kibana)

Both components are deployed using official OpenSearch Helm charts as dependencies.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for persistence)

## Installation

### Add Helm repository dependencies

```bash
helm dependency update
```

### Install the chart

```bash
helm install dp-config-opensearch . -n <namespace> --create-namespace
```

### Install with custom values

```bash
helm install dp-config-opensearch . -n <namespace> -f custom-values.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `opensearch.enabled` | Enable OpenSearch deployment | `true` |
| `opensearch.clusterName` | OpenSearch cluster name | `opensearch-cluster` |
| `opensearch.replicas` | Number of OpenSearch replicas | `3` |
| `opensearch.resources` | Resource requests/limits for OpenSearch | See values.yaml |
| `opensearch.persistence.enabled` | Enable persistence for OpenSearch | `true` |
| `opensearch.persistence.size` | PVC size for OpenSearch | `10Gi` |
| `opensearch.ingress.enabled` | Enable ingress for OpenSearch | `true` |
| `opensearch-dashboards.enabled` | Enable OpenSearch Dashboards | `true` |
| `opensearch-dashboards.replicaCount` | Number of Dashboards replicas | `1` |
| `opensearch-dashboards.ingress.enabled` | Enable ingress for Dashboards | `true` |
| `domain` | Base domain for ingress hosts | `""` |

### Ingress Configuration

The chart supports multiple ingress options:
- **Ingress** - Standard Kubernetes Ingress
- **HTTPRoute** - Gateway API HTTPRoute
- **Route** - OpenShift Route

### Example values.yaml

```yaml
domain: "example.com"

opensearch:
  enabled: true
  replicas: 3
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "2"
      memory: "4Gi"
  persistence:
    size: 50Gi
  ingress:
    enabled: true
    host: opensearch
  extraEnvs:
    - name: OPENSEARCH_INITIAL_ADMIN_PASSWORD
      value: "YourSecureP@ss123"

opensearch-dashboards:
  enabled: true
  ingress:
    enabled: true
    host: opensearch-dashboards
```

## Accessing the Services

After installation:

- **OpenSearch**: `https://opensearch.<domain>`
- **OpenSearch Dashboards**: `https://opensearch-dashboards.<domain>`

### Default Credentials

- **Username**: `admin`
- **Password**: Set via `opensearch.extraEnvs` with `OPENSEARCH_INITIAL_ADMIN_PASSWORD`

Password requirements:
- Minimum 8 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one digit (0-9)
- At least one special character (!@#$%^&*()_+-=)

## Uninstallation

```bash
helm uninstall dp-config-opensearch -n <namespace>
```

## Dependencies

| Chart | Version | Repository |
|-------|---------|------------|
| opensearch | 3.4.0 | https://opensearch-project.github.io/helm-charts/ |
| opensearch-dashboards | 3.4.0 | https://opensearch-project.github.io/helm-charts/ |

## License

Copyright © 2023 - 2026. Cloud Software Group, Inc.

Licensed under the Apache License, Version 2.0.
