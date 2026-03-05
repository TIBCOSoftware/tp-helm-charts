# TIBCO Control Plane - Master Upgrade Script

> **Note**: This master upgrade script has been tested and validated for sequential upgrades across multiple versions (1.10.0 → 1.11.0 → 1.12.0 → 1.13.0 → 1.14.0). The script handles both pre-1.13.0 (separate bootstrap/base charts) and post-1.13.0 (unified tibco-cp-base chart) deployments with intelligent file naming based on version.

## Quick Start

```bash
cd /path/to/tibco-platform/scripts

# Set execute permissions on all scripts (REQUIRED)
chmod +x upgrade.sh
chmod +x */upgrade.sh

# Run the upgrade
./upgrade.sh
```

## What It Does

This script automatically upgrades your TIBCO Control Plane from the current version to your selected target version (or latest) through sequential upgrades.

### 🎯 Smart Version Detection & Selection

The script **automatically discovers** all available versions by scanning the `scripts/` directory:
- Finds all version folders (e.g., `1.10.0/`, `1.11.0/`, `1.12.0/`, `1.13.0/`, `1.14.0/`)
- Identifies the **highest version** as the latest
- **Numbered Selection Menu**: Choose from numbered list (1, 2, 3...)
- **Auto-Select Latest**: Press Enter without input to automatically select latest version
- **Version Validation**: Only shows versions >= your current version (prevents downgrades)
- Builds the upgrade path dynamically to your selected target
- **No hardcoding needed!** When you add version `1.14.0/` with `upgrade.sh`, it's automatically detected

### Process for Each Version

#### For Pre-1.13.0 Versions:
1. **Generate values.yaml files** from current Helm deployment
   - Creates: `platform-base-VERSION.yaml` and `platform-bootstrap-VERSION.yaml`
2. **Upgrade platform-bootstrap** chart
3. **Upgrade platform-base** chart  
4. **Verify** upgrade success and pod status

#### For 1.13.0+ Versions (Unified Chart):
1. **Generate unified values.yaml** from current Helm deployment
   - Both versions use the same `tibco-cp-base` chart, but different default file names:
   - **1.13.0**: Creates `tibco-cp-base-merged-1.13.0.yaml` (naming convention from 1.13.0 script)
   - **1.14.0+**: Creates `control-plane-VERSION.yaml` (updated naming convention)
2. **Upgrade tibco-cp-base** chart only (bootstrap merged into base)
3. **Verify** upgrade success and pod status

## Interactive Prompts

When you run the script, it will ask you:

```
Enter Kubernetes namespace containing your deployments: [your-namespace]
Platform Base release name (default: platform-base): [press Enter or type custom name]
Helm repository name (default: tibco-platform): [press Enter or type custom name]
```

Then it will:
- ✅ Detect your current chart versions
- ✅ **Smart Bootstrap Prompt**: Only asks for Bootstrap release name if you're on version < 1.13.0
  - **Version 1.13.0+**: Skips Bootstrap prompt (chart is merged into Base)
  - **Version < 1.13.0**: Asks for Bootstrap release name
- ✅ **NEW: Numbered Target Version Selection** - Easy version selection:
  - Displays numbered menu: `1. 1.12.0`, `2. 1.13.0 (current)`, `3. 1.14.0`
  - Enter number (1, 2, 3...) to select specific version
  - Press Enter to automatically select latest version
  - Shows clear labels: (current) for current version
  - Only shows versions >= current (prevents downgrades)
  - Validates all input
- ✅ Calculate the upgrade path to your selected target
- ✅ Show you what will happen
- ✅ Ask for ONE final confirmation

After you confirm with `yes`, everything runs automatically.

# Run master upgrade
./upgrade.sh

### **Important Notes:**

⚠️ **Pre-release versions may not be stable**
- **INTERNAL USE ONLY** - For testing and development
- Test in development environment first
- Have rollback plan ready
- Check Helm repository for available versions:
  ```bash
  helm search repo tibco-platform/tibco-cp-base --versions
  helm search repo tibco-platform/platform-base --versions
  ```

