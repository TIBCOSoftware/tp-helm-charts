#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Tested with: GNU bash, version 5.2.21(1)-release
#
# TIBCO Control Plane Helm Values Generation Script for Platform Upgrade FROM 1.12.0 TO 1.13.0
# Generates a single merged values.yaml file for the unified tibco-cp-base chart (platform-bootstrap and platform-base are now merged into unified tibco-cp-base chart)

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
PLATFORM_OUTPUT_MERGED_FILE=""
DEFAULT_VERSION="1.13.0"
TEMP_DIR=""
OPERATION_MODE=""
NAMESPACE=""
PLATFORM_BOOTSTRAP_RELEASE_NAME="platform-bootstrap"
PLATFORM_BASE_RELEASE_NAME="platform-base"

# Enhanced mode variables
HELM_UPGRADE_MODE=false
TP_HELM_CHARTS_REPO=""
CHART_VERSION="${CHART_VERSION:-1.13.0}"

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
TIBCO Control Plane Upgrade Assistant - 1.12.0 to 1.13.0
==================================================

This script provides an interactive experience to help you upgrade your TIBCO Control Plane
from version 1.12.0 to 1.13.0.

Note: As of 1.13.0, platform-bootstrap and platform-base have been merged into the new unified chart tibco-cp-base.
This script will extract values from both existing releases and create a single merged values.yaml file.

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
  - It assumes all chart values are correct, performs the upgrade from 1.12.0 to 1.13.0
    and verifies that the pods in the target namespace are in Running/Completed state.
  - We recommend you run your own post-upgrade tests as required.
EOF
}

