#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# TIBCO Control Plane Master Upgrade Script
# Automatically detects current chart versions and performs sequential upgrades
# Fully automated with values generation and helm upgrades
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
    print_success "Latest version detected: ${LATEST_VERSION}"
    
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
    exec > >(tee -a "${LOG_FILE}") 2>&1
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

# Show target version selection menu
select_target_version() {
    print_separator
    print_step "Target Version Selection"
    echo ""
    print_info "Available upgrade versions:"
    echo ""
    
    local i=1
    for version in "${AVAILABLE_VERSIONS[@]}"; do
        if [[ "${version}" == "${CURRENT_VERSION}" ]]; then
            echo "${i}) ${version} (current)"
        elif [[ "${version}" == "${LATEST_VERSION}" ]]; then
            echo "${i}) ${version} (latest)"
        else
            echo "${i}) ${version}"
        fi
        ((i++))
    done
    echo ""
    
    while true; do
        read -p "Select target version to upgrade to (1-$((i-1)), or press Enter for latest): " version_choice
        
        # Default to latest if Enter pressed
        if [[ -z "${version_choice}" ]]; then
            TARGET_VERSION="${LATEST_VERSION}"
            print_info "Using latest version: ${TARGET_VERSION}"
            break
        fi
        
        # Validate numeric input
        if [[ "${version_choice}" =~ ^[0-9]+$ ]]; then
            if [[ ${version_choice} -ge 1 && ${version_choice} -le $((i-1)) ]]; then
                TARGET_VERSION="${AVAILABLE_VERSIONS[$((version_choice-1))]}"
                
                # Check if selected version is older than or equal to current
                local selected_idx=$((version_choice-1))
                local current_idx=-1
                for idx in "${!AVAILABLE_VERSIONS[@]}"; do
                    if [[ "${AVAILABLE_VERSIONS[$idx]}" == "${CURRENT_VERSION}" ]]; then
                        current_idx=$idx
                        break
                    fi
                done
                
                if [[ ${selected_idx} -le ${current_idx} ]]; then
                    print_error "Selected version ${TARGET_VERSION} is not newer than current version ${CURRENT_VERSION}"
                    print_error "Please select a version newer than ${CURRENT_VERSION}"
                    continue
                fi
                
                print_info "Selected target version: ${TARGET_VERSION}"
                break
            else
                print_error "Invalid choice. Please enter a number between 1 and $((i-1))."
            fi
        else
            print_error "Invalid input. Please enter a number."
        fi
    done
    
    print_success "Target version set to: ${TARGET_VERSION}"
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
    done
    
    echo ""
    print_success "Upgrade path calculated: ${#UPGRADE_PATH[@]} step(s)"
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
    
    # Check for version-specific CHART_VERSION override, Internal Usage only
    # e.g., CHART_VERSION_1_13_0="1.13.0-alpha.1"
    local version_env_var="CHART_VERSION_$(echo ${target_version} | tr '.' '_')"
    local version_specific_chart_version="${!version_env_var:-}"
    
    if [[ -n "${version_specific_chart_version}" ]]; then
        print_info "Using version-specific chart version: ${version_specific_chart_version}"
        export CHART_VERSION="${version_specific_chart_version}"
    elif [[ -n "${CHART_VERSION:-}" ]]; then
        print_info "Using global chart version: ${CHART_VERSION}"
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
          "${SCRIPT_DIR}/tibco-cp-base-merged-${target_version}.yaml" 2>/dev/null || true
    echo ""
    
    print_info ">>> Executing upgrade script for values generation..."
    print_separator
    
    local step1_input="${TEMP_DIR}/step1_${target_version}.txt"
    
    # Input differs between 1.13.0 and earlier versions
    if [[ "${target_version}" == "1.13.0" ]]; then
        # 1.13.0 asks for: namespace, bootstrap release, base release, merged output file
        print_info "  └─ Output file: tibco-cp-base-merged-${target_version}.yaml (default)"
        cat > "${step1_input}" << EOF
1
2
${NAMESPACE}



EOF
    else
        # Pre-1.13.0 asks for: namespace, bootstrap release, base release, base output, bootstrap output
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
    
    # Check if version 1.13.0 (unified chart)
    if [[ "${target_version}" == "1.13.0" ]]; then
        print_warning "Version 1.13.0 uses unified chart"
        echo ""
        
        # STEP 2: Upgrade Base only (unified chart for 1.13.0)
        print_step "STEP 2/2: Upgrading platform-base chart (unified tibco-cp-base)"
        print_info "  ├─ Selecting: Perform Helm upgrade (Option 2)"
        print_info "  ├─ Values file: tibco-cp-base-merged-${target_version}.yaml"
        print_info "  ├─ Namespace: ${NAMESPACE}"
        print_info "  ├─ Release: ${PLATFORM_BASE_RELEASE}"
        print_info "  └─ Helm repo: ${TP_HELM_REPO_NAME}"
        echo ""
        print_info ">>> Executing helm upgrade for platform-base..."
        print_separator
        
        local step2_input="${TEMP_DIR}/step2_${target_version}.txt"
        # Note: 1.13.0 doesn't ask for chart selection, values file + upgrade confirmation + cleanup prompt
        cat > "${step2_input}" << EOF
2
tibco-cp-base-merged-${target_version}.yaml
${NAMESPACE}

${TP_HELM_REPO_NAME}
yes
no
EOF
        
        echo "=== BEGIN PLATFORM-BASE UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
        if ! (cd "${SCRIPT_DIR}" && bash "${upgrade_script}" < "${step2_input}") 2>&1 | tee -a "${TEMP_DIR}/step2_${target_version}.log"; then
            echo "=== END PLATFORM-BASE UPGRADE LOG (FAILED) ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
            handle_upgrade_failure "platform-base" "${target_version}" "${TEMP_DIR}/step2_${target_version}.log"
        fi
        echo "=== END PLATFORM-BASE UPGRADE LOG ===" | tee -a "${TEMP_DIR}/step2_${target_version}.log"
        
        print_success "✓ Platform-base chart upgraded successfully"
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
    
    # Clean up generated values files for this version
    print_info "Cleaning up generated files..."
    rm -f "${SCRIPT_DIR}/platform-base-${target_version}.yaml" \
          "${SCRIPT_DIR}/platform-bootstrap-${target_version}.yaml" \
          "${SCRIPT_DIR}/platform-base-${target_version}.yaml.clean" \
          "${SCRIPT_DIR}/platform-bootstrap-${target_version}.yaml.clean" \
          "${SCRIPT_DIR}/tibco-cp-base-merged-${target_version}.yaml" 2>/dev/null || true
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
    
    # Now that we know the current version, prompt for bootstrap if needed
    prompt_bootstrap_if_needed "${CURRENT_VERSION}"
    echo ""
    
    # Let user select target version
    select_target_version
    
    # Calculate upgrade path to selected version
    calculate_upgrade_path
    
    if [[ ${#UPGRADE_PATH[@]} -eq 0 ]]; then
        print_info "No upgrades needed"
        exit 0
    fi
    
    # Confirmation prompt
    print_separator
    print_info "╔════════════════════════════════════════════════════════════════╗"
    print_info "║  TIBCO PLATFORM CHARTS DETECTED"
    print_info "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_info "📊 Current Status:"
    print_info "  • Platform Bootstrap: ${PLATFORM_BOOTSTRAP_RELEASE} = ${CURRENT_VERSION}"
    print_info "  • Platform Base: ${PLATFORM_BASE_RELEASE} = ${CURRENT_VERSION}"
    echo ""
    print_info "🎯 Upgrade Plan:"
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
    print_info "  2. Upgrade platform-bootstrap chart (if applicable)"
    print_info "  3. Upgrade platform-base chart"
    print_info "  4. Verify upgrade success and pod status"
    echo ""
    print_info "📝 All upgrade logs will be shown on screen and saved to:"
    print_info "  ${LOG_FILE}"
    echo ""
    if [[ "${TARGET_VERSION}" != "${LATEST_VERSION}" ]]; then
        print_warning "⚠️  Note: Target version ${TARGET_VERSION} is not the latest available version (${LATEST_VERSION})"
        print_warning "⚠️  You can run this script again later to upgrade to ${LATEST_VERSION}"
    fi
    echo ""
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