## Example Session

### Example 1: Current Version < 1.13.0 (Bootstrap prompt shown)

```bash
$ ./upgrade.sh

╔════════════════════════════════════════════════════════════════╗
║  TIBCO Control Plane Master Upgrade Script
╚════════════════════════════════════════════════════════════════╝

Enter Kubernetes namespace containing your deployments: tibco-platform
Platform Base release name (default: platform-base): [Enter]
Helm repository name (default: tibco-platform): [Enter]

[SUCCESS] Basic configuration completed
[INFO] Logging to: /path/to/logs/upgrade-20250117-073000.log

[STEP] Discovering available upgrade versions...
[INFO] Found 4 version(s): 1.10.0 1.11.0 1.12.0 1.13.0
[SUCCESS] Latest version detected: 1.13.0
[INFO]   Mapping: 1.10.0 → 1.11.0
[INFO]   Mapping: 1.11.0 → 1.12.0
[INFO]   Mapping: 1.12.0 → 1.13.0

[STEP] Checking dependencies...
[SUCCESS] All dependencies are installed

[STEP] Verifying namespace: tibco-platform
[SUCCESS] Namespace verified

[STEP] Detecting current chart versions...
[INFO] Chart Status:
[INFO]   platform-bootstrap: version=1.11.0, status=deployed
[INFO]   platform-base: version=1.11.0, status=deployed
[SUCCESS] Current version: 1.11.0

[INFO] Version 1.11.0 detected (pre-1.13.0): Bootstrap chart is separate
Platform Bootstrap release name (default: platform-bootstrap): [Enter]
[SUCCESS] Bootstrap configuration completed

[STEP] Select Target Version for Upgrade

[INFO] Available upgrade versions:
  1. 1.11.0 (current)
  2. 1.12.0
  3. 1.13.0

[INFO] Default: 1.13.0 (latest)

Select target version [1-3] (press Enter for latest): [Enter]
[SUCCESS] Selected latest version: 1.13.0

[STEP] Calculating upgrade path from 1.11.0 to 1.13.0...
[INFO]   1.11.0 → 1.12.0
[INFO]   1.12.0 → 1.13.0
[SUCCESS] Upgrade path calculated: 2 step(s)

╔════════════════════════════════════════════════════════════════╗
║  TIBCO PLATFORM CHARTS UPGRADE WORKFLOW
╚════════════════════════════════════════════════════════════════╝

📊 Current Status:
  • Namespace: tibco-platform
  • Current Version: 1.11.0
  • Platform Base Release: platform-base
  • Platform Bootstrap Release: platform-bootstrap

🎯 Upgrade Workflow:
  • Target Version: 1.13.0
  • Sequential upgrade from 1.11.0 to 1.13.0
  • Number of upgrade steps: 2
  • Upgrade path: 1.11.0 → 1.12.0 → 1.13.0

🔄 What will happen for EACH version:
  1. Generate values.yaml from current Helm deployment
  2. Upgrade platform-bootstrap chart (for versions < 1.13.0)
  3. Upgrade platform-base chart (for versions < 1.13.0)
  2. Upgrade tibco-cp-base chart only (for versions >= 1.13.0)
  3. Verify upgrade success and pod status

📝 All upgrade logs will be shown on screen and saved to:
  /path/to/logs/upgrade-20250117-073000.log

⚠️  Ensure you have reviewed the upgrade requirements
⚠️  Have a rollback plan ready if needed

Do you want to proceed with the sequential upgrade? (yes/no): yes

╔════════════════════════════════════════════════════════════════╗
║  UPGRADING TO TIBCO CONTROL PLANE VERSION 1.12.0
╚════════════════════════════════════════════════════════════════╝

[STEP] STEP 1/3: Generating values files from current deployment
[INFO]   ├─ Selecting: Generate values.yaml files (Option 1)
[INFO]   ├─ Source: Extract from running Helm deployments (Option 2)
[INFO]   ├─ Namespace: tibco-platform
[INFO]   ├─ Bootstrap release: platform-bootstrap
[INFO]   ├─ Base release: platform-base
[INFO]   └─ Output files: platform-base-1.12.0.yaml, platform-bootstrap-1.12.0.yaml

[INFO] >>> Executing upgrade script for values generation...

=== BEGIN VALUES GENERATION LOG ===
(full output from upgrade script shown here)
=== END VALUES GENERATION LOG ===

[SUCCESS] ✓ Values files generated

[STEP] STEP 2/3: Upgrading platform-bootstrap chart
[INFO]   ├─ Selecting: Perform Helm upgrade (Option 2)
[INFO]   ├─ Chart selection: platform-bootstrap (Option 1)
[INFO]   ├─ Values file: platform-bootstrap-1.12.0.yaml
[INFO]   ├─ Namespace: tibco-platform
[INFO]   ├─ Release: platform-bootstrap
[INFO]   └─ Helm repo: tibco-platform

[INFO] >>> Executing helm upgrade for platform-bootstrap...

=== BEGIN PLATFORM-BOOTSTRAP UPGRADE LOG ===
(full helm upgrade output shown here)
=== END PLATFORM-BOOTSTRAP UPGRADE LOG ===

[SUCCESS] ✓ Platform-bootstrap chart upgraded successfully

[STEP] STEP 3/3: Upgrading platform-base chart
(... continues with base upgrade ...)

[SUCCESS] All steps completed for 1.12.0
[INFO] Verifying upgrade...
[SUCCESS] Version verified: 1.12.0
[INFO] Checking pod status...
[SUCCESS] All pods are Running/Completed

(... process repeats for 1.13.0 ...)

[SUCCESS] ╔════════════════════════════════════════╗
[SUCCESS] ║  ALL UPGRADES COMPLETED SUCCESSFULLY!
[SUCCESS] ╚════════════════════════════════════════╝

[SUCCESS] Final version: 1.13.0
[INFO] Log file: /path/to/logs/upgrade-20250117-073000.log
```

