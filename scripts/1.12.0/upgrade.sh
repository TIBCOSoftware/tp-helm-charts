#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Tested on: Ubuntu 24.04 LTS; Bash 5.2.21
#
# TIBCO Control Plane Helm Values Generation Script for Platform Upgrade (1.11.0 → 1.12.0)
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
TEMP_DIR=""
OPERATION_MODE=""
NAMESPACE=""
PLATFORM_BOOTSTRAP_RELEASE_NAME="platform-bootstrap"
PLATFORM_BASE_RELEASE_NAME="platform-base"

# Enhanced mode variables
HELM_UPGRADE_MODE=false
TP_HELM_CHARTS_REPO=""
PLATFORM_BOOTSTRAP_CHART_VERSION="${PLATFORM_BOOTSTRAP_CHART_VERSION:-1.12.0}"
PLATFORM_BASE_CHART_VERSION="${PLATFORM_BASE_CHART_VERSION:-1.12.0}"

# Upgrade selection variables
UPGRADE_BOOTSTRAP=false
UPGRADE_BASE=false

# Control flags
UPGRADE_MINOR_VERSIONS="${UPGRADE_MINOR_VERSIONS:-false}"

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} ${1}"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} ${1}"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} ${1}"; }
print_error() { echo -e "${RED}[ERROR]${NC} ${1}" >&2; }

# Usage help
show_usage() {
    cat << EOF
TIBCO Control Plane Upgrade Assistant - 1.11.0 to 1.12.0
==================================================

This script provides an interactive experience to help you upgrade your TIBCO Control Plane
from version 1.11.0 to 1.12.0.

USAGE:
  Simply run: $0

The script will guide you through:
1. Choosing between values generation or Helm upgrade
2. Configuring input sources (files or Helm extraction)
3. Setting custom output file names (optional)
4. Performing the upgrade operations

Prerequisites:
  - yq (YAML processor) v4.0+ (required)
  - Bash version 4.0+ (required)
  - jq (JSON processor) v1.6+ (required only for Helm extraction/upgrade/validation)
  - Helm v3.17+ (required only for Helm extraction/upgrade/validation)
  - kubectl (required only for post-upgrade verification)

No command-line arguments needed - everything is handled interactively!

NOTE:
  - This script does NOT perform application-level or functional tests of the upgraded charts.
  - It assumes all chart values are correct, performs the upgrade from 1.11.0 to 1.12.0
    and verifies that the pods in the target namespace are in Running/Completed state.
  - We recommend you run your own post-upgrade tests as required.
EOF
}

