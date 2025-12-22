#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Tested with: GNU bash, version 5.2.21(1)-release
#
# TIBCO Control Plane Helm Values Generation Script for Platform Upgrade FROM 1.13.0 TO 1.14.0
# Works with the unified tibco-cp-base chart (single chart deployment)

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
PLATFORM_BASE_FILE=""
PLATFORM_OUTPUT_FILE=""
DEFAULT_VERSION="1.14.0"
TEMP_DIR=""
OPERATION_MODE=""
NAMESPACE=""
CONTROL_PLANE_RELEASE_NAME="platform-base"

# Enhanced mode variables
HELM_UPGRADE_MODE=false
TP_HELM_CHARTS_REPO=""
CHART_VERSION="${CHART_VERSION:-1.14.0}"

# yq and jq minimum versions variables
REQUIRED_YQ_VERSION="4.45.4"
REQUIRED_JQ_VERSION="1.8.0"

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} ${1}"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} ${1}"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} ${1}"; }
print_error() { echo -e "${RED}[ERROR]${NC} ${1}" >&2; }

version_ge() {
    local v1="$1" v2="$2"
    norm() {
        local v="$1"
        v=$(echo "$v" | grep -oE '[0-9]+(\.[0-9]+){1,2}' || echo "0.0.0")
        local a b c
        IFS='.' read -r a b c <<<"$v"
        [[ -z "$a" ]] && a=0; [[ -z "$b" ]] && b=0; [[ -z "$c" ]] && c=0
        printf "%d.%d.%d\n" "$a" "$b" "$c"
    }
    v1=$(norm "$v1"); v2=$(norm "$v2")
    IFS='.' read -r a1 b1 c1 <<<"$v1"
    IFS='.' read -r a2 b2 c2 <<<"$v2"
    if (( a1 > a2 )) || { (( a1 == a2 )) && (( b1 > b2 )); } || { (( a1 == a2 )) && (( b1 == b2 )) && (( c1 >= c2 )); }; then
        return 0
    else
        return 1
    fi
}

# Usage help
show_usage() {
    cat << EOF
TIBCO Control Plane Upgrade Assistant - 1.13.0 to 1.14.0
==================================================

This script provides an interactive experience to help you upgrade your TIBCO Control Plane
from version 1.13.0 to 1.14.0.

Note: In version 1.13.0+, there is only a single unified chart (tibco-cp-base or platform-base).
This script will extract values from the existing release and upgrade to 1.14.0.

USAGE:
  Simply run: $0

The script will guide you through:
1. Choosing between values generation or Helm upgrade
2. Configuring input sources (files or Helm extraction)
3. Setting custom output file name (optional)
4. Performing the upgrade operations
5. Interactive cleanup of bootstrap resources (for Helm upgrade mode)

Prerequisites:
  - yq (YAML processor) v4.0+ (required)
  - Bash version 4.0+ (required)
  - jq (JSON processor) v1.6+ (required only for Helm extraction/upgrade/validation)
  - Helm v3.17+ (required only for Helm extraction/upgrade/validation)
  - kubectl (required only for post-upgrade verification)

No command-line arguments needed - everything is handled interactively!

NOTE:
  - This script does NOT perform application-level or functional tests of the upgraded charts.
  - It assumes all chart values are correct, performs the upgrade from 1.13.0 to 1.14.0
    and verifies that the pods in the target namespace are in Running/Completed state.
  - We recommend you run your own post-upgrade tests as required.
EOF
}