### Example 2: Current Version >= 1.13.0 (Bootstrap prompt skipped)

```bash
$ ./upgrade.sh

╔════════════════════════════════════════════════════════════════╗
║  TIBCO Control Plane Master Upgrade Script
╚════════════════════════════════════════════════════════════════╝

Enter Kubernetes namespace containing your deployments: tibco-platform
Platform Base release name (default: platform-base): [Enter]
Helm repository name (default: tibco-platform): [Enter]

[SUCCESS] Basic configuration completed
[INFO] Logging to: /path/to/logs/upgrade-20250117-130000.log

[STEP] Discovering available upgrade versions...
[INFO] Found 5 version(s): 1.10.0 1.11.0 1.12.0 1.13.0 1.14.0
[SUCCESS] Latest version detected: 1.14.0

[STEP] Checking dependencies...
[SUCCESS] All dependencies are installed

[STEP] Verifying namespace: tibco-platform
[SUCCESS] Namespace verified

[STEP] Detecting current chart versions...
[INFO] Chart Status:
[INFO]   platform-base: version=1.13.0, status=deployed
[SUCCESS] Current version: 1.13.0

[INFO] Version 1.13.0 detected (1.13.0+): Bootstrap chart is merged into Base
[INFO] Skipping Bootstrap release name prompt

[STEP] Select Target Version for Upgrade

[INFO] Available upgrade versions:
  1. 1.13.0 (current)
  2. 1.14.0

[INFO] Default: 1.14.0 (latest)

Select target version [1-2] (press Enter for latest): [Enter]
[SUCCESS] Selected latest version: 1.14.0

[STEP] Calculating upgrade path from 1.13.0 to 1.14.0...
[INFO]   1.13.0 → 1.14.0
[SUCCESS] Upgrade path calculated: 1 step(s)

(... upgrade proceeds without asking for Bootstrap release ...)
```

