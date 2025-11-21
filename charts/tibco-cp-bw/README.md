# TIBCO CP base for BW Capability

## Installation

Since this chart is using the same values as the `tibco-cp-base` chart, you can re-use the same values file. The chart will install the platform prerequisites for BW capability.

```bash
helm get values -n <CP Namespace> tibco-cp-base -o yaml | helm upgrade --install -n <CP Namespace> tibco-cp-bw tibco-platform-public/tibco-cp-bw -f -
```