# Interactive mode for user input
interactive_mode() {
    print_info "TIBCO Control Plane Upgrade Script - 1.11.0 to 1.12.0"
    print_info "=================================================="
    echo ""
    
    echo "Please select your operation mode:"
    echo "1) Generate 1.12.0 values.yaml files from current 1.11.0 setup"
    echo "2) Perform Helm upgrade using existing 1.12.0 compatible values.yaml files"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate 1.12.0 values.yaml files"
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
    echo "How would you like to provide your current 1.11.0 values?"
    echo "1) I have existing 1.11.0 values.yaml files"
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
    
    read -p "Custom output file for platform-base (default: platform-base-1.12.0.yaml): " custom_base_output
    if [[ -n "${custom_base_output}" ]]; then
        PLATFORM_OUTPUT_BASE_FILE="${custom_base_output}"
        print_info "Using custom platform-base output: ${PLATFORM_OUTPUT_BASE_FILE}"
    else
        print_info "Using default platform-base output: platform-base-1.12.0.yaml"
    fi
    
    read -p "Custom output file for platform-bootstrap (default: platform-bootstrap-1.12.0.yaml): " custom_bootstrap_output
    if [[ -n "${custom_bootstrap_output}" ]]; then
        PLATFORM_OUTPUT_BOOTSTRAP_FILE="${custom_bootstrap_output}"
        print_info "Using custom platform-bootstrap output: ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    else
        print_info "Using default platform-bootstrap output: platform-bootstrap-1.12.0.yaml"
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
    
    read -p "Custom output file for platform-base (default: platform-base-1.12.0.yaml): " custom_base_output
    if [[ -n "${custom_base_output}" ]]; then
        PLATFORM_OUTPUT_BASE_FILE="${custom_base_output}"
        print_info "Using custom platform-base output: ${PLATFORM_OUTPUT_BASE_FILE}"
    else
        print_info "Using default platform-base output: platform-base-1.12.0.yaml"
    fi
    
    read -p "Custom output file for platform-bootstrap (default: platform-bootstrap-1.12.0.yaml): " custom_bootstrap_output
    if [[ -n "${custom_bootstrap_output}" ]]; then
        PLATFORM_OUTPUT_BOOTSTRAP_FILE="${custom_bootstrap_output}"
        print_info "Using custom platform-bootstrap output: ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    else
        print_info "Using default platform-bootstrap output: platform-bootstrap-1.12.0.yaml"
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
    
    print_info "This mode will perform actual Helm upgrades on your cluster using 1.12.0 values.yaml files."
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
            read -p "Enter file name of 1.12.0 platform-bootstrap values.yaml file: " PLATFORM_BOOTSTRAP_FILE
            if [[ ! -f "${PLATFORM_BOOTSTRAP_FILE}" ]]; then
                print_error "File not found: ${PLATFORM_BOOTSTRAP_FILE}"
                PLATFORM_BOOTSTRAP_FILE=""
            fi
        done
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        while [[ -z "${PLATFORM_BASE_FILE}" ]]; do
            read -p "Enter file name of 1.12.0 platform-base values.yaml file: " PLATFORM_BASE_FILE
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
    read -p "Enter Helm repository name (default: tp-helm-charts): " TP_HELM_REPO_NAME
    [[ -z "${TP_HELM_REPO_NAME}" ]] && TP_HELM_REPO_NAME="tp-helm-charts"
    
    print_success "Helm upgrade configuration complete"
    
    # Set mode to indicate upgrade
    HELM_UPGRADE_MODE=true
    OPERATION_MODE="file"  # We're using files for the upgrade
}

