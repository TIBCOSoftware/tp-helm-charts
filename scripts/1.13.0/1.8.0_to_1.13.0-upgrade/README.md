# TIBCO Control Plane Upgrade Assistant (1.8.0 ➜ 1.13.0)

This directory contains an interactive Bash script to assist with upgrading the TIBCO Control Plane from version 1.8.0 to 1.13.0.

File: `scripts/1.13.0/1.8.0_to_1.13.0-upgrade.sh`

---

## What the script does

- Prompts you interactively to:
  - Generate a single combined 1.13.0 values file from existing 1.8.0 `platform-bootstrap` and `platform-base` deployments or values files
  - Perform Helm upgrade to the unified `platform-base` chart (1.13.0+)
  - Clean up remaining `platform-bootstrap` resources after successful upgrade
- Enforces safe prechecks before extracting values or performing upgrades (including early, mode-specific dependency validation)
- Merges `platform-bootstrap` and `platform-base` values into a single unified values file for the combined chart
- Transforms recipe sections to match 1.13.0 chart structure
- Verifies the upgrade and reports chart/app version and pod readiness

---

## Key features

- Interactive flow with clear prompts and confirmations
- Three operation modes:
  1) Values generation (from files or from Helm)
  2) Helm upgrade (uses your 1.13.0-ready values)
  3) Bootstrap cleanup (removes legacy resources after upgrade)
- Strict version gating:
  - Validates currently deployed app_version is exactly `1.8.0` before values extraction or upgrade
  - Supports 1.13.x minor version upgrades when `UPGRADE_MINOR_VERSIONS=true`
- Release state awareness:
  - Confirms releases exist in the target namespace
  - Confirms release status is `deployed` (blocks on `pending-install`, `failed`, `pending-rollback`, etc.)
- Consistent version checks:
  - Uses `helm list -o json` to read `app_version`
  - Uses `helm status -o json` to read release status
- Retry-aware upgrades:
  - If a previous attempt reached `app_version` `1.13.0` but the release is in a failed-like state (e.g., `failed`, `pending-install`, `pending-rollback`, `pending-upgrade`, `superseded`), the script prompts to retry the 1.13.0 upgrade
- Post-upgrade verification:
  - Confirms chart name ends with `-${PLATFORM_CHART_VERSION}` (e.g., `-1.13.0`)
  - Confirms upgraded `app_version` is `1.13.0`
  - Reports pod readiness in the target namespace
- Clear errors for common scenarios (release not found, wrong version, non-deployed status)

---

## Prerequisites

- Bash 5+
- yq v4+ (required for all flows)
- Helm v3.17+ and jq v1.6+ (required for Helm extraction/upgrade/validation flows; validated immediately after selecting Helm flows)
- kubectl (required for namespace validation, secret creation, and post-upgrade pod checks)

The script validates these requirements depending on the chosen mode and exits with a helpful error if something is missing.

---

## How to run

1) Make executable and run:

```bash
chmod +x 1.8.0_to_1.13.0-upgrade.sh
./1.8.0_to_1.13.0-upgrade.sh
```

2) Follow the interactive prompts:
- Choose between:
  - Generate values file for 1.13.0 (combines bootstrap + base)
  - Perform Helm upgrade to unified platform-base chart
  - Clean up platform-bootstrap resources
- Provide namespace, release names (if different), and values file name as prompted
- When you choose a Helm-based flow (extraction or upgrade), Helm/jq availability is validated immediately

---

## Prechecks and validations

The script performs these checks before proceeding:

- Release existence:
  - `helm status <release> -n <ns>` must succeed for the selected chart(s)
- Release status:
  - Must be `deployed` before values extraction or upgrade
- Deployed version (pre-upgrade):
  - `app_version` must be exactly `1.8.0` for both `platform-bootstrap` and `platform-base` (unless `UPGRADE_MINOR_VERSIONS=true` for 1.13.x upgrades)
- Tools availability:
  - yq is always required
  - Helm and jq are required for Helm extraction/upgrade/validation (enforced as soon as you choose a Helm flow)
- Required secrets:
  - Creates `session-keys` secret if not present (from tibcoclusterenv or random values)
  - Creates CP encryption secret if not present (name/key configurable via values)

Additional behaviors:
- During values extraction from Helm, the script validates both releases for existence, `deployed` status, and `app_version == 1.8.0` before extracting values
- During upgrades, if a release is in a failed-like state but already at `app_version == 1.13.0`, you will be prompted to retry the 1.13.0 upgrade; otherwise, the script blocks and asks you to let's fix the state (e.g., rollback) first

