# TIBCO Control Plane Upgrade Assistant (1.15.0 ➜ 1.16.0)

This directory contains an interactive Bash script to assist with upgrading the TIBCO Control Plane from version 1.15.0 to 1.16.0.

File: `scripts/1.16.0/upgrade.sh`

---

## What the script does

- Prompts you interactively to:
  - Generate 1.16.0 values file from an existing 1.15.0 deployment or from existing values files
  - Perform Helm upgrade to `tibco-cp-base` chart version 1.16.0
- Enforces safe prechecks before extracting values or performing upgrades (including early, mode-specific dependency validation)
- **Automatically removes deprecated flags and sections** during values generation:
  - Removes deprecated flags: `tp-cp-o11y.enabled`, `hybrid-proxy.enabled`, `resource-set-operator.enabled`, `router-operator.enabled`
  - Removes entire sections: `tp-cp-auditsafe`, `tp-dp-proxy`, `tp-cp-prometheus`, `global.external.db_ssl_root_cert`, `global.tibco.proxy`, `global.tibco.rbac`
- Produces versioned output values file for the control plane chart
- Verifies the upgrade and reports chart/app version and pod readiness
- **Note**: No bootstrap cleanup needed - single chart deployment only

---

## Key features

- Interactive flow with clear prompts and confirmations
- Two operation modes:
  1) Values generation (from files or from Helm)
  2) Helm upgrade (uses your 1.16.0-ready values)
- Single chart deployment:
  - Works with unified `tibco-cp-base` or `platform-base` chart only
  - Automatic cleanup of deprecated configuration during values generation
  - Flexible release naming support (prompts for control plane chart release name)
- Strict version gating:
  - Validates currently deployed app_version is exactly `1.15.0` before values extraction or upgrade
- Release state awareness:
  - Confirms release exists in the target namespace
  - Confirms release status is `deployed` (blocks on `pending-install`, `failed`, `pending-rollback`, etc.)
- Consistent version checks:
  - Uses `helm list -o json` to read `app_version`
  - Uses `helm status -o json` to read release status
- **Deprecated configuration cleanup**:
  - Automatically removes flags and sections that are no longer supported in 1.16.0
  - Ensures clean migration to the new version
- Retry-aware upgrades:
  - If a previous attempt reached `app_version` `1.16.0` but the release is in a failed-like state, the script prompts to retry the 1.16.0 upgrade
- Post-upgrade verification:
  - Confirms chart name ends with `-${CHART_VERSION}` (e.g., `-1.16.0`)
  - Confirms upgraded `app_version` is `1.16.0`
  - Reports pod readiness in the target namespace
- Clear errors for common scenarios (release not found, wrong version, non-deployed status)

---

## Prerequisites

- Bash 4+
- yq v4.45.4 or higher (required for all flows)
- Helm v3.17+ and jq-1.8+ (required for Helm extraction/upgrade/validation flows; validated immediately after selecting Helm flows)
- kubectl (required for post-upgrade pod checks and bootstrap cleanup)

The script validates these requirements depending on the chosen mode and exits with a helpful error if something is missing.

## How to run

1) Make executable and run:

```bash
chmod +x upgrade.sh
./upgrade.sh
```

2) Follow the interactive prompts:
- Choose between:
  - Generate values file for 1.16.0
  - Perform Helm upgrade
- Provide namespace, control plane release name, and values file name as prompted
- When you choose a Helm-based flow (extraction or upgrade), Helm/jq availability is validated immediately.

---

Note:
- Post-upgrade `app_version` is validated against `1.16.0` (without pre-release suffix)
- Chart name is validated against `-${CHART_VERSION}` (pre-release suffix allowed)

---

## Prechecks and validations

The script performs these checks before proceeding:

- Release existence:
  - `helm status <control-plane-release> -n <ns>` must succeed
- Release status:
  - Must be `deployed` before values extraction or upgrade
- Deployed version (pre-upgrade):
  - `app_version` must be exactly `1.15.0` for the control plane release
- Tools availability:
  - yq is always required
  - Helm and jq are required for Helm extraction/upgrade/validation (enforced as soon as you choose a Helm flow)

Additional behaviors:
- During values extraction from Helm, the script validates the release for existence, `deployed` status, and `app_version == 1.15.0` before extracting values.
- During upgrades, if a release is in a failed-like state but already at `app_version == 1.16.0`, you will be prompted to retry the 1.16.0 upgrade; otherwise, the script blocks and asks you to fix the state (e.g., rollback) first.

If any check fails, the script prints a clear error and exits.

---

## Deprecated Configuration Cleanup

The 1.16.0 upgrade automatically removes these deprecated items:

### **Removed Flags:**
- `tp-cp-prometheus.enabled` - Prometheus enabled flag
- `tp-cp-o11y.enabled` - Observability enabled flag
- `tp-cp-auditsafe.enabled` - Audit safe enabled flag (section preserved)
- `hybrid-proxy.enabled` - Hybrid proxy enabled flag  
- `resource-set-operator.enabled` - Resource set operator enabled flag
- `router-operator.enabled` - Router operator enabled flag
- `tp-cp-infra.enabled` - Infrastructure enabled flag