# Interactive mode for user input
interactive_mode() {
    print_info "TIBCO Control Plane Upgrade Script - 1.12.0 to 1.13.0"
    print_info "======================================================="
    echo ""
    print_info "Note: Platform-bootstrap and platform-base have been merged into the new unified chart tibco-cp-base."
    print_info "This script will create a single merged values.yaml file for the new tibco-cp-base chart."
    echo ""
    
    echo "Please select your operation mode:"
    echo "1) Generate 1.13.0 merged values.yaml file from current 1.12.0 setup"
    echo "2) Perform Helm upgrade using existing 1.13.0-compatible values.yaml file"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate 1.13.0 merged values.yaml file"
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
    echo "How would you like to provide your current 1.12.0 values?"
    echo "1) I have existing 1.12.0 values.yaml files (platform-bootstrap and platform-base)"
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
    
    # Ask for custom output file name
    echo ""
    print_info "Output File Configuration"
    print_info "========================"
    echo ""
    
    read -p "Custom output file for merged tibco-cp-base (default: tibco-cp-base-merged-1.13.0.yaml): " custom_merged_output
    if [[ -n "${custom_merged_output}" ]]; then
        PLATFORM_OUTPUT_MERGED_FILE="${custom_merged_output}"
        print_info "Using custom merged output: ${PLATFORM_OUTPUT_MERGED_FILE}"
    else
        print_info "Using default merged output: tibco-cp-base-merged-1.13.0.yaml"
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
        read -p "Enter Kubernetes namespace containing your deployments: " NAMESPACE
    done
    
    read -p "Current platform-bootstrap release name (default: platform-bootstrap): " input_bootstrap
    [[ -n "${input_bootstrap}" ]] && PLATFORM_BOOTSTRAP_RELEASE_NAME="${input_bootstrap}"
    
    read -p "Current platform-base release name (default: platform-base): " input_base
    [[ -n "${input_base}" ]] && PLATFORM_BASE_RELEASE_NAME="${input_base}"
    
    print_success "Helm extraction configuration set successfully"
    
    # Ask for custom output file name
    echo ""
    print_info "Output File Configuration"
    print_info "========================"
    echo ""
    
    read -p "Custom output file for merged tibco-cp-base (default: tibco-cp-base-merged-1.13.0.yaml): " custom_merged_output
    if [[ -n "${custom_merged_output}" ]]; then
        PLATFORM_OUTPUT_MERGED_FILE="${custom_merged_output}"
        print_info "Using custom merged output: ${PLATFORM_OUTPUT_MERGED_FILE}"
    else
        print_info "Using default merged output: tibco-cp-base-merged-1.13.0.yaml"
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

    print_info "This mode will perform actual Helm upgrades on your cluster using 1.13.0 values.yaml files."
    echo ""
    
    # Chart selection - now only tibco-cp-base since bootstrap is merged
    echo "This will upgrade to the unified tibco-cp-base chart (v1.13.0)"
    echo "Platform-bootstrap and platform-base have been merged into tibco-cp-base."
    echo ""
    
    while [[ -z "${PLATFORM_BASE_FILE}" ]]; do
        read -p "Enter file name of 1.13.0 tibco-cp-base values.yaml file: " PLATFORM_BASE_FILE
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
    read -p "Current platform-base release name to upgrade (default: platform-base): " input_base
    [[ -n "${input_base}" ]] && PLATFORM_BASE_RELEASE_NAME="${input_base}"
    
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
    print_info "Upgrading ${PLATFORM_BASE_RELEASE_NAME} release to tibco-cp-base chart version ${CHART_VERSION}..."
    print_info "Using --take-ownership to allow ${PLATFORM_BASE_RELEASE_NAME} release to manage resources from platform-bootstrap..."
    
    if helm upgrade "${PLATFORM_BASE_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/tibco-cp-base" \
        --version "${CHART_VERSION}" \
        --namespace "${NAMESPACE}" \
        --values "${PLATFORM_BASE_FILE}" \
        --take-ownership \
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
    
    # Validate current deployment version and state for platform-base (which will be upgraded to tibco-cp-base)
    print_info "Validating current deployment version..."
    
    # Helper for status classification
    local FAILED_STATES="failed pending-install pending-rollback pending-upgrade superseded"
    
    # Check platform-base status and version
    if ! helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Platform Base release '${PLATFORM_BASE_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
        return 1
    fi
    local base_status=$(helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    local base_version=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
    print_info "Platform Base current status: ${base_status}, app_version: ${base_version}"
    if [[ "${base_status}" == "deployed" ]]; then
        if [[ "${base_version}" != "1.12.0" && "${base_version}" != "1.13.0" ]]; then
            print_error "Current ${PLATFORM_BASE_RELEASE_NAME} version is '${base_version}', expected '1.12.0' or '1.13.0'"
            print_error "This script supports upgrades from 1.12.0/1.13.0 to 1.13.0"
            return 1
        fi
        print_success "Base version validation passed: ${base_version}"
    else
        if echo " ${FAILED_STATES} " | grep -q " ${base_status} "; then
            if [[ "${base_version}" == "1.13.0" ]]; then
                echo ""
                print_warning "${PLATFORM_BASE_RELEASE_NAME} is already at app_version 1.13.0 but in '${base_status}' state."
                read -p "Do you want to retry the 1.13.0 upgrade for ${PLATFORM_BASE_RELEASE_NAME}? (yes/no): " retry_pb
                if [[ "${retry_pb}" != "yes" ]]; then
                    print_info "Skipping upgrade retry for ${PLATFORM_BASE_RELEASE_NAME} per user choice."
                    return 0
                fi
            else
                print_error "Upgrade blocked: ${PLATFORM_BASE_RELEASE_NAME} status is '${base_status}'. Resolve (e.g., rollback) and retry."
                return 1
            fi
        else
            print_error "Upgrade blocked: ${PLATFORM_BASE_RELEASE_NAME} status is '${base_status}'. Expected 'deployed' or a retry-able failed state."
            return 1
        fi
    fi
    
    # Update Helm repository
    print_info "Updating TP Helm charts repository..."
    helm repo update "${TP_HELM_REPO_NAME}"
    print_success "Repository updated successfully"
    
    # Upgrade platform-base
    upgrade_base_chart
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Verify upgrades
    verify_helm_upgrades
}

# Helm upgrade functionality
perform_bootstrap_cleanup() {
    print_info "Starting platform-bootstrap resource cleanup"
    print_info "==========================================="
    print_warning "We don't want to uninstall the platform-bootstrap release using 'helm uninstall',"
    print_warning "as this will delete resources still managed by the ${PLATFORM_BASE_RELEASE_NAME} release after the upgrade."
    print_warning "Instead, we will only delete the platform-bootstrap Helm secrets and clean up any orphaned resources."
    echo ""
    
    local cleanup_failed=false
    
    # Clean up roles and rolebindings
    print_info "Cleaning up roles and rolebindings..."
    if kubectl delete role,rolebinding -n "${NAMESPACE}" -l app.kubernetes.io/instance=platform-bootstrap 2>/dev/null; then
        print_success "Roles and rolebindings cleaned up successfully"
    else
        print_warning "No roles/rolebindings found or failed to delete (this may be expected)"
    fi
    
    # Clean up deployments and HPAs
    print_info "Cleaning up orphaned deployments and HPAs..."
    local resources_to_delete="deployment/tp-cp-hybrid-proxy deployment/tp-cp-resource-set-operator deployment/tp-cp-router deployment/otel-services hpa/tp-cp-hybrid-proxy hpa/tp-cp-router hpa/otel-services"
    if kubectl delete -n "${NAMESPACE}" ${resources_to_delete} 2>/dev/null; then
        print_success "Orphaned deployments and HPAs cleaned up successfully"
    else
        print_warning "Some resources not found or failed to delete (this may be expected if already managed by ${PLATFORM_BASE_RELEASE_NAME} release)"
    fi
    
    # Clean up Helm secrets
    print_info "Cleaning up platform-bootstrap Helm secrets..."
    if kubectl delete secret -n "${NAMESPACE}" -l "owner=helm,name=${PLATFORM_BOOTSTRAP_RELEASE_NAME}" 2>/dev/null; then
        print_success "Platform-bootstrap Helm secrets cleaned up successfully"
    else
        print_warning "No platform-bootstrap Helm secrets found or failed to delete"
        cleanup_failed=true
    fi
    
    if [[ "${cleanup_failed}" == "false" ]]; then
        print_success "Platform-bootstrap cleanup completed successfully"
        return 0
    else
        print_warning "Platform-bootstrap cleanup completed with some warnings"
        return 0  # Return success since warnings are acceptable
    fi
}
# Verify Helm upgrades
verify_helm_upgrades() {
    print_info "Verifying Helm upgrades..."
    echo ""
    # Hard-coded expected appVersion after upgrade
    local EXPECTED_POST_APP_VERSION="1.13.0"
    
    # Check if release exists and is deployed
    if helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        local pb_app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json | jq -r '.[0].app_version // "unknown"')
        local pb_chart=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json | jq -r '.[0].chart // "unknown"')
        print_success "Platform Base upgraded: app_version=${pb_app}, chart=${pb_chart}"
        if [[ "${pb_app}" != "${EXPECTED_POST_APP_VERSION}" ]]; then
            print_error "Platform Base app_version (${pb_app}) does not match expected ${EXPECTED_POST_APP_VERSION}"
        fi
        if [[ "${pb_chart}" != *"-${CHART_VERSION}" ]]; then
            print_error "Platform Base chart (${pb_chart}) does not match desired version ${CHART_VERSION}"
        fi
        
        print_info "IMPORTANT: platform-bootstrap release is still installed but inactive."
        print_info "This is intentional to prevent resource deletion."
        print_info "The ${PLATFORM_BASE_RELEASE_NAME} release now manages all resources."
        
    else
        print_error "Platform Base chart upgrade failed or release not found"
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
    print_info "It assumes all chart values are correct, performs the upgrade from 1.12.0 to 1.13.0,"
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
    
    # Ensure releases exist before attempting version checks
    if ! helm status "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Platform Bootstrap release '${PLATFORM_BOOTSTRAP_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
        exit 1
    fi
    if ! helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Platform Base release '${PLATFORM_BASE_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
        exit 1
    fi

    # Show and enforce current status before extracting values (use helm status for reliable state)
    local bs_status=$(helm status "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    local base_status=$(helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    print_info "Platform Bootstrap current status: ${bs_status}"
    print_info "Platform Base current status: ${base_status}"
    if [[ "${bs_status}" != "deployed" ]]; then
        print_error "Cannot extract values: Platform Bootstrap status is '${bs_status}'. Please resolve (e.g., rollback or complete install) and try again."
        exit 1
    fi
    if [[ "${base_status}" != "deployed" ]]; then
        print_error "Cannot extract values: Platform Base status is '${base_status}'. Please resolve (e.g., rollback or complete install) and try again."
        exit 1
    fi
    
    # Validate current deployed app_version is 1.12.0 for both releases before extracting values
    local bs_ver="unknown"; local base_ver="unknown"
    bs_ver=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' || echo "unknown")
    base_ver=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' || echo "unknown")
    if [[ "${bs_ver}" != "1.12.0" ]]; then
        print_error "${PLATFORM_BOOTSTRAP_RELEASE_NAME} app_version is '${bs_ver}', expected 1.12.0"
        exit 1
    fi
    if [[ "${base_ver}" != "1.12.0" ]]; then
        print_error "${PLATFORM_BASE_RELEASE_NAME} app_version is '${base_ver}', expected 1.12.0"
        exit 1
    fi
    print_success "Pre-check passed: Platform Bootstrap Chart Version=${bs_ver}, Platform Base Chart Version=${base_ver}"
    echo ""
    
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

# Generate output filename
generate_output_filename() {
    local base_dir=$([[ "${OPERATION_MODE}" == "helm" ]] && echo "." || dirname "${PLATFORM_BASE_FILE}")
    [[ -z "${PLATFORM_OUTPUT_MERGED_FILE}" ]] && PLATFORM_OUTPUT_MERGED_FILE="${base_dir}/tibco-cp-base-merged-${DEFAULT_VERSION}.yaml"
    print_info "Output file: ${PLATFORM_OUTPUT_MERGED_FILE}"
}

# Main processing function - merges platform-bootstrap and platform-base values into a single tibco-cp-base file
process_files() {
    print_info "Processing files for merged tibco-cp-base values generation..."
    
    # Validate bootstrap file
    if [[ ! -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        print_error "Bootstrap file not found: ${PLATFORM_BOOTSTRAP_FILE}"
        exit 1
    fi
    
    if [[ ! -r "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        print_error "Bootstrap file not readable: ${PLATFORM_BOOTSTRAP_FILE}"
        exit 1
    fi
    
    # Validate base file
    if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
        print_error "Base file not found: ${PLATFORM_BASE_FILE}"
        exit 1
    fi
    
    if [[ ! -r "${PLATFORM_BASE_FILE}" ]]; then
        print_error "Base file not readable: ${PLATFORM_BASE_FILE}"
        exit 1
    fi
    
    # Ensure files are ready for reading (timing fix)
    sleep 0.1
    
    # Copy entire file content to avoid race condition with file deletion
    local platform_bootstrap_file_content=""
    local platform_base_file_content=""
    
    if [[ -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
        platform_bootstrap_file_content=$(cat "${PLATFORM_BOOTSTRAP_FILE}" 2>/dev/null || echo "")
    fi
    
    if [[ -f "${PLATFORM_BASE_FILE}" ]]; then
        platform_base_file_content=$(cat "${PLATFORM_BASE_FILE}" 2>/dev/null || echo "")
    fi
    
    # Start with platform-base as the foundation for tibco-cp-base
    echo "${platform_base_file_content}" > "${PLATFORM_OUTPUT_MERGED_FILE}"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create merged tibco-cp-base file"
        exit 1
    fi
    
    print_info "Base platform-base content copied to merged tibco-cp-base file"
    
    # Process platform-bootstrap content and merge sections
    local bootstrap_global_content=""
    
    # Extract and merge global section from bootstrap
    if [[ -n "${platform_bootstrap_file_content}" ]]; then
        bootstrap_global_content=$(echo "${platform_bootstrap_file_content}" | yq eval '.global' - 2>/dev/null || echo "null")
        if [[ "${bootstrap_global_content}" != "null" ]]; then
            print_info "Found global section in bootstrap - merging with base global section"
            # Save bootstrap global to temp file and merge
            echo "global:" > "${TEMP_DIR}/bootstrap-global.yaml"
            echo "${bootstrap_global_content}" | sed 's/^/  /' >> "${TEMP_DIR}/bootstrap-global.yaml"
            
            # Merge global sections with base taking precedence for conflicts
            yq eval-all 'select(fileIndex == 1) * select(fileIndex == 0)' "${TEMP_DIR}/bootstrap-global.yaml" "${PLATFORM_OUTPUT_MERGED_FILE}" > "${PLATFORM_OUTPUT_MERGED_FILE}.tmp"
            if [[ $? -eq 0 ]]; then
                mv "${PLATFORM_OUTPUT_MERGED_FILE}.tmp" "${PLATFORM_OUTPUT_MERGED_FILE}"
                print_info "Global sections merged successfully"
            else
                rm -f "${PLATFORM_OUTPUT_MERGED_FILE}.tmp"
                print_warning "Failed to merge global sections - keeping base global section only"
            fi
        fi
    fi
    
    # Merge other top-level sections from bootstrap (excluding global)
    if [[ -n "${platform_bootstrap_file_content}" ]]; then
        # Get all top-level keys from bootstrap except global
        local bootstrap_keys=$(echo "${platform_bootstrap_file_content}" | yq eval 'keys | .[]' - 2>/dev/null | grep -v "^global$" || true)
        
        if [[ -n "${bootstrap_keys}" ]]; then
            print_info "Found additional sections in bootstrap to merge: $(echo "${bootstrap_keys}" | tr '\n' ' ')"
            
            # Create a temporary file with bootstrap sections excluding global
            echo "${platform_bootstrap_file_content}" | yq eval 'del(.global)' - > "${TEMP_DIR}/bootstrap-other.yaml"
            
            # Merge with merged file, bootstrap takes precedence for new sections
            yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "${PLATFORM_OUTPUT_MERGED_FILE}" "${TEMP_DIR}/bootstrap-other.yaml" > "${PLATFORM_OUTPUT_MERGED_FILE}.tmp"
            if [[ $? -eq 0 ]]; then
                mv "${PLATFORM_OUTPUT_MERGED_FILE}.tmp" "${PLATFORM_OUTPUT_MERGED_FILE}"
                print_info "Additional bootstrap sections merged successfully"
            else
                rm -f "${PLATFORM_OUTPUT_MERGED_FILE}.tmp"
                print_warning "Failed to merge additional bootstrap sections - keeping existing sections"
            fi
        fi
    fi
    
    transform_recipe_sections "${PLATFORM_OUTPUT_MERGED_FILE}"
    tidy_yaml "${PLATFORM_OUTPUT_MERGED_FILE}"

    print_success "Processing completed successfully"
    
    # Summary
    print_info "Merged tibco-cp-base values generation summary:"
    print_info "  [+] Base platform-base content copied as foundation for tibco-cp-base"
    if [[ -n "${bootstrap_global_content}" && "${bootstrap_global_content}" != "null" ]]; then
        print_info "  [+] Bootstrap global section merged with base global"
    fi
    if [[ -n "${bootstrap_keys}" ]]; then
        print_info "  [+] Additional bootstrap sections merged: $(echo "${bootstrap_keys}" | tr '\n' ' ')"
    fi
    print_info "  [+] Generated merged tibco-cp-base file - version: ${DEFAULT_VERSION}"
}

# Transform recipe sections per 1.13 combined chart rules
transform_recipe_sections() {
  local out_file="$1"
  if yq eval 'has("tp-cp-recipes")' "${out_file}" | grep -q true; then
    print_info "Transforming tp-cp-recipes into component-specific sections"
    # Ensure oauth2proxy lives under dp-oauth2proxy-recipes (and not under tp-cp-configuration)
    if [[ $(yq eval '."tp-cp-configuration".capabilities.oauth2proxy // "null"' "${out_file}") != "null" ]]; then
      yq eval -i '."dp-oauth2proxy-recipes".capabilities.oauth2proxy = ."tp-cp-configuration".capabilities.oauth2proxy' "${out_file}"
      yq eval -i 'del(."tp-cp-configuration".capabilities.oauth2proxy)' "${out_file}"
    fi
    # dp-oauth2proxy-recipes (from recipes) -> dp-oauth2proxy-recipes at root
    if [[ $(yq eval '."tp-cp-recipes"."dp-oauth2proxy-recipes".capabilities.oauth2proxy // "null"' "${out_file}") != "null" ]]; then
      yq eval -i '."dp-oauth2proxy-recipes".capabilities.oauth2proxy = ."tp-cp-recipes"."dp-oauth2proxy-recipes".capabilities.oauth2proxy' "${out_file}"
    fi

    # tp-cp-infra-recipes.capabilities.cpproxy -> tp-cp-configuration.capabilities.cpproxy
    if [[ $(yq eval '."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.cpproxy // "null"' "${out_file}") != "null" ]]; then
      yq eval -i '."tp-cp-configuration".capabilities.cpproxy = ."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.cpproxy' "${out_file}"
    fi

    # tp-cp-infra-recipes.capabilities.integrationcore -> tp-cp-configuration.capabilities.integrationcore
    if [[ $(yq eval '."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.integrationcore // "null"' "${out_file}") != "null" ]]; then
      yq eval -i '."tp-cp-configuration".capabilities.integrationcore = ."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.integrationcore' "${out_file}"
    fi

    # tp-cp-infra-recipes.capabilities.o11y -> tp-cp-o11y.capabilities.o11y
    if [[ $(yq eval '."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.o11y // "null"' "${out_file}") != "null" ]]; then
      yq eval -i '."tp-cp-o11y".capabilities.o11y = ."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.o11y' "${out_file}"
    fi

    # tp-cp-infra-recipes.capabilities.monitorAgent -> tp-cp-core-finops.monitoring-service.capabilities.monitorAgent
    if [[ $(yq eval '."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.monitorAgent // "null"' "${out_file}") != "null" ]]; then
      yq eval -i '."tp-cp-core-finops"."monitoring-service".capabilities.monitorAgent = ."tp-cp-recipes"."tp-cp-infra-recipes".capabilities.monitorAgent' "${out_file}"
    fi

    # Do NOT carry apimanager into the transformed recipe (explicitly remove if exists)
    yq eval -i 'del(."tp-cp-core-finops".capabilities.apimanager)' "${out_file}"
    # Clean up empty capabilities node under tp-cp-core-finops if present
    if [[ $(yq eval '."tp-cp-core-finops".capabilities // "null"' "${out_file}") == "{}" ]]; then
      yq eval -i 'del(."tp-cp-core-finops".capabilities)' "${out_file}"
    fi

    # Remove entire tp-cp-recipes and tp-cp-hawk-console-recipes
    yq eval -i 'del(."tp-cp-recipes")' "${out_file}"
  fi

  # Cleanup: remove deprecated/disabled top-level sections if present
  yq eval -i 'del(."tp-cp-msg-contrib")' "${out_file}"
  yq eval -i 'del(."tp-cp-msg-recipes")' "${out_file}"
  yq eval -i 'del(."tp-cp-tibcohub-contrib")' "${out_file}"
  yq eval -i 'del(."tp-cp-integration")' "${out_file}"
  yq eval -i 'del(."tp-cp-hawk")' "${out_file}"
  yq eval -i 'del(."tp-cp-hawk-console-recipes")' "${out_file}"
  yq eval -i 'del(."dp-oauth2proxy-recipes")' "${out_file}"

}

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
    print_info "TIBCO Control Plane Upgrade Script - 1.12.0 to 1.13.0"
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
        # Detect current version to show appropriate source chart
        local current_version="unknown"
        if command -v helm >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
            current_version=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' 2>/dev/null || echo "unknown")
        fi
        local from_chart="platform-base"
        if [[ "${current_version}" == "1.13.0" ]]; then
            from_chart="tibco-cp-base"
        fi
        
        echo ""
        print_warning "This will perform actual Helm upgrades on your cluster!"
        print_info "Upgrade Summary:"
        print_info "  Target namespace: ${NAMESPACE}"
        print_info "  Release to upgrade: ${PLATFORM_BASE_RELEASE_NAME}"
        print_info "  From chart: ${from_chart}"
        print_info "  To chart: tibco-cp-base (${CHART_VERSION})"
        print_info "  Values file: ${PLATFORM_BASE_FILE}"
        print_info "  Repository: ${TP_HELM_REPO_NAME}"
        echo ""
        print_info "This upgrade will:"
        print_info "  • Keep the same release name: ${PLATFORM_BASE_RELEASE_NAME}"
        if [[ "${current_version}" == "1.12.0" ]]; then
            print_info "  • Switch to the unified tibco-cp-base chart"
            print_info "  • Take ownership of platform-bootstrap resources"
            print_info "  • Leave platform-bootstrap release inactive (for safety)"
        else
            print_info "  • Update the tibco-cp-base chart to version ${CHART_VERSION}"
            print_info "  • Apply new configuration values"
        fi
        echo ""        
        read -p "Do you want to proceed with the upgrade? (yes/no): " confirm
        if [[ "${confirm}" == "yes" ]]; then
            perform_helm_upgrade
            if [[ $? -eq 0 ]]; then
                echo ""
                print_info "Helm upgrade completed successfully!"
                echo ""
                print_info "Bootstrap Resource Cleanup"
                print_info "========================="
                print_info "Upgrade completed! Your ${PLATFORM_BASE_RELEASE_NAME} release now uses the unified tibco-cp-base chart."
                echo ""
                print_warning "IMPORTANT: The platform-bootstrap release is still present but inactive."
                print_warning "This is intentional to prevent accidental resource deletion."
                echo ""
                print_info "Recommended cleanup - you should remove orphaned bootstrap resources:"
                print_info "  ✓ Delete platform-bootstrap Helm metadata (secrets)"
                print_info "  ✓ Remove orphaned deployments and HPAs no longer managed"
                print_info "  ✓ Clean up orphaned RBAC resources (roles/rolebindings)"
                echo ""
                print_info "Note: This cleanup is recommended to avoid resource conflicts and can be done now or later."
                echo ""
                read -p "Do you want to clean up platform-bootstrap resources now? (yes/no): " cleanup_confirm
                if [[ "${cleanup_confirm}" == "yes" ]]; then
                    perform_bootstrap_cleanup
                    if [[ $? -eq 0 ]]; then
                        print_success "Bootstrap cleanup completed successfully!"
                    else
                        print_error "Bootstrap cleanup encountered some issues. Please check the output above."
                    fi
                else
                    print_info "Bootstrap cleanup skipped - this is safe but not recommended."
                    print_info "The platform-bootstrap release will remain inactive but should be cleaned up to avoid potential conflicts."
                    echo ""
                    print_info "If you want to clean up later, use these commands:"
                    print_info "  # Remove bootstrap Helm metadata:"
                    print_info "  kubectl delete secret -n ${NAMESPACE} -l \"owner=helm,name=${PLATFORM_BOOTSTRAP_RELEASE_NAME}\""
                    echo ""
                    print_info "  # Remove orphaned resources (only if not managed by ${PLATFORM_BASE_RELEASE_NAME}):"
                    print_info "  kubectl delete -n ${NAMESPACE} deployment/tp-cp-hybrid-proxy deployment/tp-cp-resource-set-operator deployment/tp-cp-router deployment/otel-services"
                    print_info "  kubectl delete -n ${NAMESPACE} hpa/tp-cp-hybrid-proxy hpa/tp-cp-router hpa/otel-services"
                    print_info "  kubectl delete role,rolebinding -n ${NAMESPACE} -l app.kubernetes.io/instance=platform-bootstrap"
                fi
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
        print_success "Merged values.yaml generation completed successfully!"
        print_info "Generated merged values.yaml file for upgrade:"
        print_info "  - tibco-cp-base (merged): ${PLATFORM_OUTPUT_MERGED_FILE}"
        echo ""
        print_info "Use this file to upgrade your release to tibco-cp-base 1.13.0:"
        print_info "  helm upgrade <release-name> tibco-platform/tibco-cp-base \\"
        print_info "    --version ${CHART_VERSION} \\"
        print_info "    --values ${PLATFORM_OUTPUT_MERGED_FILE} \\"
        print_info "    --take-ownership \\"
        print_info "    --namespace <your-namespace>"
        echo ""
        print_warning "IMPORTANT NOTE: After upgrading to the unified tibco-cp-base chart,"
        print_warning "Do NOT uninstall the platform-bootstrap release using 'helm uninstall', as this will delete resources still managed by ${PLATFORM_BASE_RELEASE_NAME} release after the upgrade."
        print_warning "Instead, only delete the platform-bootstrap Helm secrets and clean up the orphaned resources as shown below."
        print_warning "  kubectl delete secret -n <your-namespace> -l \"owner=helm,name=${PLATFORM_BOOTSTRAP_RELEASE_NAME}\""
        print_warning "  kubectl delete -n <your-namespace> deployment/tp-cp-hybrid-proxy deployment/tp-cp-resource-set-operator deployment/tp-cp-router deployment/otel-services hpa/tp-cp-hybrid-proxy hpa/tp-cp-router hpa/otel-services"
        print_warning "  kubectl delete role,rolebinding -n <your-namespace> -l app.kubernetes.io/instance=platform-bootstrap"
        echo ""
    fi
    
    print_success "All operations completed successfully!"
}

# Execute main function
main "${@}"