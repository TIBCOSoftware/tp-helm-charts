# TIBCO Platform base for Developer Hub Capability

## Installation

Since this chart is using the same values as the `platform-base` chart, you can re-use the same values file. The chart will install the platform prerequisites for Developer Hub capability.

```bash
helm get values -n <CP Namespace> platform-base -o yaml | helm upgrade --install -n <CP Namespace> tibco-cp-devhub tibco-platform-public/tibco-cp-devhub -f -
```
