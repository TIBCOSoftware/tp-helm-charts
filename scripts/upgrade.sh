#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# TIBCO Control Plane Master Upgrade Script
# Automatically detects current chart versions and performs sequential upgrades
# Fully automated with values generation and helm upgrades
#
# Optional: Set POST_UPGRADE_VALIDATION_SCRIPT environment variable to run custom
# validation after each successful upgrade. The script should exit 0 on success
# or non-zero on failure to halt the upgrade process.
# Example: export POST_UPGRADE_VALIDATION_SCRIPT="/path/to/validate.sh"
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global variables
NAMESPACE=""
PLATFORM_BOOTSTRAP_RELEASE="platform-bootstrap"
PLATFORM_BASE_RELEASE="platform-base"
TP_HELM_REPO_NAME="tp-helm-charts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEST_VERSION=""
TARGET_VERSION=""
LOG_FILE=""
TEMP_DIR=""
CURRENT_VERSION=""
AVAILABLE_VERSIONS=()

# Version mapping will be built dynamically
declare -A VERSION_MAP

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} ${1}"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} ${1}"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} ${1}"; }
print_error() { echo -e "${RED}[ERROR]${NC} ${1}" >&2; }
print_step() { echo -e "${CYAN}[STEP]${NC} ${1}"; }

print_separator() {
    echo ""
    echo "================================================================================"
    echo ""
}