## Prerequisites

- ✅ `kubectl` - installed and configured
- ✅ `helm` - version 3.17 or higher
- ✅ `jq` - JSON processor
- ✅ `yq` - YAML processor (v4+)
- ✅ Cluster access with appropriate permissions
- ✅ Both Bootstrap and Base charts deployed (for versions before 1.13.0)
- ✅ **Execute permissions on scripts** - All version-specific upgrade scripts (e.g., `scripts/1.13.0/upgrade.sh`) must have execute permissions set before running the master upgrade script:
  ```bash
  chmod +x scripts/*/upgrade.sh
  chmod +x scripts/upgrade.sh
  ```

## Features

✅ **Smart Version Discovery** - Automatically finds latest version, no hardcoding needed  
✅ **Numbered Menu Selection** - Easy target version selection (1, 2, 3...)  
✅ **Auto-Select Latest** - Press Enter to automatically select latest version  
✅ **Version Validation** - Only shows valid upgrade targets (>= current version)  
✅ **Fully Automated** - No manual steps after confirmation  
✅ **Dynamic Upgrade Path** - Builds sequential path from current to selected target  
✅ **Values Generation** - Automatically extracts from running Helm releases  
✅ **Version-Aware File Naming** - Uses correct file names for each version  
✅ **Helm Upgrades** - Automatically upgrades charts (handles pre/post 1.13.0)  
✅ **Sequential Execution** - One version at a time  
✅ **Post-Upgrade Validation** - Optional custom validation hooks after each upgrade  
✅ **Verbose Logging** - All output shown on screen and saved to log file  
✅ **Error Handling** - Stops on failure with clear instructions  
✅ **Version Detection** - Automatically detects current versions  
✅ **Post-1.13.0 Support** - Handles unified tibco-cp-base chart  
✅ **Future-Proof** - Add new versions without modifying the script  

## What Happens for Each Version

### Step 1: Generate Values (Automated)
```
- Extracts current values from Helm releases
- Generates upgrade-ready values files
- Shows all output from upgrade script
- Saves to log: step1_X.X.X.log
```

### Step 2: Upgrade Bootstrap (Automated - pre-1.13.0 only)
```
- Runs: helm upgrade platform-bootstrap
- Uses generated values file
- Shows all helm upgrade output
- Waits for pods to be ready
- Saves to log: step2_X.X.X.log
```

### Step 3: Upgrade Base (Automated)
```
For Pre-1.13.0:
- Runs: helm upgrade platform-base
- Uses: platform-base-VERSION.yaml
- Shows all helm upgrade output
- Waits for pods to be ready
- Saves to log: step3_X.X.X.log

For 1.13.0+:
- Runs: helm upgrade tibco-cp-base
- Uses: tibco-cp-base-merged-1.13.0.yaml (for 1.13.0)
       OR control-plane-VERSION.yaml (for 1.14.0+)
- Shows all helm upgrade output
- Waits for pods to be ready
- Saves to log: step2_X.X.X.log (only 2 steps for unified chart)
```

### Step 4: Verification (Automatic)
```
- Verifies version matches target
- Checks all pods are Running/Completed
- Waits 30s if pods not ready
```

## Optional: Post-Upgrade Validation

The script supports running a custom validation script after each successful upgrade step.

Enable this feature by setting `POST_UPGRADE_VALIDATION_SCRIPT`. As part of this enhancement, `upgrade.sh` also exports `TP_UPGRADE_PLATFORM_BASE_CHART_VERSION` so your custom validation script can run version-specific logic based on the currently deployed platform base chart version.

### Usage

```bash
export POST_UPGRADE_VALIDATION_SCRIPT="/path/to/your-validation.sh"
./upgrade.sh
```

### Behavior

- Script executes after each version upgrade completes
- Exit code `0` = validation passes, upgrade continues to next version
- Exit code non-zero = validation fails, upgrade terminates immediately
- If not set, only basic infrastructure checks are performed (chart version, pod readiness, helm status)

