## Platform bootstrap

## Prerequisites

- Existing Kubernetes Secrets required by this chart:
  
  | Secret Name      | Keys                          | Description                            |
  |------------------|-------------------------------|--------------------------------------|
  | `session-keys`   | `TSC_SESSION_KEY`             | Contains session keys required for app environment variables |
  | `session-keys`   | `DOMAIN_SESSION_KEY`          | Contains session keys required for app environment variables |

- Ensure that the secrets referenced in the `values.yaml` (under `tscSessionKey` and `domainSessionKey` ) exist in the target namespace before installing the chart.

- Example to create the `session-keys` secret manually, Run this command to create the `session-keys` secret with random 32-character alphanumeric keys:

    ```bash
    kubectl create secret generic session-keys -n <namespace> \
    --from-literal=TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c32) \
    --from-literal=DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c32)

> **Note:**  
> Both `TSC_SESSION_KEY` and `DOMAIN_SESSION_KEY` can be sourced from the **same Kubernetes Secret** (as in the example above) or from **different Secrets**.  
> Make sure to update your Helm `values.yaml` accordingly to reference the correct secret names and keys.


## Configuration

The following table lists the configurable parameters of the bootstrap chart and the default values.

| Parameter                                | Description                                               | Default                         |
| -----------------------------------------|-----------------------------------------------------------| ------------------------------- |
| **cp-compute-services**                  |
| `compute-services.enabled`            | enable compute service                                    | `true`                          |
| `compute-services.dpMetadata.dpCoreInfrastructureChartVersion` | dp core infrastructure chart version installed in dataplanes | `*` |
| `compute-services.dpMetadata.dpConfigureNamespaceChartVersion` | dp configure namespace chart version installed in dataplanes | `*` |
| **cp-router-operator**                  |
| `router-operator.enabled`            | enable router operator                                    | `true`                          |
| `router-operator.tscSessionKey.secretName` | tscSessionKey secretName  | `session-keys` |
| `router-operator.tscSessionKey.key` | tscSessionKey key  | `TSC_SESSION_KEY` |
| `router-operator.domainSessionKey.secretName` | domainSessionKey secretName | `session-keys` |
| `router-operator.domainSessionKey.key` | domainSessionKey key  | `DOMAIN_SESSION_KEY` |
| **global.tibco**                            |
| `global.tibco.logging.fluentbit.enabled`                | enable logging | `false`|
| `global.tibco.serviceAccount`               | pass service account if already created else leave it   |   |
| `global.tibco.containerRegistry.url` | container registry url used by all the tibco components   | |
| `global.tibco.containerRegistry.username` | container registry username for private repo | |
| `global.tibco.containerRegistry.password` | container registry password for private repo | |
| `global.tibco.createNetworkPolicy`        | enable or disable creating default network policies for a namespace | `false` |
| `global.tibco.controlPlaneInstanceId`     | uniquely identifies the container plane installation | `abc` | 