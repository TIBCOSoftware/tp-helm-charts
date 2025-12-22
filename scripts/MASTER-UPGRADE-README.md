# TIBCO Control Plane - Master Upgrade Script

> **Note**: This master upgrade script has been tested and validated for sequential upgrades across multiple versions (1.10.0 → 1.11.0 → 1.12.0 → 1.13.0). The script handles both pre-1.13.0 (separate bootstrap/base charts) and post-1.13.0 (unified tibco-cp-base chart) deployments.

## Quick Start

```bash
cd /path/to/tibco-platform/scripts
chmod +x upgrade.sh
./upgrade.sh
```

## What It Does

This script automatically upgrades your TIBCO Control Plane from the current version to the latest available version through sequential upgrades.

### 🎯 Smart Version Detection & Selection

The script **automatically discovers** all available versions by scanning the `scripts/` directory:
- Finds all version folders (e.g., `1.10.0/`, `1.11.0/`, `1.12.0/`, `1.13.0/`)
- Identifies the **highest version** as the latest
- **NEW**: Lets you **choose your target version** - upgrade to any version or latest
- Builds the upgrade path dynamically to your selected target
- **No hardcoding needed!** When you add version `1.14.0/` with `upgrade.sh`, it's automatically detected

### Process for Each Version

1. **Generate values.yaml** from current Helm deployment
2. **Upgrade platform-bootstrap** chart (if applicable)
3. **Upgrade platform-base** chart  
4. **Verify** upgrade success and pod status

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
- ✅ **NEW: Target Version Selection** - Choose which version to upgrade to:
  - Select specific version (e.g., upgrade to 1.12.0 only)
  - Press Enter to upgrade to latest
  - Shows clear labels: (current), (latest)
  - Prevents downgrade attempts
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

[STEP] Target Version Selection
[INFO] Available upgrade versions:

1) 1.10.0
2) 1.11.0 (current)
3) 1.12.0
4) 1.13.0 (latest)

Select target version to upgrade to (1-4, or press Enter for latest): [Enter]
[INFO] Using latest version: 1.13.0
[SUCCESS] Target version set to: 1.13.0

[STEP] Calculating upgrade path from 1.11.0 to 1.13.0...
[INFO]   1.11.0 → 1.12.0
[INFO]   1.12.0 → 1.13.0
[SUCCESS] Upgrade path calculated: 2 step(s)

╔════════════════════════════════════════════════════════════════╗
║  TIBCO PLATFORM CHARTS DETECTED
╚════════════════════════════════════════════════════════════════╝

📊 Current Status:
  • Platform Bootstrap: platform-bootstrap = 1.11.0
  • Platform Base: platform-base = 1.11.0

🎯 Upgrade Plan:
  • Sequential upgrade from 1.11.0 to 1.13.0
  • Number of upgrade steps: 2
  • Upgrade path: 1.11.0 → 1.12.0 → 1.13.0

🔄 What will happen for EACH version:
  1. Generate values.yaml from current Helm deployment
  2. Upgrade platform-bootstrap chart (if applicable)
  3. Upgrade platform-base chart
  4. Verify upgrade success and pod status

📝 All upgrade logs will be shown on screen and saved to:
  /path/to/logs/upgrade-20250117-073000.log

⚠️  This is a FULLY AUTOMATED process
⚠️  Ensure you have reviewed the upgrade requirements
⚠️  Have a rollback plan ready if needed

Do you want to proceed with the sequential upgrade? (yes/no): yes

╔════════════════════════════════════════════════════════════════╗
║  UPGRADING TO VERSION 1.12.0
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

[STEP] Target Version Selection
[INFO] Available upgrade versions:

1) 1.10.0
2) 1.11.0
3) 1.12.0
4) 1.13.0 (current)
5) 1.14.0 (latest)

Select target version to upgrade to (1-5, or press Enter for latest): [Enter]
[INFO] Using latest version: 1.14.0
[SUCCESS] Target version set to: 1.14.0

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

## Features

✅ **Smart Version Discovery** - Automatically finds latest version, no hardcoding needed  
✅ **Target Version Selection** - Choose to upgrade to specific version or latest  
✅ **Fully Automated** - No manual steps after confirmation  
✅ **Dynamic Upgrade Path** - Builds sequential path from current to selected target  
✅ **Values Generation** - Automatically extracts from running Helm releases  
✅ **Helm Upgrades** - Automatically upgrades both charts  
✅ **Sequential Execution** - One version at a time  
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
- Runs: helm upgrade platform-base
- Uses generated values file
- Shows all helm upgrade output
- Waits for pods to be ready
- Saves to log: step3_X.X.X.log
```

### Step 4: Verification (Automatic)
```
- Verifies version matches target
- Checks all pods are Running/Completed
- Waits 30s if pods not ready
```

## Version 1.13.0 Special Handling

For version 1.13.0 (unified chart):
- Only 2 steps: Generate values + Upgrade base
- No separate bootstrap upgrade
- Uses unified `tibco-cp-base` chart

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