### Custom Validation Script Requirements

#### Prerequisites

- ✅ **Execute permissions** - The validation script must have execute permissions set:
  ```bash
  chmod +x /path/to/your-validation.sh
  ```
- ✅ **Bash compatibility** - Script will be executed using `bash`
- ✅ **Access to cluster** - Script should be able to run `kubectl` and `helm` commands
- ✅ **Proper exit codes** - Must return `0` on success, non-zero on failure

#### Inputs (Available Environment Variables)

Your validation script can access these environment variables:

- `NAMESPACE` - The Kubernetes namespace being upgraded
- `PLATFORM_BASE_RELEASE` - Name of the platform-base Helm release
- `PLATFORM_BOOTSTRAP_RELEASE` - Name of the platform-bootstrap Helm release (for pre-1.13.0)
- `TP_HELM_REPO_NAME` - Name of the Helm repository
- `CURRENT_VERSION` - The version that was just upgraded to

Additional exported variables are provided to support version-based validation:

- `TP_UPGRADE_PLATFORM_BASE_CHART_VERSION` - Deployed platform base chart package version (example: `1.14.0`)
- `TP_UPGRADE_PLATFORM_BASE_APP_VERSION` - Deployed app version for the platform base release
- `TP_UPGRADE_NAMESPACE` - The Kubernetes namespace being upgraded
- `TP_UPGRADE_PLATFORM_BASE_RELEASE` - Name of the platform base Helm release
- `TP_UPGRADE_TARGET_VERSION` - The upgrade step version that just completed

These `TP_UPGRADE_*` values are exported by `upgrade.sh` and are derived from the parent script context (for example, `TP_UPGRADE_NAMESPACE` is taken from `NAMESPACE`, and `TP_UPGRADE_PLATFORM_BASE_RELEASE` is taken from `PLATFORM_BASE_RELEASE`). Your custom validation script does not need to set them.

**Note:** These environment variables are automatically available from the parent script context.

#### Outputs (Expected Behavior)

- **Exit Code 0** - Validation passed, upgrade will continue to next version
- **Exit Code Non-Zero** - Validation failed, upgrade will terminate immediately
- **Standard Output** - All output (stdout/stderr) is captured and saved to validation log file
- **Log File** - Validation output is logged to `${TEMP_DIR}/validation_${version}.log`

#### Example Validation Script

```bash
#!/bin/bash
# my-company-validation.sh
# Custom post-upgrade validation script

set -euo pipefail

echo "Starting custom validation for version upgrade..."

# Version-based validation example
chart_ver="${TP_UPGRADE_PLATFORM_BASE_CHART_VERSION:-}"
case "${chart_ver}" in
  1.14.*)
    echo "Running validation for 1.14.x"
    ;;
  *)
    echo "Skipping version-specific validation for: ${chart_ver}"
    ;;
esac

# 1. Verify all pods are running
echo "Checking pod status in namespace: ${NAMESPACE}"
not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
if [[ ${not_ready} -gt 0 ]]; then
    echo "ERROR: ${not_ready} pod(s) are not ready"
    exit 1
fi
echo "✓ All pods are running"

# 2. Verify Helm release status
echo "Checking Helm release: ${PLATFORM_BASE_RELEASE}"
release_status=$(helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" -o json | jq -r '.info.status')
if [[ "${release_status}" != "deployed" ]]; then
    echo "ERROR: Release status is ${release_status}, expected 'deployed'"
    exit 1
fi
echo "✓ Helm release is deployed"

# 3. Run application-specific health checks
echo "Running application health checks..."
# Add your custom validation logic here
# Example: curl health endpoints, run integration tests, etc.

echo "✓ All validations passed"
exit 0
```

### Using the Validation Script

```bash
# Set execute permissions (REQUIRED)
chmod +x ${HOME}/my-company-validation.sh

# Export the script path
export POST_UPGRADE_VALIDATION_SCRIPT="${HOME}/my-company-validation.sh"

# Run the upgrade
./upgrade.sh
```