If any check fails, the script prints a clear error and exits.

---

## Values transformation

The script automatically transforms 1.8.0 values to 1.13.0 structure:

- **Merges bootstrap and base values** into a single file
- **Migrates compute-services**:
  - Moves from `compute-services` (bootstrap) to `tp-cp-infra` (base)
  - Splits `resources` into `tp-cp-infra.resources.infra-compute-services`
- **Transforms recipe sections**:
  - `tp-cp-recipes.dp-oauth2proxy-recipes` → `dp-oauth2proxy-recipes` (root level)
  - `tp-cp-recipes.tp-cp-infra-recipes.capabilities.cpproxy` → `tp-cp-configuration.capabilities.cpproxy`
  - `tp-cp-recipes.tp-cp-infra-recipes.capabilities.integrationcore` → `tp-cp-configuration.capabilities.integrationcore`
  - `tp-cp-recipes.tp-cp-infra-recipes.capabilities.o11y` → `tp-cp-o11y.capabilities.o11y`
  - `tp-cp-recipes.tp-cp-infra-recipes.capabilities.monitorAgent` → `tp-cp-core-finops.monitoring-service.capabilities.monitorAgent`
- **Removes deprecated sections**:
  - `tp-cp-bootstrap` (merged into root)
  - `tp-cp-recipes` (transformed)
  - `tp-cp-msg-contrib`, `tp-cp-msg-recipes`, `tp-cp-tibcohub-contrib`, `tp-cp-integration`, `tp-cp-hawk`
- **Enables new components**:
  - `tp-cp-integration-common.enabled = true`
  - `tp-cp-cli.enabled = true`
  - `tp-cp-prometheus.enabled = true`
  - `tp-cp-auditsafe.enabled = true`

---

## Outputs

- Values generation mode produces a file named (by default):
  - `platform-1.13.0-values.yaml` (single combined file for unified chart)
- You can override the output filename during the interactive prompts

---

## Upgrade verification

After a successful upgrade, the script:

- Prints upgraded `app_version` and `chart` string for the unified `platform-base` chart
- Validates:
  - `chart` ends with `-${PLATFORM_CHART_VERSION}`
  - `app_version` equals `1.13.0`
- Checks all pods in the target namespace are in `Running/Completed` state and prints a short summary

---

## Bootstrap cleanup

After successfully upgrading to 1.13.0, run the cleanup mode to:

- Delete platform-bootstrap Helm secrets (without uninstalling the release)
- Clean up orphaned roles and rolebindings
- Remove orphaned deployments and HPAs (`hybrid-proxy`, `resource-set-operator`, `router`, `compute-services`)

**Important**: The script does NOT run `helm uninstall platform-bootstrap` because that would delete resources now managed by the unified `platform-base` chart. It only removes Helm metadata and truly orphaned resources.

Cleanup is gated by:
- `platform-base` must be at `app_version` `1.13.0` and status `deployed`
- User confirmation required before cleanup

---

## Notes and limitations

- The script does NOT perform application-level or functional tests
- It assumes your values files are correct and only:
  - Generates 1.13.0 values with structural transformations
  - Upgrades the chart to the requested `PLATFORM_CHART_VERSION`
  - Verifies versions and pod readiness
- For non-`deployed` release states (e.g., `failed`, `pending-install`, `pending-rollback`), fix the state (e.g., `helm rollback`) before proceeding
- The upgrade uses `--take-ownership` flag to transfer ownership of bootstrap resources to the unified chart

---

## Troubleshooting

- **"release not found"**: ensure the release exists in the namespace and names are correct
- **"status is 'pending-install' / 'failed'"**: investigate with `helm history` and `kubectl describe`/`logs`, resolve, then retry
- **"app_version is 'unknown'"**: the script reads app version from `helm list -o json`; verify Helm/jq are available and recent
- **Validation fails for pre-release charts**: ensure `PLATFORM_CHART_VERSION` matches your chart tag (e.g., `1.13.0-rc.1`); `app_version` remains `1.13.0`
- **"Namespace not found"**: verify the namespace exists and you have access
- **yq version issues**: ensure yq v4+ is installed; the script validates this at startup

---

## Migration path

This script handles the major architectural change in 1.13.0:

**Before (1.8.0)**:
- Two separate Helm charts: `platform-bootstrap` and `platform-base`
- Two separate releases in the cluster
- Separate values files

**After (1.13.0)**:
- Single unified Helm chart: `platform-base` (includes bootstrap components)
- Single release in the cluster
- Single combined values file
- `platform-bootstrap` release metadata cleaned up (but resources preserved under new ownership)