# Interactive mode for user input
interactive_mode() {
    print_info "TIBCO Control Plane Upgrade Script - 1.13.0 to 1.14.0"
    print_info "======================================================="
    echo ""
    print_info "Note: This script works with the unified control plane chart (tibco-cp-base/platform-base)."
    print_info "This script will extract values from your 1.13.0 deployment and upgrade to 1.14.0."
    echo ""
    
    echo "Please select your operation mode:"
    echo "1) Generate 1.14.0 values.yaml file from current 1.13.0 setup"
    echo "2) Perform Helm upgrade using existing 1.14.0-compatible values.yaml file"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate 1.14.0 values.yaml file"
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
    echo "How would you like to provide your current 1.13.0 values?"
    echo "1) I have existing 1.13.0 values.yaml file"
    echo "2) Extract values from running Helm deployment"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Use existing values.yaml file"
                OPERATION_MODE="file"
                interactive_file_input
                break
                ;;
            2)
                print_info "Selected: Extract from Helm deployment"
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
    # Get input file
    while [[ -z "${PLATFORM_BASE_FILE}" ]]; do
        read -p "Enter file name of control plane values.yaml file (1.13.0): " PLATFORM_BASE_FILE
        if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
            print_error "File not found: ${PLATFORM_BASE_FILE}"
            PLATFORM_BASE_FILE=""
        fi
    done
    
    print_success "Input file validated successfully"
    
    # Ask for custom output file name
    echo ""
    print_info "Output File Configuration"
    print_info "========================"
    echo ""
    
    read -p "Custom output file for control plane (default: control-plane-1.14.0.yaml): " custom_output
    if [[ -n "${custom_output}" ]]; then
        PLATFORM_OUTPUT_FILE="${custom_output}"
        print_info "Using custom output: ${PLATFORM_OUTPUT_FILE}"
    else
        print_info "Using default output: control-plane-1.14.0.yaml"
    fi
    
    print_success "Configuration completed successfully"
}

# Interactive Helm input
interactive_helm_input() {
    # Validate mode-specific dependencies right away (helm/jq)
    print_info "Validating Helm/jq requirements for extraction..."
    check_dependencies

    echo ""
    # Get Helm configuration
    while [[ -z "${NAMESPACE}" ]]; do
        read -p "Enter Kubernetes namespace containing your deployment: " NAMESPACE
    done
    
    read -p "Enter control plane chart release name (default: platform-base): " input_release
    [[ -n "${input_release}" ]] && CONTROL_PLANE_RELEASE_NAME="${input_release}"
    
    print_success "Helm extraction configuration set successfully"
    
    # Ask for custom output file name
    echo ""
    print_info "Output File Configuration"
    print_info "========================"
    echo ""
    
    read -p "Custom output file for control plane (default: control-plane-1.14.0.yaml): " custom_output
    if [[ -n "${custom_output}" ]]; then
        PLATFORM_OUTPUT_FILE="${custom_output}"
        print_info "Using custom output: ${PLATFORM_OUTPUT_FILE}"
    else
        print_info "Using default output: control-plane-1.14.0.yaml"
    fi
    
    print_success "Configuration completed successfully"
}

# Interactive Helm upgrade setup
interactive_helm_upgrade() {
    echo ""
    print_info "Helm Upgrade Setup"
    print_info "=================="
    echo ""
    
    # Validate mode-specific dependencies right away (helm/jq)
    print_info "Validating Helm/jq requirements for upgrade..."
    # Set upgrade mode early so check_dependencies enforces helm/jq
    HELM_UPGRADE_MODE=true
    check_dependencies

    print_info "This mode will perform actual Helm upgrade on your cluster using 1.14.0 values.yaml file."
    echo ""
    
    echo "This will upgrade to tibco-cp-base chart (v1.14.0)"
    echo ""
    
    while [[ -z "${PLATFORM_BASE_FILE}" ]]; do
        read -p "Enter file name of 1.14.0 control plane values.yaml file: " PLATFORM_BASE_FILE
        if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
            print_error "File not found: ${PLATFORM_BASE_FILE}"
            PLATFORM_BASE_FILE=""
        fi
    done
    
    # Get cluster information
    while [[ -z "${NAMESPACE}" ]]; do
        read -p "Enter target namespace for upgrade: " NAMESPACE
    done
    
    # Get release name
    read -p "Enter control plane chart release name (default: platform-base): " input_release
    [[ -n "${input_release}" ]] && CONTROL_PLANE_RELEASE_NAME="${input_release}"
    
    # Get Helm repository name
    read -p "Enter Helm repository name (default: tibco-platform): " TP_HELM_REPO_NAME
    [[ -z "${TP_HELM_REPO_NAME}" ]] && TP_HELM_REPO_NAME="tibco-platform"
    
    print_success "Helm upgrade configuration complete"
    
    # Set mode to indicate upgrade
    HELM_UPGRADE_MODE=true
    OPERATION_MODE="file"  # We're using files for the upgrade
}

