# TIBCO CP base for FLOGO Capability

## Installation

Since this chart is using the same values as the `tibco-cp-base` chart, you can re-use the same values file. The chart will install the platform prerequisites for FLOGO capability.

```bash
helm get values -n <CP Namespace> tibco-cp-base -o yaml | helm upgrade --install -n <CP Namespace> tibco-cp-flogo tibco-platform-public/tibco-cp-flogo -f -
```