## Version 1.13.0+ Special Handling

### Chart Architecture Change at 1.13.0

**Before 1.13.0:**
- Two separate charts: `platform-bootstrap` and `platform-base`
- Both must be upgraded
- Separate values files: `platform-base-VERSION.yaml`, `platform-bootstrap-VERSION.yaml`

**1.13.0 and Above:**
- Single unified chart: `tibco-cp-base`
- Bootstrap functionality merged into base
- Only 2 steps: Generate values + Upgrade base
- No separate bootstrap upgrade

### Version-Specific File Naming

The script automatically uses the correct file names based on what each version's upgrade script expects:

- **Pre-1.13.0** (Separate Charts): 
  - `platform-base-VERSION.yaml`
  - `platform-bootstrap-VERSION.yaml`
  
- **1.13.0+** (Unified `tibco-cp-base` Chart):
  - **1.13.0**: `tibco-cp-base-merged-1.13.0.yaml` *(naming from 1.13.0 script)*
  - **1.14.0+**: `control-plane-VERSION.yaml` *(updated naming)*
  
> **Note**: Both 1.13.0 and 1.14.0+ use the same unified `tibco-cp-base` chart. The different file names are just naming conventions used by each version's individual upgrade script.

The master upgrade script handles these naming differences automatically.

## Supported Upgrade Paths

The script **automatically discovers** all version folders in `scripts/` and builds the upgrade path dynamically to your **selected target version**.

### Example Upgrade Paths:

You can now choose your target version:

```
# Upgrade to latest (1.13.0)
1.10.0 → 1.11.0 → 1.12.0 → 1.13.0
1.11.0 → 1.12.0 → 1.13.0
1.12.0 → 1.13.0

# Or upgrade to specific version (e.g., 1.12.0)
1.10.0 → 1.11.0 → 1.12.0
1.11.0 → 1.12.0
```

**Use Cases:**
- **Production**: Upgrade to well-tested intermediate version first
- **Testing**: Upgrade one version at a time for validation
- **Phased Rollout**: Upgrade to specific version, test, then upgrade again later

### 🚀 Adding New Versions (e.g., 1.14.0)

To add support for version 1.14.0:

1. **Create version folder**:
   ```bash
   mkdir scripts/1.14.0
   ```

2. **Add upgrade script**:
   ```bash
   # Create scripts/1.14.0/upgrade.sh
   # This should handle upgrade from 1.13.0 → 1.14.0
   ```

3. **Run master script** - That's it!
   ```bash
   ./upgrade.sh
   ```
   
   The script will automatically:
   - Detect `1.14.0` folder
   - Identify it as the new latest version
   - Create mapping: `1.13.0 → 1.14.0`
   - Include it in the upgrade path

**No script modifications needed!** The master upgrade script is truly write-once.

## Log Files

All logs are saved to `scripts/logs/`:

- **Main log**: `upgrade-YYYYMMDD-HHMMSS.log` (everything)
- **Step 1 logs**: `step1_X.X.X.log` (values generation)
- **Step 2 logs**: `step2_X.X.X.log` (bootstrap upgrade)
- **Step 3 logs**: `step3_X.X.X.log` (base upgrade)
- **Failure logs**: `failed-chart-X.X.X-timestamp.log` (if failures occur)

## If Upgrade Fails

The script will **STOP** and show:

```
╔════════════════════════════════════════════════════════════════╗
║  UPGRADE FAILED - chart-name to version X.X.X
╚════════════════════════════════════════════════════════════════╝

The upgrade failed. Check the log file:
  /path/to/stepN_X.X.X.log

Debug Steps:
  1. kubectl get pods -n namespace
  2. kubectl logs <pod-name> -n namespace
  3. helm status chart-name -n namespace
  4. helm history chart-name -n namespace

To Retry:
  1. Fix the issue
  2. Re-run: ./upgrade.sh
  3. Script will continue from current version

Log saved: /path/to/failed-chart-X.X.X-timestamp.log
```