# Individual chart upgrade functions
upgrade_bootstrap_chart() {
    print_info "Upgrading ${PLATFORM_BOOTSTRAP_RELEASE_NAME} to version ${PLATFORM_BOOTSTRAP_CHART_VERSION}..."
    if helm upgrade "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/platform-bootstrap" \
        --version "${PLATFORM_BOOTSTRAP_CHART_VERSION}" \
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
    print_info "Upgrading ${PLATFORM_BASE_RELEASE_NAME} to version ${PLATFORM_BASE_CHART_VERSION}..."
    if helm upgrade "${PLATFORM_BASE_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/platform-base" \
        --version "${PLATFORM_BASE_CHART_VERSION}" \
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
    
    # Show environment variable status only when enabled
    if [[ "${UPGRADE_MINOR_VERSIONS}" == "true" ]]; then
        print_info "Environment: UPGRADE_MINOR_VERSIONS=true (1.12.x minor version upgrades enabled with confirmation prompts)"
    fi
    
    # Validate current deployment versions and states for selected charts
    print_info "Validating current deployment versions..."
    
    # Helper for status classification
    local FAILED_STATES="failed pending-install pending-rollback pending-upgrade superseded"
    
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        if ! helm status "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            print_error "Platform Bootstrap release '${PLATFORM_BOOTSTRAP_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
            return 1
        fi
        local bs_status=$(helm status "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
        local bs_version=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
        print_info "Platform Bootstrap current status: ${bs_status}, app_version: ${bs_version}"
        if [[ "${bs_status}" == "deployed" ]]; then
            if [[ "${bs_version}" =~ ^1\.12\. ]]; then
                if [[ "${UPGRADE_MINOR_VERSIONS}" == "true" ]]; then
                    echo ""
                    print_warning "${PLATFORM_BOOTSTRAP_RELEASE_NAME} is already deployed at version ${bs_version}"
                    print_warning "You are attempting to upgrade/re-deploy to version ${PLATFORM_BOOTSTRAP_CHART_VERSION}"
                    print_warning "This will perform a minor version upgrade within the 1.12.x series"
                    read -p "Do you want to proceed with the 1.12.x minor version upgrade? (yes/no): " proceed_bs
                    if [[ "${proceed_bs}" != "yes" ]]; then
                        print_info "Skipping minor version upgrade for ${PLATFORM_BOOTSTRAP_RELEASE_NAME} per user choice."
                        UPGRADE_BOOTSTRAP=false
                    fi
                else
                    print_error "Current ${PLATFORM_BOOTSTRAP_RELEASE_NAME} version is '${bs_version}', expected '1.11.0'"
                    print_error "This script only supports upgrades from 1.11.0 to 1.12.0"
                    return 1
                fi
            elif [[ "${bs_version}" != "1.11.0" ]]; then
                print_error "Current ${PLATFORM_BOOTSTRAP_RELEASE_NAME} version is '${bs_version}', expected '1.11.0'"
                print_error "This script only supports upgrades from 1.11.0 to 1.12.0"
                return 1
            else
                print_success "Bootstrap version validation passed: ${bs_version}"
            fi
        else
            # Non-deployed state
            if echo " ${FAILED_STATES} " | grep -q " ${bs_status} "; then
                if [[ "${bs_version}" == "1.12.0" ]]; then
                    echo ""
                    print_warning "${PLATFORM_BOOTSTRAP_RELEASE_NAME} is already at app_version 1.12.0 but in '${bs_status}' state."
                    read -p "Do you want to retry the 1.12.0 upgrade for ${PLATFORM_BOOTSTRAP_RELEASE_NAME}? (yes/no): " retry_bs
                    if [[ "${retry_bs}" != "yes" ]]; then
                        print_info "Skipping upgrade retry for ${PLATFORM_BOOTSTRAP_RELEASE_NAME} per user choice."
                        UPGRADE_BOOTSTRAP=false
                    fi
                else
                    print_error "Upgrade blocked: ${PLATFORM_BOOTSTRAP_RELEASE_NAME} status is '${bs_status}'. Resolve (e.g., rollback) and retry."
                    return 1
                fi
            else
                print_error "Upgrade blocked: ${PLATFORM_BOOTSTRAP_RELEASE_NAME} status is '${bs_status}'. Expected 'deployed' or a retry-able failed state."
                return 1
            fi
        fi
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        if ! helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            print_error "Platform Base release '${PLATFORM_BASE_RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
            return 1
        fi
        local base_status=$(helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
        local base_version=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
        print_info "Platform Base current status: ${base_status}, app_version: ${base_version}"
        if [[ "${base_status}" == "deployed" ]]; then
            if [[ "${base_version}" =~ ^1\.12\. ]]; then
                if [[ "${UPGRADE_MINOR_VERSIONS}" == "true" ]]; then
                    echo ""
                    print_warning "${PLATFORM_BASE_RELEASE_NAME} is already deployed at version ${base_version}"
                    print_warning "You are attempting to upgrade/re-deploy to version ${PLATFORM_BASE_CHART_VERSION}"
                    print_warning "This will perform a minor version upgrade within the 1.12.x series"
                    read -p "Do you want to proceed with the 1.12.x minor version upgrade? (yes/no): " proceed_pb
                    if [[ "${proceed_pb}" != "yes" ]]; then
                        print_info "Skipping minor version upgrade for ${PLATFORM_BASE_RELEASE_NAME} per user choice."
                        UPGRADE_BASE=false
                    fi
                else
                    print_error "Current ${PLATFORM_BASE_RELEASE_NAME} version is '${base_version}', expected '1.11.0'"
                    print_error "This script only supports upgrades from 1.11.0 to 1.12.0"
                    print_error "To enable 1.12.x minor version upgrades, set UPGRADE_MINOR_VERSIONS=true"
                    return 1
                fi
            elif [[ "${base_version}" != "1.11.0" ]]; then
                print_error "Current ${PLATFORM_BASE_RELEASE_NAME} version is '${base_version}', expected '1.11.0'"
                print_error "This script only supports upgrades from 1.11.0 to 1.12.0"
                return 1
            else
                print_success "Base version validation passed: ${base_version}"
            fi
        else
            if echo " ${FAILED_STATES} " | grep -q " ${base_status} "; then
                if [[ "${base_version}" == "1.12.0" ]]; then
                    echo ""
                    print_warning "${PLATFORM_BASE_RELEASE_NAME} is already at app_version 1.12.0 but in '${base_status}' state."
                    read -p "Do you want to retry the 1.12.0 upgrade for ${PLATFORM_BASE_RELEASE_NAME}? (yes/no): " retry_pb
                    if [[ "${retry_pb}" != "yes" ]]; then
                        print_info "Skipping upgrade retry for ${PLATFORM_BASE_RELEASE_NAME} per user choice."
                        UPGRADE_BASE=false
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
    # Hard-coded expected appVersion after upgrade
    local EXPECTED_POST_APP_VERSION="1.12.0"
    
    # Check if releases exist and are deployed (only for selected charts)
    if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
        if helm status "${PLATFORM_BOOTSTRAP_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            local bs_app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE_NAME}$" -o json | jq -r '.[0].app_version // "unknown"')
            local bs_chart=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE_NAME}$" -o json | jq -r '.[0].chart // "unknown"')
            print_success "Platform Bootstrap upgraded: app_version=${bs_app}, chart=${bs_chart}"
            if [[ "${bs_app}" != "${EXPECTED_POST_APP_VERSION}" ]]; then
                print_error "Platform Bootstrap app_version (${bs_app}) does not match expected ${EXPECTED_POST_APP_VERSION}"
            fi
            if [[ "${bs_chart}" != *"-${PLATFORM_BOOTSTRAP_CHART_VERSION}" ]]; then
                print_error "Platform Bootstrap chart (${bs_chart}) does not match desired version ${PLATFORM_BOOTSTRAP_CHART_VERSION}"
            fi
        else
            print_error "Platform Bootstrap chart upgrade failed or release not found"
        fi
    fi
    
    if [[ "${UPGRADE_BASE}" == "true" ]]; then
        if helm status "${PLATFORM_BASE_RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
            local pb_app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json | jq -r '.[0].app_version // "unknown"')
            local pb_chart=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json | jq -r '.[0].chart // "unknown"')
            print_success "Platform Base upgraded: app_version=${pb_app}, chart=${pb_chart}"
            if [[ "${pb_app}" != "${EXPECTED_POST_APP_VERSION}" ]]; then
                print_error "Platform Base app_version (${pb_app}) does not match expected ${EXPECTED_POST_APP_VERSION}"
            fi
            if [[ "${pb_chart}" != *"-${PLATFORM_BASE_CHART_VERSION}" ]]; then
                print_error "Platform Base chart (${pb_chart}) does not match desired version ${PLATFORM_BASE_CHART_VERSION}"
            fi
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
    
    # Runtime note after upgrade and checks
    print_info "NOTE: This script does NOT perform application-level or functional tests of the upgraded charts."
    print_info "It assumes all chart values are correct, performs the configured chart upgrades,"
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
    
    local yq_version=$(yq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
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
    
    # Check helm availability and version    # Helm/jq required only for Helm flows
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
        
        local jq_version=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if [[ -n "${jq_version}" ]]; then
            local jq_major=$(echo "${jq_version}" | cut -d. -f1)
            if [[ ${jq_major} -lt 1 ]]; then
                print_warning "jq version ${jq_version} detected. Recommended: jq v1.6 or higher"
            else
                print_info "jq version ${jq_version} - OK"
            fi
        else
            print_warning "Could not determine jq version. Proceeding with caution..."
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
    
    # Validate current deployed app_version is 1.11.0 for both releases before extracting values
    local bs_ver="unknown"; local base_ver="unknown"
    bs_ver=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' || echo "unknown")
    base_ver=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE_NAME}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"' || echo "unknown")
    if [[ "${bs_ver}" != "1.11.0" ]]; then
        print_error "${PLATFORM_BOOTSTRAP_RELEASE_NAME} app_version is '${bs_ver}', expected 1.11.0"
        exit 1
    fi
    if [[ "${base_ver}" != "1.11.0" ]]; then
        print_error "${PLATFORM_BASE_RELEASE_NAME} app_version is '${base_ver}', expected 1.11.0"
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

