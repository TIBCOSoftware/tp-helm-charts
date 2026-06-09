<!-- 
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

# TIBCO Control Plane Upgrade Assistant (1.17.0 ➜ 1.18.0)

This directory contains an interactive Bash script to assist with upgrading the TIBCO Control Plane from version 1.17.0 to 1.18.0.

File: `scripts/1.18.0/upgrade.sh`

---

## What the script does

- Prompts you interactively to:
  - Generate 1.18.0 values file from an existing 1.17.0 deployment or from existing values files
  - Perform Helm upgrade to `tibco-cp-base` chart version 1.18.0
- Enforces safe prechecks before extracting values or performing upgrades (including early, mode-specific dependency validation)
- **Automatically removes deprecated email server configuration fields** during values generation:
  - Removes deprecated field: `global.external.emailServerType`
  - Removes deprecated field: `global.external.fromAndReplyToEmailAddress`
  - Removes deprecated field: `global.external.cronJobReportsEmailAlias`
  - Removes deprecated field: `global.external.platformEmailNotificationCcAddresses`
  - Removes deprecated section: `global.external.emailServer`
- Produces versioned output values file for the control plane chart
- Verifies the upgrade and reports chart/app version and pod readiness
- **Note**: No bootstrap cleanup needed - single chart deployment only

---

## Key features

- Interactive flow with clear prompts and confirmations
- Two operation modes:
  1) Values generation (from files or from Helm)
  2) Helm upgrade (uses your 1.18.0-ready values)
- Single chart deployment:
  - Works with unified `tibco-cp-base` or `platform-base` chart only
  - Automatic cleanup of deprecated email server configuration during values generation
  - Flexible release naming support (prompts for control plane chart release name)
- **Deprecated configuration cleanup**:
  - Automatically removes email server fields that are no longer supported in 1.18.0
  - Ensures clean migration to the new version
- Strict version gating:
  - Validates currently deployed app_version is exactly `1.17.0` before values extraction or upgrade
- Release state awareness:
  - Confirms release exists in the target namespace
  - Confirms release status is `deployed` (blocks on `pending-install`, `failed`, `pending-rollback`, etc.)
- Consistent version checks:
  - Uses `helm list -o json` to read `app_version`
  - Uses `helm status -o json` to read release status
- Retry-aware upgrades:
  - If a previous attempt reached `app_version` `1.18.0` but the release is in a failed-like state, the script prompts to retry the 1.18.0 upgrade
- Post-upgrade verification:
  - Confirms chart name ends with `-${CHART_VERSION}` (e.g., `-1.18.0`)
  - Confirms upgraded `app_version` is `1.18.0`
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
  - Generate values file for 1.18.0
  - Perform Helm upgrade
- Provide namespace, control plane release name, and values file name as prompted
- When you choose a Helm-based flow (extraction or upgrade), Helm/jq availability is validated immediately.

---

Note:
- Post-upgrade `app_version` is validated against `1.18.0` (without pre-release suffix)
- Chart name is validated against `-${CHART_VERSION}` (pre-release suffix allowed)

---

## Prechecks and validations

The script performs these checks before proceeding:

- Release existence:
  - `helm status <control-plane-release> -n <ns>` must succeed
- Release status:
  - Must be `deployed` before values extraction or upgrade
- Deployed version (pre-upgrade):
  - `app_version` must be exactly `1.17.0` for the control plane release
- Tools availability:
  - yq is always required
  - Helm and jq are required for Helm extraction/upgrade/validation (enforced as soon as you choose a Helm flow)

Additional behaviors:
- During values extraction from Helm, the script validates the release for existence, `deployed` status, and `app_version == 1.17.0` before extracting values.
- During upgrades, if a release is in a failed-like state but already at `app_version == 1.18.0`, you will be prompted to retry the 1.18.0 upgrade; otherwise, the script blocks and asks you to fix the state (e.g., rollback) first.

If any check fails, the script prints a clear error and exits.

---

## Version-Specific Changes

The following deprecated email server configuration fields are automatically removed during values generation:

| Field | Path |
|---|---|
| `emailServerType` | `global.external.emailServerType` |
| `fromAndReplyToEmailAddress` | `global.external.fromAndReplyToEmailAddress` |
| `cronJobReportsEmailAlias` | `global.external.cronJobReportsEmailAlias` |
| `platformEmailNotificationCcAddresses` | `global.external.platformEmailNotificationCcAddresses` |
| `emailServer` | `global.external.emailServer` |

These fields were previously used for email server configuration and are no longer supported in 1.18.0. The upgrade script removes them automatically so they do not cause issues with the new chart version.