### Recovery Steps

1. **Review the error** in the log file
2. **Debug the issue**:
   ```bash
   kubectl get pods -n tibco-platform
   kubectl logs <failing-pod> -n tibco-platform
   helm status platform-base -n tibco-platform
   ```
3. **Fix the problem** (add resources, fix config, etc.)
4. **Re-run the script**:
   ```bash
   ./upgrade.sh
   ```
5. **Script will detect** your current version and continue from there

## Monitoring During Upgrade

### Terminal 1 (Run Script)
```bash
./upgrade.sh
```

### Terminal 2 (Watch Pods)
```bash
watch -n 2 kubectl get pods -n tibco-platform
```

### Terminal 3 (Watch Helm)
```bash
watch -n 5 helm list -n tibco-platform
```

## Expected Duration

- **One version upgrade**: ~15-20 minutes
- **Two version upgrades**: ~30-40 minutes
- **Three version upgrades**: ~45-60 minutes

*Varies based on cluster resources and pod startup times*

### Partial Upgrade Strategy

With target version selection, you can:
1. **First run**: Upgrade from 1.10.0 → 1.11.0 (select 1.11.0 as target)
2. **Test and validate** the 1.11.0 deployment
3. **Second run**: Upgrade from 1.11.0 → 1.12.0 (select 1.12.0 as target)
4. **Test and validate** the 1.12.0 deployment
5. **Third run**: Upgrade from 1.12.0 → 1.13.0 (select 1.13.0 or press Enter for latest)

This approach provides:
- ✅ More control over the upgrade process
- ✅ Time to validate each version
- ✅ Easier troubleshooting if issues arise
- ✅ Lower risk for production environments

## Pre-Upgrade Checklist

Before running the script:

- [ ] **Set execute permissions on all upgrade scripts:**
  ```bash
  chmod +x scripts/upgrade.sh
  chmod +x scripts/*/upgrade.sh
  # If using custom validation script:
  chmod +x /path/to/your-validation.sh
  ```
- [ ] Take backup of current values:
  ```bash
  helm get values platform-bootstrap -n tibco-platform > backup-bootstrap.yaml
  helm get values platform-base -n tibco-platform > backup-base.yaml
  ```
- [ ] Verify kubectl is connected to correct cluster
- [ ] Verify helm repository is configured
- [ ] Review release notes for target versions
- [ ] Ensure sufficient cluster resources
- [ ] Have rollback plan ready
- [ ] Allocate sufficient time (plan for 1 hour)

## Post-Upgrade Verification

After successful upgrade:

```bash
# Check versions
helm list -n tibco-platform

# Check pod status
kubectl get pods -n tibco-platform

# Check application
# - Access TIBCO Control Plane UI
# - Test critical workflows
# - Verify integrations
```

## Troubleshooting

### Issue: "Namespace not found"
```bash
kubectl get namespaces
# Use the correct namespace name
```

### Issue: "Helm repository not found"
```bash
helm repo list
# Add repository if missing:
helm repo add tibco-platform <URL>
```

### Issue: "Chart not in deployed state"
```bash
helm status platform-base -n tibco-platform
# May need to rollback or fix current deployment
```

### Issue: "Pods not ready"
```bash
kubectl get pods -n tibco-platform
kubectl describe pod <pod-name> -n tibco-platform
kubectl logs <pod-name> -n tibco-platform
# Check resources, pull policies, configurations
```

## Rollback

If you need to rollback:

```bash
# View history
helm history platform-base -n tibco-platform

# Rollback to previous version
helm rollback platform-base -n tibco-platform

# Or to specific revision
helm rollback platform-base <revision> -n tibco-platform
```

## Support

For issues:
1. Check log files in `scripts/logs/`
2. Review error messages
3. Follow debug steps in error output
4. Contact TIBCO Support with log files

---

**Ready to upgrade?**

```bash
./upgrade.sh
```

Good luck! 🚀
