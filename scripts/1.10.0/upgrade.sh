#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Tested with: GNU bash, version 5.2.21(1)-release
#
# TIBCO Control Plane Helm Values Generation Script for Platform Upgrade (1.9.0 → 1.10.0)
# Generates upgrade-ready values.yaml files for platform-base and platform-bootstrap charts

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
PLATFORM_BOOTSTRAP_FILE=""
PLATFORM_BASE_FILE=""
PLATFORM_OUTPUT_BASE_FILE=""
PLATFORM_OUTPUT_BOOTSTRAP_FILE=""
DEFAULT_VERSION="1.10.0"
TEMP_DIR=""
OPERATION_MODE=""
NAMESPACE=""
PLATFORM_BOOTSTRAP_RELEASE_NAME="platform-bootstrap"
PLATFORM_BASE_RELEASE_NAME="platform-base"

# Enhanced mode variables
HELM_UPGRADE_MODE=false
TP_HELM_CHARTS_REPO=""
CHART_VERSION="1.10.0"

# Upgrade selection variables
UPGRADE_BOOTSTRAP=false
UPGRADE_BASE=false

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} ${1}"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} ${1}"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} ${1}"; }
print_error() { echo -e "${RED}[ERROR]${NC} ${1}" >&2; }

# Usage help
show_usage() {
    cat << EOF
TIBCO Control Plane Upgrade Assistant - 1.9.0 to 1.10.0
==================================================

This script provides an interactive experience to help you upgrade your TIBCO Control Plane
from version 1.9.0 to 1.10.0.

USAGE:
  Simply run: $0

The script will guide you through:
1. Choosing between values generation or Helm upgrade
2. Configuring input sources (files or Helm extraction)
3. Setting custom output file names (optional)
4. Performing the upgrade operations

Prerequisites:
  - yq (YAML processor) v4.0+
  - Bash version 4.0+
  - Helm v3.17+ (for helm operations)
  - kubectl (for upgrade verification)
  - jq (for JSON parsing during upgrade validation)

No command-line arguments needed - everything is handled interactively!
EOF
}

