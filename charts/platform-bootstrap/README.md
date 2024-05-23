## Platform bootstrap

## Configuration

| **tp-cp-bootstrap**
The following table lists the configurable parameters of the platform bootstrap chart and the default values.

| Parameter                                | Description                                               | Default                         |
| -----------------------------------------|-----------------------------------------------------------| ------------------------------- |
| **cp-compute-services**                  |
| `tp-cp-bootstrap.compute-services.enabled`            | enable compute service                                    | `true`                          |
| `tp-cp-bootstrap.compute-services.dpMetadata.dpCoreInfrastructureChartVersion` | dp core infrastructure chart version installed in dataplanes | `*` |
| `tp-cp-bootstrap.compute-services.dpMetadata.dpConfigureNamespaceChartVersion` | dp configure namespace chart version installed in dataplanes | `*` |
| **global.tibco**                            |
| `global.tibco.logging.fluentbit.enabled`                | enable logging | `false`|
| `global.tibco.serviceAccount`               | pass service account if already created else leave it   |   |
| `global.tibco.containerRegistry.url` | container registry url used by all the tibco components   | |
| `global.tibco.containerRegistry.username` | container registry username for private repo | |
| `global.tibco.containerRegistry.password` | container registry password for private repo | |
| `global.tibco.createNetworkPolicy`        | enable or disable creating default network policies for a namespace | `false` |
| `global.tibco.controlPlaneInstanceId`     | uniquely identifies the container plane installation | `abc` | 