# Generate output filenames
generate_output_filenames() {
    local base_dir=$([[ "${OPERATION_MODE}" == "helm" ]] && echo "." || dirname "${PLATFORM_BASE_FILE}")
    [[ -z "${PLATFORM_OUTPUT_BASE_FILE}" ]] && PLATFORM_OUTPUT_BASE_FILE="${base_dir}/platform-base-${PLATFORM_BASE_CHART_VERSION}.yaml"
    [[ -z "${PLATFORM_OUTPUT_BOOTSTRAP_FILE}" ]] && PLATFORM_OUTPUT_BOOTSTRAP_FILE="${base_dir}/platform-bootstrap-${PLATFORM_BOOTSTRAP_CHART_VERSION}.yaml"
    print_info "Output files: ${PLATFORM_OUTPUT_BASE_FILE}, ${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
}

# Main processing function - combines extract, validate, transform, and merge
process_files() {
    print_info "Processing files for upgrade generation (no schema changes for 1.12.0)..."
    
    # Validate files
    for f in "${PLATFORM_BOOTSTRAP_FILE}" "${PLATFORM_BASE_FILE}"; do
        if [[ ! -f "${f}" ]]; then
            print_error "File not found: ${f}"
            exit 1
        fi
        if [[ ! -r "${f}" ]]; then
            print_error "File not readable: ${f}"
            exit 1
        fi
    done
    
    # Direct copy: no transformations between 1.11.x and 1.12.0
    cp "${PLATFORM_BASE_FILE}" "${PLATFORM_OUTPUT_BASE_FILE}" && cp "${PLATFORM_BOOTSTRAP_FILE}" "${PLATFORM_OUTPUT_BOOTSTRAP_FILE}"
    
    print_success "Values copied without modification"
    print_info "Values generation summary:"
    print_info "  [+] platform-base copied -> ${PLATFORM_OUTPUT_BASE_FILE} (version: ${PLATFORM_BASE_CHART_VERSION})"
    print_info "  [+] platform-bootstrap copied -> ${PLATFORM_OUTPUT_BOOTSTRAP_FILE} (version: ${PLATFORM_BOOTSTRAP_CHART_VERSION})"
    print_info "  [+] Generated version-specific files"
}

# Main execution
main() {
    print_info "TIBCO Control Plane Upgrade Script - 1.11.0 to 1.12.0"
    print_info "=================================================="
    
    # Handle help request
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Always run in interactive mode
    setup_temp_dir
    # Initial generic checks (yq)
    check_dependencies
    # Determine operation mode
    interactive_mode
    
    # Handle Helm upgrade mode
    if [[ "${HELM_UPGRADE_MODE}" == "true" ]]; then
        echo ""
        print_warning "WARNING: This will perform actual Helm upgrades on your cluster!"
        print_info "Target namespace: ${NAMESPACE}"
        
        # Show only selected chart details
        if [[ "${UPGRADE_BOOTSTRAP}" == "true" ]]; then
            print_info "Platform Bootstrap release: ${PLATFORM_BOOTSTRAP_RELEASE_NAME} (version: ${PLATFORM_BOOTSTRAP_CHART_VERSION})"
        fi
        
        if [[ "${UPGRADE_BASE}" == "true" ]]; then
            print_info "Platform Base release: ${PLATFORM_BASE_RELEASE_NAME} (version: ${PLATFORM_BASE_CHART_VERSION})"
        fi
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
