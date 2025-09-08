# TIBCO Control Plane Upgrade Assistant (1.9.0 ➜ 1.10.0)

This directory contains an interactive Bash script to assist with upgrading the TIBCO Control Plane from version 1.9.0 to 1.10.0.

File: `scripts/1.10.0/upgrade.sh`

---

## What the script does

- Guides you interactively to either:
  - Generate 1.10.0-ready values files from your current 1.9.0 setup (from existing values files or by extracting from Helm), or
  - Perform Helm upgrades for `platform-bootstrap` or `platform-base` using 1.10.0 values
- Validates tool prerequisites and (when applicable) currently deployed app versions
- Produces versioned output values files
- Verifies upgrades and reports release state and pod readiness

---

## Key features

- Interactive flow with clear prompts
- Two operation modes:
  1) Values generation (from files or from Helm extraction)
  2) Helm upgrade (uses your 1.10.0-ready values)
- Version gating for upgrade mode:
  - Validates the currently deployed `app_version` is exactly `1.9.0` before upgrading
- Repository management:
  - Updates the specified Helm repo before upgrade
- Post-upgrade verification:
  - Confirms releases exist and checks pod readiness in the target namespace
- Input/Output convenience:
  - Lets you specify custom output filenames; defaults to versioned filenames

---

## Prerequisites

- Bash 4+
- yq v4+ (required for all flows)
- Helm v3.17+ (required for Helm extraction/upgrade flows)
- jq v1.5+ (required for JSON parsing during upgrade validation)
- kubectl (required for post-upgrade pod checks)

The script validates these requirements depending on the chosen mode and exits with a helpful error if something is missing. It also provides soft version warnings for yq and jq when applicable.

---

## How to run

1) Make executable and run:

```bash
chmod +x upgrade.sh
./upgrade.sh
```

2) Follow the interactive prompts:
- Choose between:
  - Generate values files for 1.10.0
  - Perform Helm upgrade
- Provide namespace, release names (if different), and values file names as prompted

---

## Environment variables

- `CHART_VERSION` (optional): overrides the default target chart version for upgrades.
  - Default is `1.10.0` (as set in the script).
  - Example:
    - Linux/macOS: `export CHART_VERSION="1.10.0" && ./upgrade.sh`

Note:
- Pre-upgrade validation checks `app_version` equals `1.9.0`.

---

## Prechecks and validations

- Tools availability:
  - yq is always required
  - Helm and jq are required for Helm extraction/upgrade/validation
  - kubectl is required for post-upgrade verification
- Deployed version (pre-upgrade):
  - For the selected chart(s), `helm list -o json | jq -r '.[0].app_version'` must report exactly `1.9.0`
- Release existence (verification):
  - `helm status <release> -n <ns>` must succeed for the selected chart(s)

If any check fails, the script prints a clear error and exits.

---

## Outputs (Values generation mode)

By default, the script generates the following files (unless you override the names in prompts):

- `platform-base-1.10.0.yaml`
- `platform-bootstrap-1.10.0.yaml`

These are produced based on your input values or values extracted from Helm.

---

## Schema/values migration logic (1.9.0 ➜ 1.10.0)

During values generation, the script will:

- compute-services migration (from platform-bootstrap to platform-base):
  - If a `.compute-services` section is found in the 1.9.0 `platform-bootstrap` values:
    - It is migrated to a new `tp-cp-infra` section at the root of `platform-base` values.
    - If `.compute-services.resources` exists, it is placed under:
      - `tp-cp-infra.resources.infra-compute-services`
    - The rest of `.compute-services` is placed under `tp-cp-infra`.
    - The `.compute-services` key is removed from the generated `platform-bootstrap` output.
  - If no `.compute-services` section is present, the bootstrap file is copied as-is.

- dnsTunnelDomain propagation:
  - If `dnsTunnelDomain` is found in either input values file, it is written into
    `global.external.dnsTunnelDomain` in the generated `platform-base` values.

- File handling robustness:
  - The script captures file contents before transformations and uses `yq` via stdin
    to minimize race conditions.

This logic aligns the values structure expected by 1.10.0 charts while preserving relevant configuration from your 1.9.0 setup.

---

## Helm upgrade flow (optional)

If you choose the Helm upgrade mode:

- You select which chart to upgrade: `platform-bootstrap` or `platform-base`.
- You provide the corresponding 1.10.0 values file.
- The script validates the current deployed `app_version` is `1.9.0` for the selected release.
- The script updates the specified Helm repo and runs `helm upgrade --wait` with a chart `--version` (default `1.10.0`).
- Post-upgrade, the script verifies the release exists and reports pod readiness for the namespace.

---

## Upgrade verification

After a successful upgrade, the script:

- Confirms `helm status <release> -n <ns>` succeeds for the selected chart(s)
- Checks all pods in the target namespace and warns if any are not in `Running/Completed` state

---

## Notes and limitations

- The script does NOT perform application-level or functional tests.
- It assumes your values files are correct and focuses on:
  - Generating 1.10.0 values with the 1.9 ➜ 1.10 migration adjustments described above
  - Upgrading charts to the requested `CHART_VERSION`
  - Verifying releases exist and pods are Ready/Completed
- For non-`deployed` or problematic release states, investigate with `helm history`, `helm status -o json`, and `kubectl describe`/`logs` and resolve before retrying.

---

## Troubleshooting

- "release not found": ensure the release exists in the namespace and names are correct
- "app_version is 'unknown'": verify Helm/jq are available; the script reads app version from `helm list -o json`
- jq/yq not found or old: install/upgrade to the versions listed in prerequisites
- Pods not ready after upgrade: use `kubectl get pods -n <ns>`, `kubectl describe`, and `kubectl logs` to investigate
