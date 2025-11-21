# TIBCO Control Plane Upgrade Assistant (1.12.0 ➜ 1.13.0)

This directory contains an interactive Bash script to assist with upgrading the TIBCO Control Plane from version 1.12.0 to 1.13.0.

File: `scripts/1.13.0/upgrade.sh`

---

## What the script does

- Prompts you interactively to:
  - Generate 1.13.0 merged values file from an existing 1.12.0 deployment or from existing values files
  - Perform Helm upgrades to the unified `tibco-cp-base` chart
- Enforces safe prechecks before extracting values or performing upgrades (including early, mode-specific dependency validation)
- Produces versioned output merged values file for the new unified chart
- Verifies the upgrade and reports chart/app version and pod readiness
- Provides interactive cleanup of platform-bootstrap resources

---

## Key features

- Interactive flow with clear prompts and confirmations
- Two operation modes:
  1) Values generation (from files or from Helm)
  2) Helm upgrade (uses your 1.13.0-ready values)
- Chart consolidation:
  - Merges `platform-bootstrap` and `platform-base` into unified `tibco-cp-base` chart
  - Intelligent values merging with conflict resolution
- Strict version gating:
  - Validates currently deployed app_version is exactly `1.12.0` before values extraction or upgrade
- Release state awareness:
  - Confirms releases exist in the target namespace
  - Confirms release status is `deployed` (blocks on `pending-install`, `failed`, `pending-rollback`, etc.)
- Consistent version checks:
  - Uses `helm list -o json` to read `app_version`
  - Uses `helm status -o json` to read release status
- Retry-aware upgrades:
  - If a previous attempt reached `app_version` `1.13.0` but the release is in a failed-like state, the script prompts to retry the 1.13.0 upgrade
- Post-upgrade verification:
  - Confirms chart name ends with `-${CHART_VERSION}` (e.g., `-1.13.0`)
  - Confirms upgraded `app_version` is `1.13.0`
  - Reports pod readiness in the target namespace
- Interactive bootstrap cleanup:
  - Automated cleanup of orphaned bootstrap resources after upgrade
  - Safe removal of Helm metadata and truly orphaned resources
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
  - Generate merged values file for 1.13.0
  - Perform Helm upgrade
- Provide namespace, release names (if different), and values file name as prompted
- When you choose a Helm-based flow (extraction or upgrade), Helm/jq availability is validated immediately.

---

Note:
- Post-upgrade `app_version` is validated against `1.13.0` (without pre-release suffix)
- Chart name is validated against `-${CHART_VERSION}` (pre-release suffix allowed)

---

## Prechecks and validations

The script performs these checks before proceeding:

- Release existence:
  - `helm status <release> -n <ns>` must succeed for both `platform-bootstrap` and `platform-base`
- Release status:
  - Must be `deployed` before values extraction or upgrade
- Deployed version (pre-upgrade):
  - `app_version` must be exactly `1.12.0` for both `platform-bootstrap` and `platform-base`
- Tools availability:
  - yq is always required
  - Helm and jq are required for Helm extraction/upgrade/validation (enforced as soon as you choose a Helm flow)

Additional behaviors:
- During values extraction from Helm, the script validates both releases for existence, `deployed` status, and `app_version == 1.12.0` before extracting values.
- During upgrades, if a release is in a failed-like state but already at `app_version == 1.13.0`, you will be prompted to retry the 1.13.0 upgrade; otherwise, the script blocks and asks you to fix the state (e.g., rollback) first.

If any check fails, the script prints a clear error and exits.

---

## Outputs

- Values generation mode produces a merged file named (by default):
  - `tibco-cp-base-merged-<CHART_VERSION>.yaml`
- You can override output filename during the interactive prompts.

---

## Upgrade verification

After a successful upgrade, the script:

- Prints upgraded `app_version` and `chart` string for the unified chart
- Validates:
  - `chart` ends with `-${CHART_VERSION}`
  - `app_version` equals `1.13.0`
- Checks all pods in the target namespace are in `Running/Completed` state and prints a short summary




## Notes and limitations

- The script does NOT perform application-level or functional tests.
- It assumes your values files are correct and only:
  - Generates 1.13.0 merged values (intelligent merging of bootstrap and base values)
  - Upgrades the charts to the unified `tibco-cp-base` chart at the requested `CHART_VERSION`
  - Verifies versions and pod readiness
- For non-`deployed` release states (e.g., `failed`, `pending-install`, `pending-rollback`), fix the state (e.g., `helm rollback`) before proceeding.
- **Platform-bootstrap ownership**: After upgrade, the platform-bootstrap release remains installed but becomes inactive. Do NOT uninstall it using `helm uninstall` as this will delete resources.
- **Resource ownership**: The script uses Helm's `--take-ownership` flag to transfer resource management from platform-bootstrap to the unified tibco-cp-base release.

---

## Manual Bootstrap Cleanup

If the automated bootstrap cleanup fails or you need to perform manual cleanup later, use these commands:

```bash
# 1. Remove platform-bootstrap Helm metadata (safe - does not delete resources)
kubectl delete secret -n <your-namespace> -l "owner=helm,name=platform-bootstrap"

# 2. Remove orphaned bootstrap resources (only if not managed by platform-base release)
kubectl delete -n <your-namespace> deployment/tp-cp-hybrid-proxy deployment/tp-cp-resource-set-operator deployment/tp-cp-router deployment/otel-services

# 3. Remove orphaned HPA resources
kubectl delete -n <your-namespace> hpa/tp-cp-hybrid-proxy hpa/tp-cp-router hpa/otel-services

# 4. Remove bootstrap-specific RBAC resources
kubectl delete role,rolebinding -n <your-namespace> -l app.kubernetes.io/instance=platform-bootstrap
```

**Important**: 
- Do NOT use `helm uninstall platform-bootstrap` as this will delete resources still managed by the unified tibco-cp-base release
- Only run these commands if the automated cleanup fails or you skipped it during the upgrade process
- Verify resources are truly orphaned before deletion by checking if they're managed by the tibco-cp-base release

---

## Troubleshooting

- "release not found": ensure the release exists in the namespace and names are correct
- "status is 'pending-install' / 'failed'": investigate with `helm history` and `kubectl describe`/`logs`, resolve, then retry
- "app_version is 'unknown'": the script now reads app version from `helm list -o json`; verify Helm/jq are available and recent
- Validation fails for pre-release charts: ensure `CHART_VERSION` matches your chart tag (e.g., `1.13.0-alpha.1`); `app_version` remains `1.13.0`
- Merge conflicts: The script prioritizes base values over bootstrap values for conflicts
- Missing sections: Check that your input files are valid YAML and readable

