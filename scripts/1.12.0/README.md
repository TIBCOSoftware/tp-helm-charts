# TIBCO Control Plane Upgrade Assistant (1.11.0 ➜ 1.12.0)

This directory contains an interactive Bash script to assist with upgrading the TIBCO Control Plane from version 1.11.0 to 1.12.0.

File: `scripts/1.12.0/upgrade.sh`

---

## What the script does

- Prompts you interactively to:
  - Generate 1.12.0 values files from an existing 1.11.0 deployment or from existing values files
  - Perform Helm upgrades for `platform-bootstrap` or `platform-base`
- Enforces safe prechecks before extracting values or performing upgrades (including early, mode-specific dependency validation)
- Produces versioned output values files
- Verifies the upgrade and reports chart/app version and pod readiness

---

## Key features

- Interactive flow with clear prompts and confirmations
- Two operation modes:
  1) Values generation (from files or from Helm)
  2) Helm upgrade (uses your 1.12.0-ready values)
- Strict version gating:
  - Validates currently deployed app_version is exactly `1.11.0` before values extraction or upgrade
- Release state awareness:
  - Confirms releases exist in the target namespace
  - Confirms release status is `deployed` (blocks on `pending-install`, `failed`, `pending-rollback`, etc.)
- Consistent version checks:
  - Uses `helm list -o json` to read `app_version`
  - Uses `helm status -o json` to read release status
- Retry-aware upgrades:
  - If a previous attempt reached `app_version` `1.12.0` but the release is in a failed-like state (e.g., `failed`, `pending-install`, `pending-rollback`, `pending-upgrade`, `superseded`), the script prompts to retry the 1.12.0 upgrade.
- Post-upgrade verification:
  - Confirms chart name ends with `-${CHART_VERSION}` (e.g., `-1.12.0`)
  - Confirms upgraded `app_version` is `1.12.0`
  - Reports pod readiness in the target namespace
- Clear errors for common scenarios (release not found, wrong version, non-deployed status)

---

## Prerequisites

- Bash 4+
- yq v4+ (required for all flows)
- Helm v3.17+ and jq v1.6+ (required for Helm extraction/upgrade/validation flows; validated immediately after selecting Helm flows)
- kubectl (required for post-upgrade pod checks)

The script validates these requirements depending on the chosen mode and exits with a helpful error if something is missing.

---

## How to run

1) Make executable and run:

```bash
chmod +x upgrade.sh
./upgrade.sh
```

2) Follow the interactive prompts:
- Choose between:
  - Generate values files for 1.12.0
  - Perform Helm upgrade
- Provide namespace, release names (if different), and values file name as prompted
- When you choose a Helm-based flow (extraction or upgrade), Helm/jq availability is validated immediately.

---

## Environment variables

- `CHART_VERSION` (optional): overrides the default target chart version.
  - Default is `1.12.0` (or whatever is set in the script).
  - Example:
    - Linux: `export CHART_VERSION="1.12.0-alpha.1" && ./upgrade.sh`

Note:
- Post-upgrade `app_version` is validated against `1.12.0` (without pre-release suffix)
- Chart name is validated against `-${CHART_VERSION}` (pre-release suffix allowed)

---

## Prechecks and validations

The script performs these checks before proceeding:

- Release existence:
  - `helm status <release> -n <ns>` must succeed for the selected chart(s)
- Release status:
  - Must be `deployed` before values extraction or upgrade
- Deployed version (pre-upgrade):
  - `app_version` must be exactly `1.11.0` for both `platform-bootstrap` and `platform-base`
- Tools availability:
  - yq is always required
  - Helm and jq are required for Helm extraction/upgrade/validation (enforced as soon as you choose a Helm flow)

Additional behaviors:
- During values extraction from Helm, the script validates both releases for existence, `deployed` status, and `app_version == 1.11.0` before extracting values.
- During upgrades, if a release is in a failed-like state but already at `app_version == 1.12.0`, you will be prompted to retry the 1.12.0 upgrade; otherwise, the script blocks and asks you to fix the state (e.g., rollback) first.

If any check fails, the script prints a clear error and exits.

---

## Outputs

- Values generation mode produces files named (by default):
  - `platform-base-<CHART_VERSION>.yaml`
  - `platform-bootstrap-<CHART_VERSION>.yaml`
- You can override output filenames during the interactive prompts.

---

## Upgrade verification

After a successful upgrade, the script:

- Prints upgraded `app_version` and `chart` string for each selected chart
- Validates:
  - `chart` ends with `-${CHART_VERSION}`
  - `app_version` equals `1.12.0`
- Checks all pods in the target namespace are in `Running/Completed` state and prints a short summary

---

## Notes and limitations

- The script does NOT perform application-level or functional tests.
- It assumes your values files are correct and only:
  - Generates 1.12.0 values (no schema transformations for this release)
  - Upgrades the charts to the requested `CHART_VERSION`
  - Verifies versions and pod readiness
- For non-`deployed` release states (e.g., `failed`, `pending-install`, `pending-rollback`), fix the state (e.g., `helm rollback`) before proceeding.

---

## Troubleshooting

- "release not found": ensure the release exists in the namespace and names are correct
- "status is 'pending-install' / 'failed'": investigate with `helm history` and `kubectl describe`/`logs`, resolve, then retry
- "app_version is 'unknown'": the script now reads app version from `helm list -o json`; verify Helm/jq are available and recent
- Validation fails for pre-release charts: ensure `CHART_VERSION` matches your chart tag (e.g., `1.12.0-alpha.1`); `app_version` remains `1.12.0`