# Interactive mode for user input
interactive_mode() {
    print_info "TIBCO Control Plane Upgrade Script - 1.9.0 to 1.10.0"
    print_info "=================================================="
    echo ""
    
    echo "Please select your operation mode:"
    echo "1) Generate 1.10.0 values.yaml files from current 1.9.0 setup"
    echo "2) Perform Helm upgrade using existing 1.10.0-compatible values.yaml files"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate 1.10.0 values.yaml files"
                interactive_values_generation
                break
                ;;
            2)
                print_info "Selected: Perform Helm upgrade"
                interactive_helm_upgrade
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Interactive values generation setup
interactive_values_generation() {
    echo ""
    print_info "Values Generation Setup"
    print_info "======================"
    echo ""
    echo "How would you like to provide your current 1.9.0 values?"
    echo "1) I have existing 1.9.0 values.yaml files"
    echo "2) Extract values from running Helm deployments"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Use existing values.yaml files"
                OPERATION_MODE="file"
                interactive_file_input
                break
                ;;
            2)
                print_info "Selected: Extract from Helm deployments"
                OPERATION_MODE="helm"
                interactive_helm_input
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Interactive file input
interactive_file_input() {
    echo ""
    # Get input files
    while [[ -z "${PLATFORM_BOOTSTRAP_FILE}" ]]; do
        read -p "Enter file name of platform-bootstrap values.yaml file: " PLATFORM_BOOTSTRAP_FILE
        if [[ ! -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
            print_error "File not found: ${PLATFORM_BOOTSTRAP_FILE}"
            PLATFORM_BOOTSTRAP_FILE=""
        fi
    done
    
    while [[ -z "${PLATFORM_BASE_FILE}" ]]; do
        read -p "Enter file name of platform-base values.yaml file: " PLATFORM_BASE_FILE
        if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
            print_error "File not found: ${PLATFORM_BASE_FILE}"
            PLATFORM_BASE_FILE=""
        fi
    done
    
    print_success "Input files validated successfully"
    
    # Ask for custom output file names
    echo ""
    print_info "Output File Configuration"
    print_info "========================"
    echo ""
    
    read -p "Custom output file for platform-base (default: platform-base-1.10.0.yaml): " custom_base_output
    if [[ -n "${custom_base_output}" ]]; then
        PLATFORM_OUTPUT_BASE_FILE="${custom_base_output}"
        print_info "Using custom platform-base output: ${PLATFORM_OUTPUT_BASE_FILE}"
    else
        print_info "Using default platform-base output: platform-base-1.10.0.yaml"
    fi
    
    read -p "Custom output file for platform-bootstrap (default: platform-bootstrap-1.10.0.yaml): " custom_bootstrap_output
    if [[ -n "${custom_bootstrap_output}" ]]; then
        PLATFORM_OUTPUT_BOOTSTRAP_FILE="${custom_bootstrap_output}"
        print_info "Using custom platform-bootstrap output: ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    else
        print_info "Using default platform-bootstrap output: platform-bootstrap-1.10.0.yaml"
    fi
    
    print_success "Configuration completed successfully"
}

# Interactive Helm input
interactive_helm_input() {
    echo ""
    # Get Helm configuration
    while [[ -z "${NAMESPACE}" ]]; do
        read -p "Enter Kubernetes namespace containing your deployments: " NAMESPACE
    done
    
    read -p "Platform Bootstrap release name (default: platform-bootstrap): " input_bootstrap
    [[ -n "${input_bootstrap}" ]] && PLATFORM_BOOTSTRAP_RELEASE_NAME="${input_bootstrap}"
    
    read -p "Platform Base release name (default: platform-base): " input_base
    [[ -n "${input_base}" ]] && PLATFORM_BASE_RELEASE_NAME="${input_base}"
    
    print_success "Helm extraction configuration set successfully"
    
    # Ask for custom output file names
    echo ""
    print_info "Output File Configuration"
    print_info "========================"
    echo ""
    
    read -p "Custom output file for platform-base (default: platform-base-1.10.0.yaml): " custom_base_output
    if [[ -n "${custom_base_output}" ]]; then
        PLATFORM_OUTPUT_BASE_FILE="${custom_base_output}"
        print_info "Using custom platform-base output: ${PLATFORM_OUTPUT_BASE_FILE}"
    else
        print_info "Using default platform-base output: platform-base-1.10.0.yaml"
    fi
    
    read -p "Custom output file for platform-bootstrap (default: platform-bootstrap-1.10.0.yaml): " custom_bootstrap_output
    if [[ -n "${custom_bootstrap_output}" ]]; then
        PLATFORM_OUTPUT_BOOTSTRAP_FILE="${custom_bootstrap_output}"
        print_info "Using custom platform-bootstrap output: ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    else
        print_info "Using default platform-bootstrap output: platform-bootstrap-1.10.0.yaml"
    fi
    
    print_success "Configuration completed successfully"
}

# Interactive Helm upgrade setup
interactive_helm_upgrade() {
    echo ""
    print_info "Helm Upgrade Setup"
    print_info "=================="
    echo ""
    
    print_info "This mode will perform actual Helm upgrades on your cluster using 1.10.0 values.yaml files."
    echo ""
    
    # Chart selection
    echo "Which chart would you like to upgrade?"
    echo "1) platform-bootstrap"
    echo "2) platform-base"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " chart_choice
        case $chart_choice in
            1)
                print_info "Selected: platform-bootstrap"
                UPGRADE_BOOTSTRAP=true
                UPGRADE_BASE=false
                break
                ;;
            2)
                print_info "Selected: platform-base"
                UPGRADE_BOOTSTRAP=false
                UPGRADE_BASE=true
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    
    # Get values.yaml files based on selection
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        while [[ -z "${PLATFORM_BOOTSTRAP_FILE}" ]]; do
            read -p "Enter file name of 1.10.0 platform-bootstrap values.yaml file: " PLATFORM_BOOTSTRAP_FILE
            if [[ ! -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
                print_error "File not found: ${PLATFORM_BOOTSTRAP_FILE}"
                PLATFORM_BOOTSTRAP_FILE=""
            fi
        done
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        while [[ -z "${PLATFORM_BASE_FILE}" ]]; do
            read -p "Enter file name of 1.10.0 platform-base values.yaml file: " PLATFORM_BASE_FILE
            if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
                print_error "File not found: ${PLATFORM_BASE_FILE}"
                PLATFORM_BASE_FILE=""
            fi
        done
    fi
    
    # Get cluster information
    while [[ -z "${NAMESPACE}" ]]; do
        read -p "Enter target namespace for upgrade: " NAMESPACE
    done
    
    # Get release names based on selection
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        read -p "Platform Bootstrap release name (default: platform-bootstrap): " input_bootstrap
        [[ -n "${input_bootstrap}" ]] && PLATFORM_BOOTSTRAP_RELEASE_NAME="${input_bootstrap}"
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        read -p "Platform Base release name (default: platform-base): " input_base
        [[ -n "${input_base}" ]] && PLATFORM_BASE_RELEASE_NAME="${input_base}"
    fi
    
    # Get Helm repository name
    read -p "Enter Helm repository name (default: tibco-platform): " TP_HELM_REPO_NAME
    [[ -z "${TP_HELM_REPO_NAME}" ]] && TP_HELM_REPO_NAME="tibco-platform"
    
    print_success "Helm upgrade configuration complete"
    
    # Set mode to indicate upgrade
    HELM_UPGRADE_MODE=true
    OPERATION_MODE="file"  # We're using files for the upgrade
}

# Individual chart upgrade functions
upgrade_bootstrap_chart() {
    print_info "Upgrading ${PLATFORM_BOOTSTRAP_RELEASE_NAME} to version ${CHART_VERSION}..."
    if helm upgrade "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/platform-bootstrap" \
        --version "${CHART_VERSION}" \
        --namespace "${NAMESPACE}" \
        --values "${PLATFORM_BOOTSTRAP_FILE}" \
        --wait --timeout=15m; then
        print_success "Successfully upgraded ${PLATFORM_BOOTSTRAP_RELEASE_NAME}"
        return 0
    else
        print_error "Failed to upgrade ${PLATFORM_BOOTSTRAP_RELEASE_NAME}"
        return 1
    fi
}

upgrade_base_chart() {
    print_info "Upgrading ${PLATFORM_BASE_RELEASE_NAME} to version ${CHART_VERSION}..."
    if helm upgrade "${PLATFORM_BASE_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/platform-base" \
        --version "${CHART_VERSION}" \
        --namespace "${NAMESPACE}" \
        --values "${PLATFORM_BASE_FILE}" \
        --wait --timeout=1h; then
        print_success "Successfully upgraded ${PLATFORM_BASE_RELEASE_NAME}"
        return 0
    else
        print_error "Failed to upgrade ${PLATFORM_BASE_RELEASE_NAME}"
        return 1
    fi
}

# Helm upgrade functionality
perform_helm_upgrade() {
    print_info "Starting Helm upgrade process"
    print_info "============================="
    
    # Validate current deployment versions (must be 1.9.0) for selected charts
    print_info "Validating current deployment versions..."
    
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        local bootstrap_version=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE_NAME}$" -o json | jq -r '.[0].app_version // "unknown"' 2>/dev/null)
        if [[ "${bootstrap_version}" != "1.9.0" ]]; then
            print_error "Current ${PLATFORM_BOOTSTRAP_RELEASE_NAME} version is '${bootstrap_version}', expected '1.9.0'"
            print_error "This script only supports upgrades from 1.9.0 to 1.10.0"
            return 1
        fi
        print_success "Bootstrap version validation passed: ${bootstrap_version}"
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        local base_version=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json | jq -r '.[0].app_version // "unknown"' 2>/dev/null)
        if [[ "${base_version}" != "1.9.0" ]]; then
            print_error "Current ${PLATFORM_BASE_RELEASE_NAME} version is '${base_version}', expected '1.9.0'"
            print_error "This script only supports upgrades from 1.9.0 to 1.10.0"
            return 1
        fi
        print_success "Base version validation passed: ${base_version}"
    fi
    
    # Update Helm repository
    print_info "Updating TP Helm charts repository..."
    helm repo update "${TP_HELM_REPO_NAME}"
    print_success "Repository updated successfully"
    
    # Upgrade platform-bootstrap (if selected)
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        upgrade_bootstrap_chart
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi
    
    # Upgrade platform-base (if selected)
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        upgrade_base_chart
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi
    
    # Verify upgrades
    verify_helm_upgrades
}

