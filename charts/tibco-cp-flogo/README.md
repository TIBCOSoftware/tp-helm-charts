# TIBCO CP FLOGO Chart

## Installation

1. Update your local Helm repository with the latest charts:

```bash
helm repo update
```

2. Extract the values from your existing `platform-base` release into a new file. The `tibco-cp-flogo` chart uses the common values from the `platform-base` chart.

```bash
helm get values -n <control_plane_namespace> platform-base > tibco-cp-flogo-values.yaml
```

3. Review the generated `tibco-cp-flogo-values.yaml` file and make any necessary customizations for your environment.

4. Install the `tibco-cp-flogo` chart using the values file you just created:

```bash
helm upgrade --install -n <control_plane_namespace> tibco-cp-flogo tibco-platform-public/tibco-cp-flogo --version=1.13.0 -f tibco-cp-flogo-values.yaml
```

## Cleanup Job

5. (Optional): To clean up EFS data during the uninstallation of the `tibco-cp-flogo` chart, install the chart using the following command:

```bash
helm upgrade --install -n <control_plane_namespace> tibco-cp-flogo tibco-platform-public/tibco-cp-flogo --version=1.13.0 -f tibco-cp-flogo-values.yaml --set flogo-utilities.cleanupJob=true --set flogo-recipes.cleanupJob=true
```

## Uninstallation

### Before you begin:

Delete your deployed FLOGO apps before uninstalling the `tibco-cp-flogo` chart. If you do not delete the FLOGO apps, they will continue to run but cannot be accessed from the UI.

To uninstall the `tibco-cp-flogo` chart, run the following command:

```bash
helm uninstall -n <control_plane_namespace> tibco-cp-flogo
```

### Note:

- If you install the `tibco-cp-flogo` chart with the `cleanupJob` flags set to true (--set flogo-utilities.cleanupJob=true --set flogo-recipes.cleanupJob=true), then flogo-specific EFS data is cleaned up automatically during uninstallation.

- If you did not set the cleanup flags during installation and need to clean up EFS data, re-install the `tibco-cp-flogo` chart with the `cleanupJob` flags enabled using the following command, then uninstall the chart:

```bash
helm get values -n <control_plane_namespace> tibco-cp-flogo -o yaml | helm upgrade --install -n <control_plane_namespace> tibco-cp-flogo tibco-platform-public/tibco-cp-flogo --version=1.13.0 --set flogo-utilities.cleanupJob=true --set flogo-recipes.cleanupJob=true -f -
```