# Discover available versions and build version map
discover_versions() {
    print_step "Discovering available upgrade versions..."
    
    # Find all version directories with upgrade.sh
    local version_dirs=()
    for dir in "${SCRIPT_DIR}"/*/; do
        if [[ -d "${dir}" ]]; then
            local dirname=$(basename "${dir}")
            # Check if directory name matches version pattern X.Y.Z
            if [[ "${dirname}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                # Check if upgrade.sh exists
                if [[ -f "${dir}/upgrade.sh" ]]; then
                    version_dirs+=("${dirname}")
                fi
            fi
        fi
    done
    
    if [[ ${#version_dirs[@]} -eq 0 ]]; then
        print_error "No version directories with upgrade.sh found in ${SCRIPT_DIR}"
        exit 1
    fi
    
    # Sort versions using semantic versioning
    IFS=$'\n' AVAILABLE_VERSIONS=($(sort -t. -k1,1n -k2,2n -k3,3n <<< "${version_dirs[*]}"))
    unset IFS
    
    # Latest version is the highest one
    LATEST_VERSION="${AVAILABLE_VERSIONS[-1]}"
    
    print_info "Found ${#AVAILABLE_VERSIONS[@]} version(s): ${AVAILABLE_VERSIONS[*]}"
    print_success "Latest version available: ${LATEST_VERSION}"
    
    # Build VERSION_MAP dynamically (each version points to the next)
    for i in "${!AVAILABLE_VERSIONS[@]}"; do
        if [[ $i -lt $((${#AVAILABLE_VERSIONS[@]} - 1)) ]]; then
            local current_ver="${AVAILABLE_VERSIONS[$i]}"
            local next_ver="${AVAILABLE_VERSIONS[$((i + 1))]}"
            VERSION_MAP["${current_ver}"]="${next_ver}"
            print_info "  Mapping: ${current_ver} → ${next_ver}"
        fi
    done
    
    echo ""
}

# Compare semantic versions (returns 0 if v1 >= v2, 1 otherwise)
version_gte() {
    local v1="$1"
    local v2="$2"
    
    # Split versions into arrays
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"
    
    # Compare each part
    for i in 0 1 2; do
        local part1=${v1_parts[$i]:-0}
        local part2=${v2_parts[$i]:-0}
        
        if [[ $part1 -gt $part2 ]]; then
            return 0
        elif [[ $part1 -lt $part2 ]]; then
            return 1
        fi
    done
    
    # Versions are equal
    return 0
}

# Prompt for target version
prompt_target_version() {
    local current_version="$1"
    
    print_separator
    print_step "Select Target Version for Upgrade"
    echo ""
    print_info "Available upgrade versions:"
    
    # Show only versions >= current version
    local valid_targets=()
    for version in "${AVAILABLE_VERSIONS[@]}"; do
        if version_gte "$version" "$current_version"; then
            valid_targets+=("$version")
        fi
    done
    
    if [[ ${#valid_targets[@]} -eq 1 ]] && [[ "${valid_targets[0]}" == "$current_version" ]]; then
        print_success "Already at the latest available version: ${current_version}"
        return 1
    fi
    
    # Display versions with numbers
    local index=1
    for version in "${valid_targets[@]}"; do
        if [[ "$version" == "$current_version" ]]; then
            print_info "  ${index}. ${version} (current)"
        else
            print_info "  ${index}. ${version}"
        fi
        ((index++))
    done
    
    echo ""
    print_info "Default: ${LATEST_VERSION} (latest)"
    echo ""
    
    # Prompt for target version selection
    while true; do
        read -p "Select target version [1-${#valid_targets[@]}] (press Enter for latest): " selection
        
        # If empty, select latest version
        if [[ -z "${selection}" ]]; then
            TARGET_VERSION="${LATEST_VERSION}"
            print_success "Selected latest version: ${TARGET_VERSION}"
            break
        fi
        
        # Validate numeric input
        if ! [[ "${selection}" =~ ^[0-9]+$ ]]; then
            print_error "Invalid input. Please enter a number between 1 and ${#valid_targets[@]}"
            continue
        fi
        
        # Validate range
        if [[ ${selection} -lt 1 ]] || [[ ${selection} -gt ${#valid_targets[@]} ]]; then
            print_error "Invalid selection. Please enter a number between 1 and ${#valid_targets[@]}"
            continue
        fi
        
        # Get selected version (array is 0-indexed)
        TARGET_VERSION="${valid_targets[$((selection - 1))]}"
        
        # Check if target == current
        if [[ "${TARGET_VERSION}" == "$current_version" ]]; then
            print_info "Target version is same as current version. No upgrade needed."
            return 1
        fi
        
        print_success "Selected version: ${TARGET_VERSION}"
        break
    done
    
    return 0
}

# (Usage function removed - script is now fully interactive)

# Interactive prompts for user input (basic info only)
interactive_prompts_basic() {
    print_separator
    print_info "╔════════════════════════════════════════════════════════════════╗"
    print_info "║  TIBCO Control Plane Master Upgrade Script"
    print_info "╚════════════════════════════════════════════════════════════════╝"
    print_separator
    
    # Get namespace
    while [[ -z "${NAMESPACE}" ]]; do
        read -p "Enter Kubernetes namespace containing your deployments: " NAMESPACE
        if [[ -z "${NAMESPACE}" ]]; then
            print_error "Namespace cannot be empty"
        fi
    done
    
    # Get base release name (always needed)
    read -p "Platform Base release name (default: platform-base): " input_base
    if [[ -n "${input_base}" ]]; then
        PLATFORM_BASE_RELEASE="${input_base}"
    fi
    
    # Get helm repo name (optional)
    read -p "Helm repository name (default: tp-helm-charts): " input_repo
    if [[ -n "${input_repo}" ]]; then
        TP_HELM_REPO_NAME="${input_repo}"
    fi
    
    print_success "Basic configuration completed"
}

# Prompt for bootstrap release name (only if needed)
prompt_bootstrap_if_needed() {
    local current_version="$1"
    
    # Check if current version is 1.13.0 or higher
    if [[ "${current_version}" =~ ^1\.1[3-9]\. ]] || [[ "${current_version}" =~ ^1\.[2-9][0-9]\. ]] || [[ "${current_version}" =~ ^[2-9]\. ]]; then
        print_info "Version ${current_version} detected (1.13.0+): Bootstrap chart is merged into Base"
        print_info "Skipping Bootstrap release name prompt"
        return
    fi
    
    # For versions before 1.13.0, ask for bootstrap release name
    echo ""
    print_info "Version ${current_version} detected (pre-1.13.0): Bootstrap chart is separate"
    read -p "Platform Bootstrap release name (default: platform-bootstrap): " input_bootstrap
    if [[ -n "${input_bootstrap}" ]]; then
        PLATFORM_BOOTSTRAP_RELEASE="${input_bootstrap}"
    fi
    print_success "Bootstrap configuration completed"
}

# Setup logging
setup_logging() {
    local log_dir="${SCRIPT_DIR}/logs"
    mkdir -p "${log_dir}"
    LOG_FILE="${log_dir}/upgrade-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee >(sed -r 's/\x1B\[[0-9;]*[mK]//g' >> "${LOG_FILE}")) 2>&1
    print_info "Logging to: ${LOG_FILE}"
}

# Setup temp directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "${TEMP_DIR}" 2>/dev/null || true' EXIT
    print_info "Temp directory: ${TEMP_DIR}"
}

# Check dependencies
check_dependencies() {
    print_step "Checking dependencies..."
    
    local missing_deps=()
    
    for cmd in kubectl helm jq yq; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    print_success "All dependencies are installed"
}

# Verify namespace
verify_namespace() {
    print_step "Verifying namespace: ${NAMESPACE}"
    
    if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Namespace '${NAMESPACE}' not found"
        exit 1
    fi
    
    print_success "Namespace verified"
}

# Get chart version
get_chart_version() {
    local release_name="$1"
    local namespace="$2"
    
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        echo "not-found"
        return
    fi
    
    helm list -n "${namespace}" -f "^${release_name}$" -o json 2>/dev/null | \
        jq -r '.[0].app_version // "unknown"'
}

# Get deployed chart (package) version
get_deployed_chart_version() {
    local release_name="$1"
    local namespace="$2"
    
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        echo "not-found"
        return
    fi
    
    local chart_version chart_field extracted

    chart_version=$(helm status "${release_name}" -n "${namespace}" -o json 2>/dev/null | jq -r '.chart.metadata.version // empty' 2>/dev/null || true)
    if [[ -n "${chart_version}" ]]; then
        echo "${chart_version}"
        return
    fi

    chart_field=$(helm list -n "${namespace}" -f "^${release_name}$" -o json 2>/dev/null | jq -r '.[0].chart // empty' 2>/dev/null || true)
    extracted=$(echo "${chart_field}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z.]+)*' | tail -1 || true)

    echo "${extracted:-${chart_field:-unknown}}"
}

# Get chart status
get_chart_status() {
    local release_name="$1"
    local namespace="$2"
    
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        echo "not-found"
        return
    fi
    
    helm status "${release_name}" -n "${namespace}" -o json 2>/dev/null | \
        jq -r '.info.status // "unknown"'
}

# Detect current versions
detect_versions() {
    print_separator
    print_step "Detecting current chart versions..."
    echo ""
    
    local bootstrap_version=$(get_chart_version "${PLATFORM_BOOTSTRAP_RELEASE}" "${NAMESPACE}")
    local bootstrap_status=$(get_chart_status "${PLATFORM_BOOTSTRAP_RELEASE}" "${NAMESPACE}")
    local base_version=$(get_chart_version "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")
    local base_status=$(get_chart_status "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")
    
    print_info "Chart Status:"
    print_info "  ${PLATFORM_BOOTSTRAP_RELEASE}: version=${bootstrap_version}, status=${bootstrap_status}"
    print_info "  ${PLATFORM_BASE_RELEASE}: version=${base_version}, status=${base_status}"
    echo ""
    
    # Validate
    if [[ "${base_version}" == "not-found" ]]; then
        print_error "Base chart not found in namespace"
        exit 1
    fi
    
    if [[ "${base_status}" != "deployed" ]]; then
        print_error "Base chart is not in 'deployed' state"
        exit 1
    fi
    
    # Check if post-1.13.0
    if [[ "${base_version}" =~ ^1\.1[3-9]\. ]] || [[ "${base_version}" =~ ^1\.[2-9][0-9]\. ]]; then
        print_info "Detected version 1.13.0+ (unified chart)"
        CURRENT_VERSION="${base_version}"
    else
        if [[ "${bootstrap_version}" == "not-found" || "${bootstrap_status}" != "deployed" ]]; then
            print_error "Bootstrap chart must be deployed for versions before 1.13.0"
            exit 1
        fi
        CURRENT_VERSION="${base_version}"
    fi
    
    print_success "Current version: ${CURRENT_VERSION}"
}

# Calculate upgrade path
calculate_upgrade_path() {
    print_separator
    print_step "Calculating upgrade path from ${CURRENT_VERSION} to ${TARGET_VERSION}..."
    echo ""
    
    UPGRADE_PATH=()
    local current="${CURRENT_VERSION}"
    
    if [[ "${current}" == "${TARGET_VERSION}" ]]; then
        print_info "Already at target version"
        return 0
    fi
    
    while [[ "${current}" != "${TARGET_VERSION}" ]]; do
        if [[ -z "${VERSION_MAP[${current}]:-}" ]]; then
            print_error "No upgrade path from version ${current}"
            exit 1
        fi
        
        local next_version="${VERSION_MAP[${current}]}"
        UPGRADE_PATH+=("${next_version}")
        print_info "  ${current} → ${next_version}"
        current="${next_version}"
        
        # Stop if we reached target
        if [[ "${current}" == "${TARGET_VERSION}" ]]; then
            break
        fi
    done
    
    echo ""
    print_success "Upgrade path calculated: ${#UPGRADE_PATH[@]} step(s)"
}

# Run post-upgrade validation script if configured
run_post_upgrade_validation() {
    local version="$1"
    
    print_separator
    print_step "Running post-upgrade validation for version ${version}"
    
    # Check if validation script is configured
    if [[ -z "${POST_UPGRADE_VALIDATION_SCRIPT:-}" ]]; then
        print_info "No custom validation script configured (POST_UPGRADE_VALIDATION_SCRIPT not set)"
        print_info "Performing basic infrastructure validation only (no functional tests)"
        echo ""
        
        # Basic Check 1: Verify chart version
        print_info "✓ Checking chart version..."
        local current_version=$(get_chart_version "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")
        if [[ "${current_version}" == "${version}" ]]; then
            print_success "  Chart version verified: ${current_version}"
        else
            print_warning "  Version mismatch: expected ${version}, got ${current_version}"
        fi
        
        # Basic Check 2: Verify pod readiness
        print_info "✓ Checking pod readiness..."
        local not_ready=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l | tr -d '[:space:]' || echo "0")
        if [[ ${not_ready} -eq 0 ]]; then
            print_success "  All pods are in Running/Completed state"
        else
            print_warning "  ${not_ready} pod(s) not in Running/Completed state"
            kubectl get pods -n "${NAMESPACE}" 2>/dev/null | grep -v "Running\|Completed" | head -5 || true
        fi
        
        # Basic Check 3: Check helm release status
        print_info "✓ Checking Helm release status..."
        local release_status=$(get_chart_status "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")
        if [[ "${release_status}" == "deployed" ]]; then
            print_success "  Helm release status: ${release_status}"
        else
            print_warning "  Helm release status: ${release_status}"
        fi
        
        echo ""
        print_success "✓ Basic infrastructure validation completed"
        print_info "ℹ️  No functional tests performed - configure POST_UPGRADE_VALIDATION_SCRIPT for custom validation"
        return 0
    fi
    
    # Custom validation script configured
    print_info "Custom validation script: ${POST_UPGRADE_VALIDATION_SCRIPT}"
    echo ""
    
    # Check if script exists
    if [[ ! -f "${POST_UPGRADE_VALIDATION_SCRIPT}" ]]; then
        print_error "Validation script not found: ${POST_UPGRADE_VALIDATION_SCRIPT}"
        print_error "Terminating upgrade process"
        exit 1
    fi
    
    # Run validation script
    local validation_log="${TEMP_DIR}/validation_${version}.log"
    print_info "Executing validation script..."

    export TP_UPGRADE_NAMESPACE="${NAMESPACE}"
    export TP_UPGRADE_PLATFORM_BASE_RELEASE="${PLATFORM_BASE_RELEASE}"
    export TP_UPGRADE_TARGET_VERSION="${version}"
    export TP_UPGRADE_PLATFORM_BASE_APP_VERSION="$(get_chart_version "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")"
    export TP_UPGRADE_PLATFORM_BASE_CHART_VERSION="$(get_deployed_chart_version "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")"
    
    if bash "${POST_UPGRADE_VALIDATION_SCRIPT}" 2>&1 | tee "${validation_log}"; then
        local exit_code=${PIPESTATUS[0]}
        if [[ ${exit_code} -eq 0 ]]; then
            print_success "✓ Post-upgrade validation passed for version ${version}"
            print_info "Proceeding to next upgrade step"
            return 0
        else
            print_error "✗ Post-upgrade validation failed for version ${version} (exit code: ${exit_code})"
            print_error "Validation log: ${validation_log}"
            print_error "Terminating upgrade process"
            exit 1
        fi
    else
        print_error "✗ Post-upgrade validation failed for version ${version}"
        print_error "Validation log: ${validation_log}"
        print_error "Terminating upgrade process"
        exit 1
    fi
}

# Handle upgrade failure
handle_upgrade_failure() {
    local chart_name="$1"
    local version="$2"
    local log_file="$3"
    
    print_separator
    print_error "╔════════════════════════════════════════════════════════════════╗"
    print_error "║  UPGRADE FAILED - ${chart_name} to ${version}"
    print_error "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_error "The upgrade failed. Check the log file:"
    print_error "  ${log_file}"
    echo ""
    print_error "🔍 Debug Steps:"
    print_error "  1. kubectl get pods -n ${NAMESPACE}"
    print_error "  2. kubectl logs <pod-name> -n ${NAMESPACE}"
    print_error "  3. helm status ${chart_name} -n ${NAMESPACE}"
    print_error "  4. helm history ${chart_name} -n ${NAMESPACE}"
    echo ""
    print_error "🔧 To Retry:"
    print_error "  1. Fix the issue"
    print_error "  2. Re-run: $0 --namespace ${NAMESPACE}"
    print_error "  3. Script will continue from current version"
    echo ""
    
    # Save permanent log
    local perm_log="${SCRIPT_DIR}/logs/failed-${chart_name}-${version}-$(date +%Y%m%d-%H%M%S).log"
    cp "${log_file}" "${perm_log}"
    print_error "📁 Log saved: ${perm_log}"
    
    exit 1
}

# Execute upgrade for a version
execute_upgrade() {
    local target_version="$1"
    local upgrade_script="${SCRIPT_DIR}/${target_version}/upgrade.sh"
    
    print_separator
    print_info "╔════════════════════════════════════════════════════════════════╗"
    print_info "║  UPGRADING TO TIBCO CONTROL PLANE VERSION ${target_version}"
    print_info "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check if CHART_VERSION is set and matches the target version pattern
    local saved_chart_version="${CHART_VERSION:-}"
    local version_matches=false
    
    if [[ -n "${saved_chart_version}" ]]; then
        # Extract major.minor from both CHART_VERSION and target_version
        local chart_major_minor=$(echo "${saved_chart_version}" | grep -oE '^[0-9]+\.[0-9]+' || echo "")
        local target_major_minor=$(echo "${target_version}" | grep -oE '^[0-9]+\.[0-9]+' || echo "")
        
        if [[ -n "${chart_major_minor}" ]] && [[ "${chart_major_minor}" == "${target_major_minor}" ]]; then
            # Chart version pattern matches target version (e.g., 1.14.* matches 1.14.0)
            print_info "Using global chart version (matches ${target_version}): ${CHART_VERSION}"
            version_matches=true
        else
            # Chart version pattern does NOT match - temporarily unset for this upgrade step only
            print_info "Global CHART_VERSION (${CHART_VERSION}) does not match target ${target_version} - using default from upgrade script"
            unset CHART_VERSION
        fi
    else
        print_info "Using default chart version from upgrade script"
    fi
    
    if [[ ! -f "${upgrade_script}" ]]; then
        print_error "Upgrade script not found: ${upgrade_script}"
        exit 1
    fi
    
    chmod +x "${upgrade_script}"
    
    # STEP 1: Generate values files
    print_step "STEP 1/3: Generating values files from current deployment"
    print_info "  ├─ Selecting: Generate values.yaml files (Option 1)"
    print_info "  ├─ Source: Extract from running Helm deployments (Option 2)"
    print_info "  ├─ Namespace: ${NAMESPACE}"
    print_info "  ├─ Bootstrap release: ${PLATFORM_BOOTSTRAP_RELEASE}"
    print_info "  ├─ Base release: ${PLATFORM_BASE_RELEASE}"
    
    # Clean up any existing generated files from previous runs
    print_info "  └─ Cleaning up any existing generated files..."
    rm -f "${SCRIPT_DIR}/platform-base-${target_version}.yaml" \
          "${SCRIPT_DIR}/platform-bootstrap-${target_version}.yaml" \
          "${SCRIPT_DIR}/platform-base-${target_version}.yaml.clean" \
          "${SCRIPT_DIR}/platform-bootstrap-${target_version}.yaml.clean" \
          "${SCRIPT_DIR}/tibco-cp-base-merged-${target_version}.yaml" \
          "${SCRIPT_DIR}/control-plane-${target_version}.yaml" 2>/dev/null || true
    echo ""
    
    print_info ">>> Executing upgrade script for values generation..."
    print_separator
    
    local step1_input="${TEMP_DIR}/step1_${target_version}.txt"
    
    # Determine output file name based on version
    local values_file=""
    
    # Input differs between 1.13.0+ and earlier versions
    if [[ "${target_version}" =~ ^1\.1[3-9]\. ]] || [[ "${target_version}" =~ ^1\.[2-9][0-9]\. ]] || [[ "${target_version}" =~ ^[2-9]\. ]]; then
        # For 1.13.0+, determine the default file name
        if [[ "${target_version}" == "1.13.0" ]]; then
            values_file="tibco-cp-base-merged-${target_version}.yaml"
        else
            # 1.14.0+ uses control-plane-VERSION.yaml
            values_file="control-plane-${target_version}.yaml"
        fi
        
        print_info "  └─ Output file: ${values_file} (default)"
        # 1.13.0+ asks for: namespace, bootstrap release, base release, merged output file (press Enter for default)
        cat > "${step1_input}" << EOF
1
2
${NAMESPACE}



EOF
    else
        # Pre-1.13.0 asks for: namespace, bootstrap release, base release, base output, bootstrap output
        values_file="platform-base-${target_version}.yaml"
        print_info "  └─ Output files: platform-base-${target_version}.yaml, platform-bootstrap-${target_version}.yaml"
        cat > "${step1_input}" << EOF
1
2
${NAMESPACE}


platform-base-${target_version}.yaml
platform-bootstrap-${target_version}.yaml
EOF
    fi
    
    echo "=== BEGIN VALUES GENERATION LOG ===" | tee -a "${TEMP_DIR}/step1_${target_version}.log"
    # Run the upgrade script in the SCRIPT_DIR so generated files are in the right place
    if ! (cd "${SCRIPT_DIR}" && bash "${upgrade_script}" < "${step1_input}") 2>&1 | tee -a "${TEMP_DIR}/step1_${target_version}.log"; then
        echo "=== END VALUES GENERATION LOG (FAILED) ===" | tee -a "${TEMP_DIR}/step1_${target_version}.log"
        print_error "❌ Failed to generate values files"
        print_error "Log location: ${TEMP_DIR}/step1_${target_version}.log"
        exit 1
    fi
    echo "=== END VALUES GENERATION LOG ===" | tee -a "${TEMP_DIR}/step1_${target_version}.log"
    
    print_success "✓ Values files generated"
    echo ""
    
    # Check if version 1.13.0 or higher (unified chart)
    if [[ "${target_version}" =~ ^1\.1[3-9]\. ]] || [[ "${target_version}" =~ ^1\.[2-9][0-9]\. ]] || [[ "${target_version}" =~ ^[2-9]\. ]]; then
        print_warning "Version ${target_version} uses unified tibco-cp-base chart (1.13.0+)"
        echo ""
        
        # STEP 2: Upgrade Base only (unified chart for 1.13.0+)
        print_step "STEP 2/2: Upgrading tibco-cp-base chart (unified chart)"
        print_info "  ├─ Selecting: Perform Helm upgrade (Option 2)"
        print_info "  ├─ Values file: ${values_file}"
        print_info "  ├─ Namespace: ${NAMESPACE}"
        print_info "  ├─ Release: ${PLATFORM_BASE_RELEASE}"
        print_info "  └─ Helm repo: ${TP_HELM_REPO_NAME}"
        echo ""
        print_info ">>> Executing helm upgrade for platform-base..."
        print_separator
        
        local step2_input="${TEMP_DIR}/step2_${target_version}.txt"
        # Note: 1.13.0+ doesn't ask for chart selection, values file + upgrade confirmation + cleanup prompt
        cat > "${step2_input}" << EOF
2
${values_file}
${NAMESPACE}
${PLATFORM_BASE_RELEASE}
${TP_HELM_REPO_NAME}
yes
no
EOF
        
        echo "=== BEGIN TIBCO-CP-BASE UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
        if ! (cd "${SCRIPT_DIR}" && bash "${upgrade_script}" < "${step2_input}") 2>&1 | tee -a "${TEMP_DIR}/step2_${target_version}.log"; then
            echo "=== END TIBCO-CP-BASE UPGRADE LOG (FAILED) ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
            handle_upgrade_failure "tibco-cp-base" "${target_version}" "${TEMP_DIR}/step2_${target_version}.log"
        fi
        echo "=== END TIBCO-CP-BASE UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
        
        print_success "✓ Tibco-cp-base chart upgraded successfully"
    else
        # Pre-1.13.0: Upgrade both
        
        # STEP 2: Upgrade Bootstrap
        print_step "STEP 2/3: Upgrading platform-bootstrap chart"
        print_info "  ├─ Selecting: Perform Helm upgrade (Option 2)"
        print_info "  ├─ Chart selection: platform-bootstrap (Option 1)"
        print_info "  ├─ Values file: platform-bootstrap-${target_version}.yaml"
        print_info "  ├─ Namespace: ${NAMESPACE}"
        print_info "  ├─ Release: ${PLATFORM_BOOTSTRAP_RELEASE}"
        print_info "  └─ Helm repo: ${TP_HELM_REPO_NAME}"
        echo ""
        print_info ">>> Executing helm upgrade for platform-bootstrap..."
        print_separator
        
        local step2_input="${TEMP_DIR}/step2_${target_version}.txt"
        cat > "${step2_input}" << EOF
2
1
platform-bootstrap-${target_version}.yaml
${NAMESPACE}

${TP_HELM_REPO_NAME}
yes
EOF
        
        echo "=== BEGIN PLATFORM-BOOTSTRAP UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
        if ! (cd "${SCRIPT_DIR}" && bash "${upgrade_script}" < "${step2_input}") 2>&1 | tee -a "${TEMP_DIR}/step2_${target_version}.log"; then
            echo "=== END PLATFORM-BOOTSTRAP UPGRADE LOG (FAILED) ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
            handle_upgrade_failure "platform-bootstrap" "${target_version}" "${TEMP_DIR}/step2_${target_version}.log"
        fi
        echo "=== END PLATFORM-BOOTSTRAP UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
        
        print_success "✓ Platform-bootstrap chart upgraded successfully"
        echo ""
        
        # STEP 3: Upgrade Base
        print_step "STEP 3/3: Upgrading platform-base chart"
        print_info "  ├─ Selecting: Perform Helm upgrade (Option 2)"
        print_info "  ├─ Chart selection: platform-base (Option 2)"
        print_info "  ├─ Values file: platform-base-${target_version}.yaml"
        print_info "  ├─ Namespace: ${NAMESPACE}"
        print_info "  ├─ Release: ${PLATFORM_BASE_RELEASE}"
        print_info "  └─ Helm repo: ${TP_HELM_REPO_NAME}"
        echo ""
        print_info ">>> Executing helm upgrade for platform-base..."
        print_separator
        
        local step3_input="${TEMP_DIR}/step3_${target_version}.txt"
        cat > "${step3_input}" << EOF
2
2
platform-base-${target_version}.yaml
${NAMESPACE}

${TP_HELM_REPO_NAME}
yes
EOF
        
        echo "=== BEGIN PLATFORM-BASE UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step3_${target_version}.log"
        if ! (cd "${SCRIPT_DIR}" && bash "${upgrade_script}" < "${step3_input}") 2>&1 | tee -a "${TEMP_DIR}/step3_${target_version}.log"; then
            echo "=== END PLATFORM-BASE UPGRADE LOG (FAILED) ===" | tee -a "${TEMP_DIR}/step3_${target_version}.log"
            handle_upgrade_failure "platform-base" "${target_version}" "${TEMP_DIR}/step3_${target_version}.log"
        fi
        echo "=== END PLATFORM-BASE UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step3_${target_version}.log"
        
        print_success "✓ Platform-base chart upgraded successfully"
    fi
    
    echo ""
    print_success "All steps completed for ${target_version}"
    
    # Verify
    print_info "Verifying upgrade..."
    local new_version=$(get_chart_version "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")
    
    if [[ "${new_version}" == "${target_version}" ]]; then
        print_success "Version verified: ${new_version}"
    else
        print_warning "Version mismatch: expected ${target_version}, got ${new_version}"
    fi
    
    # Check pods
    print_info "Checking pod status..."
    if kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | grep -q .; then
        print_warning "Some pods are not Ready. Waiting 30s..."
        sleep 30
    else
        print_success "All pods are Running/Completed"
    fi
    
    # Run post-upgrade validation if configured
    run_post_upgrade_validation "${target_version}"
    
    # Clean up generated values files for this version
    print_info "Cleaning up generated files..."
    rm -f "${SCRIPT_DIR}/platform-base-${target_version}.yaml" \
          "${SCRIPT_DIR}/platform-bootstrap-${target_version}.yaml" \
          "${SCRIPT_DIR}/platform-base-${target_version}.yaml.clean" \
          "${SCRIPT_DIR}/platform-bootstrap-${target_version}.yaml.clean" \
          "${SCRIPT_DIR}/tibco-cp-base-merged-${target_version}.yaml" \
          "${SCRIPT_DIR}/control-plane-${target_version}.yaml" 2>/dev/null || true
    
    # Restore original CHART_VERSION for next upgrade step if it was temporarily unset
    if [[ -n "${saved_chart_version}" ]] && [[ "${version_matches}" == "false" ]]; then
        export CHART_VERSION="${saved_chart_version}"
    fi
}

# Main execution
main() {
    # Interactive prompts - basic info (namespace, base release, helm repo)
    interactive_prompts_basic
    
    # Setup logging and temp
    setup_logging
    setup_temp_dir
    
    # Discover available versions and build version map
    discover_versions
    
    # Check dependencies
    check_dependencies
    echo ""
    
    # Verify namespace exists
    verify_namespace
    echo ""
    
    # Detect current versions
    detect_versions
    
    # Prompt for target version
    if ! prompt_target_version "${CURRENT_VERSION}"; then
        print_info "No upgrades needed"
        exit 0
    fi
    
    # Now that we know the current version, prompt for bootstrap if needed
    prompt_bootstrap_if_needed "${CURRENT_VERSION}"
    echo ""
    
    # Calculate upgrade path
    calculate_upgrade_path
    
    if [[ ${#UPGRADE_PATH[@]} -eq 0 ]]; then
        print_info "No upgrades needed"
        exit 0
    fi
    
    # Confirmation prompt
    print_separator
    print_info "╔════════════════════════════════════════════════════════════════╗"
    print_info "║  TIBCO PLATFORM CHARTS UPGRADE WORKFLOW"
    print_info "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_info "📊 Current Status:"
    print_info "  • Namespace: ${NAMESPACE}"
    print_info "  • Current Version: ${CURRENT_VERSION}"
    print_info "  • Platform Base Release: ${PLATFORM_BASE_RELEASE}"
    
    # Show bootstrap only for pre-1.13.0
    if ! [[ "${CURRENT_VERSION}" =~ ^1\.1[3-9]\. ]] && ! [[ "${CURRENT_VERSION}" =~ ^1\.[2-9][0-9]\. ]] && ! [[ "${CURRENT_VERSION}" =~ ^[2-9]\. ]]; then
        print_info "  • Platform Bootstrap Release: ${PLATFORM_BOOTSTRAP_RELEASE}"
    fi
    
    echo ""
    print_info "🎯 Upgrade Workflow:"
    print_info "  • Target Version: ${TARGET_VERSION}"
    print_info "  • Sequential upgrade from ${CURRENT_VERSION} to ${TARGET_VERSION}"
    print_info "  • Number of upgrade steps: ${#UPGRADE_PATH[@]}"
    
    # Format upgrade path with arrows
    local path_display="${CURRENT_VERSION}"
    for version in "${UPGRADE_PATH[@]}"; do
        path_display="${path_display} → ${version}"
    done
    print_info "  • Upgrade path: ${path_display}"
    echo ""
    print_info "🔄 What will happen for EACH version:"
    print_info "  1. Generate values.yaml from current Helm deployment"
    
    # Check if any version in path is 1.13.0+
    local has_unified=false
    local has_legacy=false
    for ver in "${UPGRADE_PATH[@]}"; do
        if [[ "${ver}" =~ ^1\.1[3-9]\. ]] || [[ "${ver}" =~ ^1\.[2-9][0-9]\. ]] || [[ "${ver}" =~ ^[2-9]\. ]]; then
            has_unified=true
        else
            has_legacy=true
        fi
    done
    
    if [[ "$has_legacy" == "true" ]]; then
        print_info "  2. Upgrade platform-bootstrap chart (for versions < 1.13.0)"
        print_info "  3. Upgrade platform-base chart (for versions < 1.13.0)"
    fi
    if [[ "$has_unified" == "true" ]]; then
        print_info "  2. Upgrade tibco-cp-base chart only (for versions >= 1.13.0)"
    fi
    print_info "  3. Verify upgrade success and pod status"
    echo ""
    print_info "📝 All upgrade logs will be shown on screen and saved to:"
    print_info "  ${LOG_FILE}"
    echo ""
    
    # Show validation info if configured
    if [[ -n "${POST_UPGRADE_VALIDATION_SCRIPT:-}" ]]; then
        print_info "🔍 Post-upgrade validation enabled:"
        print_info "  ${POST_UPGRADE_VALIDATION_SCRIPT}"
        print_info "  (Will run after each successful upgrade step)"
        echo ""
    fi
    
    print_warning "⚠️  This is a FULLY AUTOMATED process"
    print_warning "⚠️  Ensure you have reviewed the upgrade requirements"
    print_warning "⚠️  Have a rollback plan ready if needed"
    echo ""
    read -p "Do you want to proceed with the sequential upgrade? (yes/no): " confirm
    
    if [[ "${confirm}" != "yes" ]]; then
        print_info "Cancelled by user"
        exit 0
    fi
    
    # Execute upgrades
    for target_version in "${UPGRADE_PATH[@]}"; do
        execute_upgrade "${target_version}"
        CURRENT_VERSION="${target_version}"
    done
    
    # Final verification
    print_separator
    print_success "╔════════════════════════════════════════════════════════════════╗"
    print_success "║  ALL UPGRADES COMPLETED SUCCESSFULLY!"
    print_success "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_success "Final version: $(get_chart_version "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}")"
    print_info "Log file: ${LOG_FILE}"
    print_separator
}

# Run main (interactive mode - no arguments needed)
main