# Verify Helm upgrades
verify_helm_upgrades() {
    print_info "Verifying Helm upgrades..."
    echo ""
    
    # Check if releases exist and are deployed (only for selected charts)
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        if helm status "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            print_success "Platform Bootstrap chart upgraded successfully"
        else
            print_error "Platform Bootstrap chart upgrade failed or release not found"
        fi
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        if helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            print_success "Platform Base chart upgraded successfully"
        else
            print_error "Platform Base chart upgrade failed or release not found"
        fi
    fi
    
    echo ""
    # Check pod status
    print_info "Checking pod readiness in namespace ${NAMESPACE}..."
    if kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | grep -q .; then
        print_warning "Some pods are not in Running/Completed state:"
        kubectl get pods -n "${NAMESPACE}" --no-headers | grep -v "Running\|Completed" || true
    else
        print_success "All pods are in Running/Completed state"
    fi
    
    print_success "Upgrade verification completed"
}

# Setup temp directory with cleanup trap
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "${TEMP_DIR}" 2>/dev/null || true' EXIT
    print_info "Temp directory: ${TEMP_DIR}"
}

# Check dependencies and versions
check_dependencies() {
    print_info "Checking dependencies..."
    # Check yq availability and version (safe under set -e)
    if ! command -v yq >/dev/null 2>&1; then
        print_error "yq is required. Install with: sudo apt-get install yq or brew install yq"
        echo "Dependency check failed: yq not found"  # explicit stdout message
        exit 1
    fi
    print_info "yq path: $(command -v yq)"
    
    local yq_version=""
    if yq --version >/dev/null 2>&1; then
        yq_version=$(yq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    fi
    if [[ -n "${yq_version}" ]]; then
        local yq_major=$(echo "${yq_version}" | cut -d. -f1)
        if [[ ${yq_major} -lt 4 ]]; then
            print_warning "yq version ${yq_version} detected. Recommended: yq v4.0 or higher"
        else
            print_info "yq version ${yq_version} - OK"
        fi
    else
        print_warning "Could not determine yq version. Proceeding with caution..."
    fi
    
    # Check helm availability and version (for helm mode and upgrade mode)
    if [[ "${OPERATION_MODE}" == "helm" || "${HELM_UPGRADE_MODE}" == "true" ]]; then
        if ! command -v helm >/dev/null 2>&1; then
            print_error "helm is required for helm mode. Install from: https://helm.sh/docs/intro/install/"
            echo "Dependency check failed: helm not found"  # explicit stdout message
            exit 1
        fi
        print_info "helm path: $(command -v helm)"
        
        local helm_version=""
        if helm version --short >/dev/null 2>&1; then
            helm_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+' | head -1 | sed 's/v//')
        fi
        if [[ -n "${helm_version}" ]]; then
            local helm_major=$(echo "${helm_version}" | cut -d. -f1)
            local helm_minor=$(echo "${helm_version}" | cut -d. -f2)
            
            # Check for Helm 3.17+
            if [[ ${helm_major} -lt 3 ]] || [[ ${helm_major} -eq 3 && ${helm_minor} -lt 17 ]]; then
                print_error "Helm version ${helm_version} detected. Required: Helm v3.17 or higher"
                print_error "Please upgrade Helm: https://helm.sh/docs/intro/install/"
                exit 1
            else
                print_info "Helm version ${helm_version} - OK"
            fi
        else
            print_warning "Could not determine Helm version. Proceeding with caution..."
        fi
    fi
    
    # Check jq availability (used for JSON parsing in upgrade validation)
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required. Install with: sudo apt-get install jq or brew install jq"
        echo "Dependency check failed: jq not found"  # explicit stdout message
        exit 1
    fi
    print_info "jq path: $(command -v jq)"
    
    # Soft-check jq version (recommend 1.5+)
    local jq_version=""
    if jq --version >/dev/null 2>&1; then
        jq_version=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    fi
    if [[ -n "${jq_version}" ]]; then
        local jq_major=$(echo "${jq_version}" | cut -d. -f1)
        local jq_minor=$(echo "${jq_version}" | cut -d. -f2)
        if [[ ${jq_major} -lt 1 ]] || [[ ${jq_major} -eq 1 && ${jq_minor} -lt 5 ]]; then
            print_warning "jq version ${jq_version} detected. Recommended: jq 1.5 or higher"
        else
            print_info "jq version ${jq_version} - OK"
        fi
    else
        print_warning "Could not determine jq version. Proceeding with caution..."
    fi
    
    # Check kubectl availability (used in verification steps)
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is required. Install from: https://kubernetes.io/docs/tasks/tools/"
        echo "Dependency check failed: kubectl not found"  # explicit stdout message
        exit 1
    fi
    print_info "kubectl path: $(command -v kubectl)"
}

# Extract Helm values
extract_helm_values() {
    print_info "Extracting Helm values from namespace: ${NAMESPACE}"
    
    # Extract bootstrap values
    helm get values -n "${NAMESPACE}" "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" > "${TEMP_DIR}/temp-bootstrap-raw.yaml"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to extract values from release: ${PLATFORM_BOOTSTRAP_RELEASE_NAME}"
        exit 1
    fi
    
    # Remove header if present and create clean bootstrap file
    if head -1 "${TEMP_DIR}/temp-bootstrap-raw.yaml" | grep -q "USER-SUPPLIED VALUES"; then
        tail -n +2 "${TEMP_DIR}/temp-bootstrap-raw.yaml" > "${TEMP_DIR}/temp-bootstrap.yaml"
    else
        cp "${TEMP_DIR}/temp-bootstrap-raw.yaml" "${TEMP_DIR}/temp-bootstrap.yaml"
    fi
    [[ ! -s "${TEMP_DIR}/temp-bootstrap.yaml" ]] && echo "{}" > "${TEMP_DIR}/temp-bootstrap.yaml"
    
    # Extract base values
    helm get values -n "${NAMESPACE}" "${PLATFORM_BASE_RELEASE_NAME}" > "${TEMP_DIR}/temp-base-raw.yaml"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to extract values from release: ${PLATFORM_BASE_RELEASE_NAME}"
        exit 1
    fi
    
    # Remove header if present and create clean base file
    if head -1 "${TEMP_DIR}/temp-base-raw.yaml" | grep -q "USER-SUPPLIED VALUES"; then
        tail -n +2 "${TEMP_DIR}/temp-base-raw.yaml" > "${TEMP_DIR}/temp-base.yaml"
    else
        cp "${TEMP_DIR}/temp-base-raw.yaml" "${TEMP_DIR}/temp-base.yaml"
    fi
    [[ ! -s "${TEMP_DIR}/temp-base.yaml" ]] && echo "{}" > "${TEMP_DIR}/temp-base.yaml"
    
    PLATFORM_BOOTSTRAP_FILE="${TEMP_DIR}/temp-bootstrap.yaml"
    PLATFORM_BASE_FILE="${TEMP_DIR}/temp-base.yaml"
    
    # Ensure files are fully written (potential timing fix)
    sync 2>/dev/null || true
    sleep 1
    
    print_success "Helm values extracted successfully"
}

# Generate output filenames
generate_output_filenames() {
    local base_dir=$([[ "${OPERATION_MODE}" == "helm" ]] && echo "." || dirname "${PLATFORM_BASE_FILE}")
    [[ -z "${PLATFORM_OUTPUT_BASE_FILE}" ]] && PLATFORM_OUTPUT_BASE_FILE="${base_dir}/platform-base-${DEFAULT_VERSION}.yaml"
    [[ -z "${PLATFORM_OUTPUT_BOOTSTRAP_FILE}" ]] && PLATFORM_OUTPUT_BOOTSTRAP_FILE="${base_dir}/platform-bootstrap-${DEFAULT_VERSION}.yaml"
    print_info "Output files: ${PLATFORM_OUTPUT_BASE_FILE}, ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
}

# Main processing function - combines extract, validate, transform, and merge
process_files() {
    print_info "Processing files for upgrade generation..."
    
    # Validate bootstrap file
    if [[ ! -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        print_error "Bootstrap file not found: ${PLATFORM_BOOTSTRAP_FILE}"
        exit 1
    fi
    
    if [[ ! -r "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        print_error "Bootstrap file not readable: ${PLATFORM_BOOTSTRAP_FILE}"
        exit 1
    fi
    
    # Check for compute-services (optional)
    local has_compute_services=false
    
    # Ensure file is ready for reading (timing fix)
    if [[ ! -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        print_error "Bootstrap file missing during detection: ${PLATFORM_BOOTSTRAP_FILE}"
        exit 1
    fi
    
    # Wait a moment and capture file content to avoid deletion race condition
    sleep 0.1
    
    # Copy entire file content to avoid race condition with file deletion
    local platform_bootstrap_file_content=""
    if [[ -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        platform_bootstrap_file_content=$(cat "${PLATFORM_BOOTSTRAP_FILE}" 2>/dev/null || echo "")
    fi
    
    # Use yq on the content via stdin instead of file path
    local compute_services_content=""
    if [[ -n "${platform_bootstrap_file_content}" ]]; then
        compute_services_content=$(echo "${platform_bootstrap_file_content}" | yq eval '.compute-services' - 2>/dev/null || echo "null")
    else
        compute_services_content="null"
    fi
    
    if [[ "${compute_services_content}" != "null" ]] && echo "${compute_services_content}" | grep -q "enabled"; then
        print_info "compute-services section found - will be included in generated values"
        has_compute_services=true
        echo "${compute_services_content}" > "${TEMP_DIR}/compute-services.yaml"
    else
        print_warning "compute-services section not found - skipping in generated values"
    fi
    
    # Extract dnsTunnelDomain
    local dns_tunnel_value=""
    if grep -q "dnsTunnelDomain:" "${PLATFORM_BOOTSTRAP_FILE}" 2>/dev/null; then
        dns_tunnel_value=$(grep "dnsTunnelDomain:" "${PLATFORM_BOOTSTRAP_FILE}" | sed 's/.*dnsTunnelDomain: *//g' | tr -d '"' | tr -d "'" | head -1)
        print_info "Found dnsTunnelDomain: ${dns_tunnel_value}"
    elif grep -q "dnsTunnelDomain:" "${PLATFORM_BASE_FILE}" 2>/dev/null; then
        dns_tunnel_value=$(grep "dnsTunnelDomain:" "${PLATFORM_BASE_FILE}" | sed 's/.*dnsTunnelDomain: *//g' | tr -d '"' | tr -d "'" | head -1)
        print_info "Found dnsTunnelDomain: ${dns_tunnel_value}"
    else
        print_warning "dnsTunnelDomain not found - values generation will proceed without it"
    fi
    
    # Process base file
    cp "${PLATFORM_BASE_FILE}" "${PLATFORM_OUTPUT_BASE_FILE}"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to process platform-base file"
        exit 1
    fi
    
    # Transform and merge compute-services to tp-cp-infra if exists
    if [[ "${has_compute_services}" == "true" ]]; then
        print_info "Processing compute-services transformation to tp-cp-infra..."
        local compute_services_content=$(cat "${TEMP_DIR}/compute-services.yaml")
        
        # Check if compute-services contains a resources section
        local compute_resources=""
        compute_resources=$(echo "${compute_services_content}" | yq eval '.resources' - 2>/dev/null || echo "null")
        
        if [[ "${compute_resources}" != "null" ]]; then
            print_info "Found resources section in compute-services - will migrate to tp-cp-infra.resources.infra-compute-services"
            
            # Create compute-services without resources for tp-cp-infra
            local compute_services_without_resources=$(echo "${compute_services_content}" | yq eval 'del(.resources)' - 2>/dev/null)
            
            # Create tp-cp-infra section with compute-services and resources
            cat > "${TEMP_DIR}/tp-cp-infra.yaml" << EOF
tp-cp-infra:
$(echo "${compute_services_without_resources}" | sed 's/^/  /')
  resources:
    infra-compute-services:
$(echo "${compute_resources}" | sed 's/^/      /')
EOF
        else
            # No resources section, use original logic
            cat > "${TEMP_DIR}/tp-cp-infra.yaml" << EOF
tp-cp-infra:
$(echo "${compute_services_content}" | sed 's/^/  /')
EOF
        fi
        
        # Merge tp-cp-infra at root level
        cp "${TEMP_DIR}/tp-cp-infra.yaml" "./tp-cp-infra-temp.yaml"
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "${PLATFORM_OUTPUT_BASE_FILE}" "./tp-cp-infra-temp.yaml" > "${PLATFORM_OUTPUT_BASE_FILE}.tmp"
        if [[ $? -ne 0 ]]; then
            rm -f "./tp-cp-infra-temp.yaml"
            print_error "Failed to merge tp-cp-infra content"
            exit 1
        fi
        mv "${PLATFORM_OUTPUT_BASE_FILE}.tmp" "${PLATFORM_OUTPUT_BASE_FILE}"
        rm -f "./tp-cp-infra-temp.yaml"
    fi
    
    # Merge dnsTunnelDomain if exists
    if [[ -n "${dns_tunnel_value}" ]]; then
        print_info "Merging dnsTunnelDomain: ${dns_tunnel_value}"
        yq eval '.global.external.dnsTunnelDomain = "'"${dns_tunnel_value}"'"' -i "${PLATFORM_OUTPUT_BASE_FILE}"
        if [[ $? -ne 0 ]]; then
            print_error "Failed to merge dnsTunnelDomain content"
            exit 1
        fi
    fi
    
    # Generate cleaned platform-bootstrap
    if [[ "${has_compute_services}" == "true" ]]; then
        print_info "Removing compute-services from platform-bootstrap file..."
        # Use the captured content instead of file path to avoid race condition
        echo "${platform_bootstrap_file_content}" | yq eval 'del(.compute-services)' - > "${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    else
        print_info "Copying platform-bootstrap file as-is..."
        # Use the captured content instead of file path to avoid race condition
        echo "${platform_bootstrap_file_content}" > "${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    fi
    
    print_success "Processing completed successfully"
    
    # Summary
    print_info "Values generation summary:"
    if [[ "${has_compute_services}" == "true" ]]; then
        print_info "  [+] compute-services -> tp-cp-infra at root level"
        print_info "  [+] Generated cleaned platform-bootstrap - compute-services removed"
    else
        print_info "  [-] compute-services section not found - skipped"
        print_info "  [+] platform-bootstrap file copied as-is - no compute-services to remove"
    fi
    [[ -n "${dns_tunnel_value}" ]] && print_info "  [+] dnsTunnelDomain: ${dns_tunnel_value} -> global.external.dnsTunnelDomain" || print_info "  [-] dnsTunnelDomain not found - skipped"
    print_info "  [+] Generated version-specific files - version: ${DEFAULT_VERSION}"
}

# Main execution
main() {
    print_info "TIBCO Control Plane Upgrade Script - 1.9.0 to 1.10.0"
    print_info "=================================================="
    
    # Handle help request
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Always run in interactive mode
    setup_temp_dir
    check_dependencies
    interactive_mode
    
    # Handle Helm upgrade mode
    if [[ "${HELM_UPGRADE_MODE}" == "true" ]]; then
        echo ""
        print_warning "WARNING: This will perform actual Helm upgrades on your cluster!"
        print_info "Target namespace: ${NAMESPACE}"
        
        # Show only selected chart details
        if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
            print_info "Platform Bootstrap release: ${PLATFORM_BOOTSTRAP_RELEASE_NAME}"
        fi
        
        if [[ "${UPGRADE_BASE}" == "true" ]]; then
            print_info "Platform Base release: ${PLATFORM_BASE_RELEASE_NAME}"
        fi
        
        print_info "Chart version: ${CHART_VERSION}"
        echo ""
        
        read -p "Do you want to proceed with the upgrade? (yes/no): " confirm
        if [[ "${confirm}" == "yes" ]]; then
            perform_helm_upgrade
            print_success "All operations completed successfully!"
            exit 0
        else
            print_info "Helm upgrade cancelled by user"
            exit 0
        fi
    else
        # Standard values generation mode
        [[ "${OPERATION_MODE}" == "helm" ]] && extract_helm_values
        
        generate_output_filenames
        process_files
        
        echo ""
        print_success "Values.yaml generation completed successfully!"
        print_info "Generated values.yaml files for upgrade:"
        print_info "  - platform-base: ${PLATFORM_OUTPUT_BASE_FILE}"
        print_info "  - platform-bootstrap: ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    fi
    
    print_success "All operations completed successfully!"
}

# Execute main function
main "${@}"
