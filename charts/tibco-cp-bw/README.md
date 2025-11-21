# TIBCO CP BW Chart

## Installation

1. Update your local Helm repository with the latest charts:

```bash
helm repo update
```

2. Extract the values from your existing `platform-base` release into a new file. The `tibco-cp-bw` chart uses the common values from the `platform-base` chart.

```bash
helm get values -n <control_plane_namespace> platform-base > tibco-cp-bw-values.yaml
```

3. Review the generated `tibco-cp-bw-values.yaml` file and make any necessary customizations for your environment.

4. Install the `tibco-cp-bw` chart using the values file you just created:

```bash
helm upgrade --install -n <control_plane_namespace> tibco-cp-bw tibco-platform-public/tibco-cp-bw --version=1.13.0 -f tibco-cp-bw-values.yaml
```

## Cleanup Job

5. (Optional): To clean up EFS data during the uninstallation of the `tibco-cp-bw` chart, install the chart using the following command:

```bash
helm upgrade --install -n <control_plane_namespace> tibco-cp-bw tibco-platform-public/tibco-cp-bw --version=1.13.0 -f tibco-cp-bw-values.yaml --set bwce-utilities.bwCleanupJob=true --set bw5ce-utilities.bw5CleanupJob=true --set bw-recipes.recipeCleanupJob=true
```

## Uninstallation

### Before you begin:

Delete your deployed BW apps before uninstalling the `tibco-cp-bw` chart. If you do not delete the BW apps, they will continue to run but cannot be accessed from the UI.

To uninstall the `tibco-cp-bw` chart, run the following command:

```bash
helm uninstall -n <control_plane_namespace> tibco-cp-bw
```

### Note:

- If you install the `tibco-cp-bw` chart with the cleanup flags set to true (--set bwce-utilities.bwCleanupJob=true --set bw5ce-utilities.bw5CleanupJob=true --set bw-recipes.recipeCleanupJob=true), then bw-specific EFS data is cleaned up automatically during uninstallation.

- If you did not set the cleanup flags during installation and need to clean up EFS data, re-install the `tibco-cp-bw` chart with the cleanup flags enabled using the following command, then uninstall the chart:

```bash
helm get values -n <control_plane_namespace> tibco-cp-bw -o yaml | helm upgrade --install -n <control_plane_namespace> tibco-cp-bw tibco-platform-public/tibco-cp-bw --version=1.13.0 --set bwce-utilities.bwCleanupJob=true --set bw5ce-utilities.bw5CleanupJob=true --set bw-recipes.recipeCleanupJob=true -f -
```
