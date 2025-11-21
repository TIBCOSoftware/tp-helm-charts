## Cp core configuration

Configure and setup the ground work for control plane. Manages resources set templates for subscription and dataplane. These templates creates infra resources required for a control plane subscription and dataplane. 
Extract control tower to pvc.
Configure router log level to info.

## Parameters

The following table lists the configurable parameters of the base chart and the default values.

| Parameter                                | Description                                               | Default                         |
| -----------------------------------------|-----------------------------------------------------------| ------------------------------- |
| **image**                  |
| `image.name`       | image used to extract control tower | `container-image-extractor`                  |
| `image.registry`   | custom image registry | nil |
| `image.repo`       | custom image repo     | nil | 
| `image.tag`        | image tag             | `68-distroless` |
| `image.pullPolicy` | iamge pull policy     | `IfNotPresent`  |
| **controlTower**   |
| `control-tower.image.name` | control tower image which have ct zip | `control-tower` |
| `control-tower.image.tag`  | control tower image tag               | `79` |