# Individual chart upgrade functions
upgrade_base_chart() {
    print_info "Upgrading ${CONTROL_PLANE_RELEASE_NAME} release to tibco-cp-base chart version ${CHART_VERSION}..."
    
    if helm upgrade "${CONTROL_PLANE_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/tibco-cp-base" \
        --version "${CHART_VERSION}" \
        --namespace "${NAMESPACE}" \
        --values "${PLATFORM_BASE_FILE}" \
        --wait --timeout=1h; then
        
        print_success "Successfully upgraded ${CONTROL_PLANE_RELEASE_NAME}"
        return 0
    else
        print_error "Failed to upgrade ${CONTROL_PLANE_RELEASE_NAME}"
        return 1
    fi
}

# Helm upgrade functionality
perform_helm_upgrade() {
    print_info "Starting Helm upgrade process"
    print_info "============================="
    
    # Validate current deployment version and state
    print_info "Validating current deployment version..."
    
    # Helper for status classification
    local FAILED_STATES="failed pending-install pending-rollback pending-upgrade superseded"
    
    # Check control plane release status and version
    if ! helm status "${CONTROL_PLANE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Control plane release '${CONTROL_PLANE_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
        return 1
    fi
    local release_status=$(helm status "${CONTROL_PLANE_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    local release_version=$(helm list -n "${NAMESPACE}" -f "^${CONTROL_PLANE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
    print_info "Control plane current status: ${release_status}, app_version: ${release_version}"
    if [[ "${release_status}" == "deployed" ]]; then
        if [[ "${release_version}" != "1.13.0" && "${release_version}" != "1.14.0" ]]; then
            print_error "Current ${CONTROL_PLANE_RELEASE_NAME} version is '${release_version}', expected '1.13.0' or '1.14.0'"
            print_error "This script supports upgrades from 1.13.0 to 1.14.0"
            return 1
        fi
        print_success "Release version validation passed: ${release_version}"
    else
        if echo " ${FAILED_STATES} " | grep -q " ${release_status} "; then
            if [[ "${release_version}" == "1.14.0" ]]; then
                echo ""
                print_warning "${CONTROL_PLANE_RELEASE_NAME} is already at app_version 1.14.0 but in '${release_status}' state."
                read -p "Do you want to retry the 1.14.0 upgrade for ${CONTROL_PLANE_RELEASE_NAME}? (yes/no): " retry_confirm
                if [[ "${retry_confirm}" != "yes" ]]; then
                    print_info "Skipping upgrade retry for ${CONTROL_PLANE_RELEASE_NAME} per user choice."
                    return 0
                fi
            else
                print_error "Upgrade blocked: ${CONTROL_PLANE_RELEASE_NAME} status is '${release_status}'. Resolve (e.g., rollback) and retry."
                return 1
            fi
        else
            print_error "Upgrade blocked: ${CONTROL_PLANE_RELEASE_NAME} status is '${release_status}'. Expected 'deployed' or a retry-able failed state."
            return 1
        fi
    fi
    
    # Update Helm repository
    print_info "Updating TP Helm charts repository..."
    helm repo update "${TP_HELM_REPO_NAME}"
    print_success "Repository updated successfully"
    
    # Upgrade control plane
    upgrade_base_chart
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Verify upgrades
    verify_helm_upgrades
}

# (Bootstrap cleanup not needed for 1.14.0 upgrade - no separate bootstrap chart)
# Verify Helm upgrades
verify_helm_upgrades() {
    print_info "Verifying Helm upgrade..."
    echo ""
    # Hard-coded expected appVersion after upgrade
    local EXPECTED_POST_APP_VERSION="1.14.0"
    
    # Check if release exists and is deployed
    if helm status "${CONTROL_PLANE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        local release_app=$(helm list -n "${NAMESPACE}" -f "^${CONTROL_PLANE_RELEASE_NAME}$" -o json | jq -r '.[0].app_version // "unknown"')
        local release_chart=$(helm list -n "${NAMESPACE}" -f "^${CONTROL_PLANE_RELEASE_NAME}$" -o json | jq -r '.[0].chart // "unknown"')
        print_success "Control plane upgraded: app_version=${release_app}, chart=${release_chart}"
        if [[ "${release_app}" != "${EXPECTED_POST_APP_VERSION}" ]]; then
            print_error "Control plane app_version (${release_app}) does not match expected ${EXPECTED_POST_APP_VERSION}"
        fi
        if [[ "${release_chart}" != *"-${CHART_VERSION}" ]]; then
            print_error "Control plane chart (${release_chart}) does not match desired version ${CHART_VERSION}"
        fi
    else
        print_error "Control plane chart upgrade failed or release not found"
        return 1
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
    
    
    # Runtime note after upgrade and checks
    print_info "NOTE: This script does NOT perform application-level or functional tests of the upgraded charts."
    print_info "It assumes all chart values are correct, performs the upgrade from 1.13.0 to 1.14.0,"
    print_info "and verifies that the pods in namespace '${NAMESPACE}' are in Running/Completed state."
    print_info "We recommend you run your own post-upgrade tests as required."

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
        echo "Dependency check failed: yq not found"
        exit 1
    fi
    
    local yq_version=$(yq --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -1)
    if [[ -n "${yq_version}" ]]; then
        if version_ge "${yq_version}" "${REQUIRED_YQ_VERSION}"; then
            print_info "yq version ${yq_version} - OK"
        else
            print_error "yq version ${yq_version} detected. Required: yq v${REQUIRED_YQ_VERSION} or higher"
            exit 1
        fi
    else
        print_error "Could not determine yq version. Required: yq v${REQUIRED_YQ_VERSION} or higher"
        exit 1
    fi
    
    # Helm/jq required only for Helm flows
    if [[ "${OPERATION_MODE}" == "helm" || "${HELM_UPGRADE_MODE}" == "true" ]]; then
        if ! command -v helm >/dev/null 2>&1; then
            print_error "helm is required for helm mode. Install from: https://helm.sh/docs/intro/install/"
            echo "Dependency check failed: helm not found"
            exit 1
        fi
        
        local helm_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+' | head -1 | sed 's/v//')
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
        
        # Check jq availability and version
        if ! command -v jq >/dev/null 2>&1; then
            print_error "jq is required for helm operations. Install with: sudo apt-get install jq or brew install jq"
            echo "Dependency check failed: jq not found"
            exit 1
        fi
        
        local jq_version=$(jq --version 2>/dev/null | sed -E 's/^[^0-9]*//' | grep -oE '^[0-9]+(\.[0-9]+){1,2}' | head -1)
        if [[ -n "${jq_version}" ]]; then
            if version_ge "${jq_version}" "${REQUIRED_JQ_VERSION}"; then
                print_info "jq version ${jq_version} - OK"
            else
                print_error "jq version ${jq_version} detected. Required: jq v${REQUIRED_JQ_VERSION} or higher"
                exit 1
            fi
        else
            print_error "Could not determine jq version. Required: jq v${REQUIRED_JQ_VERSION} or higher"
            exit 1
        fi
    fi

    # kubectl required only for post-upgrade verification (upgrade mode)
    if [[ "${HELM_UPGRADE_MODE}" == "true" ]]; then
        if ! command -v kubectl >/dev/null 2>&1; then
            print_error "kubectl is required for post-upgrade verification. Install from: https://kubernetes.io/docs/tasks/tools/"
            echo "Dependency check failed: kubectl not found"
            exit 1
        fi
    fi
}

# Extract Helm values
extract_helm_values() {
    print_info "Extracting Helm values from namespace: ${NAMESPACE}"
    
    # Ensure helm/jq are available (in case dependencies were checked before mode selection)
    command -v helm >/dev/null 2>&1 || { print_error "helm is required for Helm extraction. Install from: https://helm.sh/docs/intro/install/"; exit 1; }
    command -v jq >/dev/null 2>&1   || { print_error "jq is required for Helm extraction. Install with: sudo apt-get install jq or brew install jq"; exit 1; }
    
    # Ensure release exists before attempting version checks
    if ! helm status "${CONTROL_PLANE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Control plane release '${CONTROL_PLANE_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
        exit 1
    fi

    # Show and enforce current status before extracting values (use helm status for reliable state)
    local release_status=$(helm status "${CONTROL_PLANE_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    print_info "Control plane current status: ${release_status}"
    if [[ "${release_status}" != "deployed" ]]; then
        print_error "Cannot extract values: Control plane status is '${release_status}'. Please resolve (e.g., rollback or complete install) and try again."
        exit 1
    fi
    
    # Validate current deployed app_version is 1.13.0 before extracting values
    local release_ver="unknown"
    release_ver=$(helm list -n "${NAMESPACE}" -f "^${CONTROL_PLANE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' || echo "unknown")
    if [[ "${release_ver}" != "1.13.0" ]]; then
        print_error "${CONTROL_PLANE_RELEASE_NAME} app_version is '${release_ver}', expected 1.13.0"
        exit 1
    fi
    print_success "Pre-check passed: Control Plane Chart Version=${release_ver}"
    echo ""
    
    # Extract control plane values
    helm get values -n "${NAMESPACE}" "${CONTROL_PLANE_RELEASE_NAME}" > "${TEMP_DIR}/temp-base-raw.yaml"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to extract values from release: ${CONTROL_PLANE_RELEASE_NAME}"
        exit 1
    fi
    
    # Remove header if present and create clean file
    if head -1 "${TEMP_DIR}/temp-base-raw.yaml" | grep -q "USER-SUPPLIED VALUES"; then
        tail -n +2 "${TEMP_DIR}/temp-base-raw.yaml" > "${TEMP_DIR}/temp-base.yaml"
    else
        cp "${TEMP_DIR}/temp-base-raw.yaml" "${TEMP_DIR}/temp-base.yaml"
    fi
    [[ ! -s "${TEMP_DIR}/temp-base.yaml" ]] && echo "{}" > "${TEMP_DIR}/temp-base.yaml"
    
    PLATFORM_BASE_FILE="${TEMP_DIR}/temp-base.yaml"
    
    # Ensure files are fully written (potential timing fix)
    sync 2>/dev/null || true
    sleep 1
    
    print_success "Helm values extracted successfully"
}

# Generate output filename
generate_output_filename() {
    local base_dir=$([[ "${OPERATION_MODE}" == "helm" ]] && echo "." || dirname "${PLATFORM_BASE_FILE}")
    [[ -z "${PLATFORM_OUTPUT_FILE}" ]] && PLATFORM_OUTPUT_FILE="${base_dir}/control-plane-${DEFAULT_VERSION}.yaml"
    print_info "Output file: ${PLATFORM_OUTPUT_FILE}"
}

# Main processing function - copies control plane values for 1.14.0
process_files() {
    print_info "Processing control plane values file..."
    
    # Validate control plane file
    if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
        print_error "Control plane file not found: ${PLATFORM_BASE_FILE}"
        exit 1
    fi
    
    if [[ ! -r "${PLATFORM_BASE_FILE}" ]]; then
        print_error "Control plane file not readable: ${PLATFORM_BASE_FILE}"
        exit 1
    fi
    
    # Ensure files are ready for reading (timing fix)
    sleep 0.1
    
    # Copy control plane values file content
    local platform_base_file_content=""
    
    if [[ -f "${PLATFORM_BASE_FILE}" ]]; then
        platform_base_file_content=$(cat "${PLATFORM_BASE_FILE}" 2>/dev/null || echo "")
    fi
    
    # Copy control plane values to output file
    echo "${platform_base_file_content}" > "${PLATFORM_OUTPUT_FILE}"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create control plane output file"
        exit 1
    fi
    
    print_info "Control plane values copied to output file"
    
    # No recipe transformations needed for 1.14.0 upgrade
    tidy_yaml "${PLATFORM_OUTPUT_FILE}"

    print_success "Processing completed successfully"
    
    # Summary
    print_info "Control plane values generation summary:"
    print_info "  [+] Control plane values copied for version: ${DEFAULT_VERSION}"
    print_info "  [+] Output file ready for upgrade: ${PLATFORM_OUTPUT_FILE}"
}

# No recipe transformations needed for 1.14.0 upgrade (no recipe changes)

# Remove empty lines and trailing spaces from YAML output
tidy_yaml() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    sed -e 's/[[:space:]]\+$//' -e '/^[[:space:]]*$/d' "${f}" > "${f}.clean"
    mv "${f}.clean" "${f}"
  fi
}

# Main execution
main() {
    print_info "TIBCO Control Plane Upgrade Script - 1.13.0 to 1.14.0"
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
        # Detect current version
        local current_version="unknown"
        if command -v helm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
            current_version=$(helm list -n "${NAMESPACE}" -f "^${CONTROL_PLANE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' 2>/dev/null || echo "unknown")
        fi
        
        echo ""
        print_warning "This will perform actual Helm upgrade on your cluster!"
        print_info "Upgrade Summary:"
        print_info "  Target namespace: ${NAMESPACE}"
        print_info "  Release to upgrade: ${CONTROL_PLANE_RELEASE_NAME}"
        print_info "  From version: ${current_version}"
        print_info "  To chart: tibco-cp-base (${CHART_VERSION})"
        print_info "  Values file: ${PLATFORM_BASE_FILE}"
        print_info "  Repository: ${TP_HELM_REPO_NAME}"
        echo ""
        print_info "This upgrade will:"
        print_info "  • Keep the same release name: ${CONTROL_PLANE_RELEASE_NAME}"
        print_info "  • Update the tibco-cp-base chart to version ${CHART_VERSION}"
        print_info "  • Apply new configuration values"
        echo ""        
        read -p "Do you want to proceed with the upgrade? (yes/no): " confirm
        if [[ "${confirm}" == "yes" ]]; then
            perform_helm_upgrade
            if [[ $? -eq 0 ]]; then
                echo ""
                print_info "Helm upgrade completed successfully!"
                echo ""
            fi
            print_success "All operations completed successfully!"
            exit 0
        else
            print_info "Helm upgrade cancelled by user"
            exit 0
        fi
    else
        # Standard values generation mode
        [[ "${OPERATION_MODE}" == "helm" ]] && extract_helm_values
        
        generate_output_filename
        process_files
        
        echo ""
        print_success "Control plane values.yaml generation completed successfully!"
        print_info "Generated control plane values.yaml file for upgrade:"
        print_info "  - Control plane values: ${PLATFORM_OUTPUT_FILE}"
        echo ""
        print_info "Use this file to upgrade your release to version ${CHART_VERSION}:"
        print_info "  helm upgrade <release-name> tibco-platform/tibco-cp-base \\"
        print_info "    --version ${CHART_VERSION} \\"
        print_info "    --values ${PLATFORM_OUTPUT_FILE} \\"
        print_info "    --namespace <your-namespace>"
        echo ""
    fi
    
    print_success "All operations completed successfully!"
}

# Execute main function
main "${@}"