### **Removed Sections:**
- `tp-dp-proxy` - Entire data plane proxy configuration section
- `tp-cp-prometheus` - Entire Prometheus configuration section
- `global.external.db_ssl_root_cert` - Database SSL root certificate flag
- `global.tibco.proxy` - Entire proxy configuration (httpProxy, httpsProxy, noProxy)
- `global.tibco.rbac` - Entire RBAC configuration section
- `global.tibco.logging.fluentbit.image.name` - FluentBit image name
- `global.tibco.logging.fluentbit.image.pullPolicy` - FluentBit image pull policy
- `global.tibco.logging.repository` - Logging repository configuration
- `tp-cp-infra.dpMetadata` - Infrastructure metadata configuration
- `global.tibco.finops` - Finops configuration section

### **Preserved Sections:**
- `tp-cp-auditsafe` - Audit safe configuration section preserved (only `.enabled` flag removed)

### **What This Means:**
- These components are now managed differently in 1.16.0
- The script ensures clean migration by removing deprecated configuration
- Your 1.16.0 deployment will use the new configuration patterns automatically

---

## Outputs

- Values generation mode produces a values file named (by default):
  - `control-plane-<CHART_VERSION>.yaml`
- The generated file will have all deprecated flags and sections removed
- You can override output filename during the interactive prompts.

---

## Upgrade verification

After a successful upgrade, the script:

- Prints upgraded `app_version` and `chart` string for the control plane chart
- Validates:
  - `chart` ends with `-${CHART_VERSION}`
  - `app_version` equals `1.16.0`
- Checks all pods in the target namespace are in `Running/Completed` state and prints a short summary



## Notes and limitations

- The script does NOT perform application-level or functional tests.
- It assumes your values files are correct and only:
  - Generates 1.16.0 control plane values with deprecated configuration cleanup
  - Upgrades the chart to `tibco-cp-base` version 1.16.0
  - Verifies versions and pod readiness
- For non-`deployed` release states (e.g., `failed`, `pending-install`, `pending-rollback`), fix the state (e.g., `helm rollback`) before proceeding.
- **Single chart deployment**: Version 1.15.0+ has only one control plane chart - no bootstrap chart handling needed.
- **Automatic cleanup**: The 1.16.0 upgrade automatically removes deprecated flags and sections.

---

## Simplified Upgrade Process

The 1.16.0 upgrade maintains the simplicity of 1.15.0 with added cleanup:

- **Single chart**: Only one control plane chart to manage
- **No bootstrap cleanup**: No separate bootstrap chart exists
- **Flexible naming**: Script prompts for your control plane release name (could be `platform-base`, `tibco-cp-base`, or custom)
- **Automatic cleanup**: Deprecated configuration is removed automatically during values generation

Example upgrade command after generating values:
```bash
helm upgrade <your-release-name> tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  --values control-plane-1.16.0.yaml \
  --namespace <your-namespace>
```

---

## Troubleshooting

- "release not found": ensure the release exists in the namespace and name is correct
- "status is 'pending-install' / 'failed'": investigate with `helm history` and `kubectl describe`/`logs`, resolve, then retry
- "app_version is 'unknown'": the script now reads app version from `helm list -o json`; verify Helm/jq are available and recent
- "app_version is not 1.15.0": this script upgrades from 1.15.0 to 1.16.0 only; if you're on a different version, use the appropriate upgrade script
- Validation fails for pre-release charts: ensure `CHART_VERSION` matches your chart tag (e.g., `1.16.0-alpha.1`); `app_version` remains `1.16.0`
- Missing sections: Check that your input file is valid YAML and readable
- "yq command not found": Install yq v4.45.4 or higher for automatic deprecated configuration cleanup
- "Deprecated configuration errors": The script automatically removes deprecated flags; if you manually edited the file after generation, ensure deprecated items are removed

---

## Migration Impact

### **Before 1.16.0:**
```yaml
# These configurations were valid
tp-cp-prometheus:
  enabled: true
tp-cp-auditsafe:
  enabled: true
tp-dp-proxy:
  enabled: true
tp-cp-o11y:
  enabled: true
tp-cp-infra:
  enabled: true
  dpMetadata:
    dpCoreInfrastructureChartVersion: "1.16.1"
    dpCoreInfrastructureAppVersion: "1.16.0"
    dpConfigureNamespaceChartVersion: "1.15.4"
    dpConfigureNamespaceAppVersion: "1.15.0"
hybrid-proxy:
  enabled: true
resource-set-operator:
  enabled: true
router-operator:
  enabled: true
global:
  tibco:
    proxy:
      httpProxy: ""
      httpsProxy: ""
      noProxy: ""
    rbac:
      infra: true
    finops: "disable"
    logging:
      fluentbit:
        image:
          name: "common-fluentbit"
          pullPolicy: IfNotPresent
        repository: ""
  external:
    db_ssl_root_cert: ""
```

### **After 1.16.0:**
```yaml
# These sections are automatically removed or cleaned up
tp-cp-auditsafe:  # Section preserved, only .enabled flag removed
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1024Mi

# These entire sections are removed:
# tp-cp-prometheus, tp-dp-proxy, global.tibco.proxy, global.tibco.rbac, global.external.db_ssl_root_cert
# global.tibco.logging.fluentbit.image.name, global.tibco.logging.fluentbit.image.pullPolicy
# global.tibco.logging.repository, tp-cp-infra.dpMetadata, global.tibco.finops

# These flags are removed but sections may remain:
# hybrid-proxy.enabled, resource-set-operator.enabled, router-operator.enabled, tp-cp-o11y.enabled, tp-cp-infra.enabled
```

The upgrade script ensures you don't need to manually remove these deprecated configurations - it's handled automatically during the values generation process.
