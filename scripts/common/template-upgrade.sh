#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# TEMPLATE: TIBCO Control Plane Upgrade Script
# 
# This template is for upgrades using the tibco-cp-base chart.
# For upgrades from version 1.13.0 onwards.
#
# Instructions:
# 1. Copy this file to scripts/<version>/upgrade.sh
# 2. Update FROM_VERSION and TO_VERSION
# 3. Implement version-specific logic in process_files()
# 4. Update show_usage() if needed
# 5. Test thoroughly
#

# ============================================================================
# INITIALIZATION - Source Common Helpers
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/upgrade-helpers.sh"

# Initialize common variables (sets strict error handling)
init_common_variables

# ============================================================================
# SCRIPT-SPECIFIC CONFIGURATION
# ============================================================================

# Version configuration
FROM_VERSION="1.X.0"  # TODO: Update this (must be 1.13.0+)
TO_VERSION="1.Y.0"    # TODO: Update this
DEFAULT_VERSION="${TO_VERSION}"

# Dependency requirements
REQUIRED_YQ_VERSION="4.45.4"
REQUIRED_JQ_VERSION="1.8.0"
REQUIRED_HELM_VERSION="3.17"

# Global variables (single chart/release)
CONTROL_PLANE_FILE=""
CONTROL_PLANE_OUTPUT_FILE=""
CONTROL_PLANE_RELEASE_NAME="platform-base"  # Standard release name
TP_HELM_REPO_NAME="tibco-platform"
CHART_VERSION="${CHART_VERSION:-${TO_VERSION}}"
CHART_NAME="tibco-cp-base"  # Chart name

# ============================================================================
# USAGE/HELP
# ============================================================================

show_usage() {
    show_standard_usage "${FROM_VERSION}" "${TO_VERSION}"
    
    cat << EOF

VERSION 1.13.0+ NOTES:
  - This script works with the tibco-cp-base chart (single release: platform-base)
  - No separate platform-bootstrap chart
  - Single values.yaml file for the entire control plane
EOF
}

# ============================================================================
# INTERACTIVE MODE FUNCTIONS
# ============================================================================

interactive_mode() {
    print_info "TIBCO Control Plane Upgrade Script - ${FROM_VERSION} to ${TO_VERSION}"
    print_info "Chart: tibco-cp-base"
    print_separator
    
    echo "Please select your operation mode:"
    echo "1) Generate ${TO_VERSION} values.yaml file from current ${FROM_VERSION} setup"
    echo "2) Perform Helm upgrade using existing ${TO_VERSION}-compatible values.yaml file"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate ${TO_VERSION} values.yaml file"
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

interactive_values_generation() {
    echo ""
    print_info "Values Generation Setup"
    print_separator
    
    echo "How would you like to provide your current ${FROM_VERSION} values?"
    echo "1) I have existing ${FROM_VERSION} values.yaml file"
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

interactive_file_input() {
    echo ""
    
    # Get input file using helper
    CONTROL_PLANE_FILE=$(prompt_for_file "Enter control plane values.yaml file (${FROM_VERSION})" true)
    
    print_success "Input file validated successfully"
    
    # Ask for custom output file name
    echo ""
    print_info "Output File Configuration"
    print_separator
    
    read -p "Custom output file for control plane (default: control-plane-${TO_VERSION}.yaml): " custom_output
    CONTROL_PLANE_OUTPUT_FILE="${custom_output:-control-plane-${TO_VERSION}.yaml}"
    print_info "Using output: ${CONTROL_PLANE_OUTPUT_FILE}"
    
    print_success "Configuration completed successfully"
}

interactive_helm_input() {
    echo ""
    
    # Validate dependencies for Helm operations
    print_info "Validating Helm/jq requirements for extraction..."
    check_dependencies "${REQUIRED_YQ_VERSION}" true false || exit 1
    
    # Get Helm configuration using helpers
    NAMESPACE=$(prompt_for_namespace)
    verify_namespace "${NAMESPACE}" || exit 1
    
    CONTROL_PLANE_RELEASE_NAME=$(prompt_for_release_name \
        "Control plane release name" "${CONTROL_PLANE_RELEASE_NAME}")
    
    print_success "Helm extraction configuration set successfully"
    
    # Configure output file
    echo ""
    print_info "Output File Configuration"
    print_separator
    
    read -p "Custom output file for control plane (default: control-plane-${TO_VERSION}.yaml): " custom_output
    CONTROL_PLANE_OUTPUT_FILE="${custom_output:-control-plane-${TO_VERSION}.yaml}"
    print_info "Using output: ${CONTROL_PLANE_OUTPUT_FILE}"
    
    print_success "Configuration completed successfully"
}

interactive_helm_upgrade() {
    echo ""
    print_info "Helm Upgrade Setup"
    print_separator
    
    # Validate dependencies for upgrade
    print_info "Validating Helm/jq requirements for upgrade..."
    HELM_UPGRADE_MODE=true
    check_dependencies "${REQUIRED_YQ_VERSION}" true true || exit 1
    
    print_info "This mode will perform actual Helm upgrade on your cluster using ${TO_VERSION} values.yaml file."
    echo ""
    
    # Get values.yaml file
    CONTROL_PLANE_FILE=$(prompt_for_file \
        "Enter ${TO_VERSION} control plane values.yaml file" true)
    
    # Get cluster information
    NAMESPACE=$(prompt_for_namespace)
    verify_namespace "${NAMESPACE}" || exit 1
    
    # Get release name
    CONTROL_PLANE_RELEASE_NAME=$(prompt_for_release_name \
        "Control plane release name" "${CONTROL_PLANE_RELEASE_NAME}")
    
    # Get Helm repository name
    TP_HELM_REPO_NAME=$(prompt_for_release_name \
        "Helm repository name" "${TP_HELM_REPO_NAME}")
    
    print_success "Helm upgrade configuration complete"
    
    HELM_UPGRADE_MODE=true
    OPERATION_MODE="file"
}

# ============================================================================
# HELM VALUES EXTRACTION
# ============================================================================

extract_helm_values_for_upgrade() {
    print_info "Extracting Helm values from namespace: ${NAMESPACE}"
    
    # Validate current release
    validate_helm_release_for_upgrade \
        "${CONTROL_PLANE_RELEASE_NAME}" \
        "${NAMESPACE}" \
        "${FROM_VERSION}" \
        "deployed" || exit 1
    
    # Extract values using helper
    local values_file="${TEMP_DIR}/current-values.yaml"
    extract_helm_values "${CONTROL_PLANE_RELEASE_NAME}" "${NAMESPACE}" "${values_file}" || exit 1
    CONTROL_PLANE_FILE="${values_file}"
    
    # Ensure files are fully written
    sync 2>/dev/null || true
    sleep 1
    
    print_success "Helm values extracted successfully"
}

# ============================================================================
# FILE PROCESSING (VERSION-SPECIFIC LOGIC)
# ============================================================================

process_files() {
    print_info "Processing files for upgrade generation..."
    
    # Validate input file using helper
    validate_file "${CONTROL_PLANE_FILE}" "Control plane values file" || exit 1
    
    # ========================================================================
    # TODO: Implement version-specific transformation logic here
    # ========================================================================
    
    # Example: Start with current values as base
    cp "${CONTROL_PLANE_FILE}" "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Example: Apply version-specific transformations using yq
    # yq eval '.some.new.config = "value"' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    # yq eval 'del(.deprecated.section)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Example: Merge new configurations
    # if [[ -f "${TEMP_DIR}/new-config.yaml" ]]; then
    #     yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
    #         "${CONTROL_PLANE_OUTPUT_FILE}" \
    #         "${TEMP_DIR}/new-config.yaml" > "${CONTROL_PLANE_OUTPUT_FILE}.tmp"
    #     mv "${CONTROL_PLANE_OUTPUT_FILE}.tmp" "${CONTROL_PLANE_OUTPUT_FILE}"
    # fi
    
    print_success "Processing completed successfully"
    
    # Summary
    print_info "Values generation summary:"
    print_info "  [+] Generated control plane file: ${CONTROL_PLANE_OUTPUT_FILE}"
    print_info "  [+] Target version: ${TO_VERSION}"
    print_info "  [+] Chart: ${CHART_NAME}"
}

# ============================================================================
# HELM UPGRADE EXECUTION
# ============================================================================

upgrade_control_plane_chart() {
    print_info "Upgrading ${CONTROL_PLANE_RELEASE_NAME} to ${CHART_NAME} version ${CHART_VERSION}..."
    
    if helm upgrade "${CONTROL_PLANE_RELEASE_NAME}" "${TP_HELM_REPO_NAME}/${CHART_NAME}" \
        --version "${CHART_VERSION}" \
        --namespace "${NAMESPACE}" \
        --values "${CONTROL_PLANE_FILE}" \
        --wait --timeout=1h; then
        print_success "Successfully upgraded ${CONTROL_PLANE_RELEASE_NAME}"
        return 0
    else
        print_error "Failed to upgrade ${CONTROL_PLANE_RELEASE_NAME}"
        return 1
    fi
}

perform_helm_upgrade() {
    print_info "Starting Helm upgrade process"
    print_separator
    
    # Validate current deployment
    print_info "Validating current deployment version..."
    validate_helm_release_for_upgrade \
        "${CONTROL_PLANE_RELEASE_NAME}" \
        "${NAMESPACE}" \
        "${FROM_VERSION}" \
        "deployed" || return 1
    
    # Update Helm repository
    print_info "Updating Helm charts repository..."
    helm repo update "${TP_HELM_REPO_NAME}"
    print_success "Repository updated successfully"
    
    # Perform upgrade
    upgrade_control_plane_chart || return 1
    
    # Verify upgrade
    verify_helm_upgrades
}

verify_helm_upgrades() {
    print_info "Verifying Helm upgrade..."
    echo ""
    
    # Verify using helper
    verify_upgrade "${CONTROL_PLANE_RELEASE_NAME}" "${NAMESPACE}" "${TO_VERSION}"
    
    echo ""
    # Check pod status using helper
    check_pod_status "${NAMESPACE}"
    
    print_info "NOTE: This script does NOT perform application-level or functional tests."
    print_info "We recommend you run your own post-upgrade tests as required."
    
    print_success "Upgrade verification completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_info "TIBCO Control Plane Upgrade Script - ${FROM_VERSION} to ${TO_VERSION}"
    print_info "Chart: ${CHART_NAME} (release: ${CONTROL_PLANE_RELEASE_NAME})"
    print_separator
    
    # Handle help request
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Setup
    setup_temp_dir
    
    # Check basic dependencies (yq always required)
    check_dependencies "${REQUIRED_YQ_VERSION}" false false || exit 1
    
    # Interactive mode
    interactive_mode
    
    # Handle Helm upgrade mode
    if [[ "${HELM_UPGRADE_MODE}" == "true" ]]; then
        echo ""
        print_warning "WARNING: This will perform actual Helm upgrade on your cluster!"
        print_info "Target namespace: ${NAMESPACE}"
        print_info "Release: ${CONTROL_PLANE_RELEASE_NAME}"
        print_info "Chart: ${CHART_NAME} version ${CHART_VERSION}"
        echo ""
        
        if prompt_yes_no "Do you want to proceed with the upgrade?" "no"; then
            perform_helm_upgrade
            print_success "All operations completed successfully!"
            exit 0
        else
            print_info "Helm upgrade cancelled by user"
            exit 0
        fi
    else
        # Standard values generation mode
        if [[ "${OPERATION_MODE}" == "helm" ]]; then
            extract_helm_values_for_upgrade
        fi
        
        # Generate output filename if not set
        [[ -z "${CONTROL_PLANE_OUTPUT_FILE}" ]] && \
            CONTROL_PLANE_OUTPUT_FILE="control-plane-${TO_VERSION}.yaml"
        
        process_files
        
        echo ""
        print_success "Values.yaml generation completed successfully!"
        print_info "Generated values.yaml file for upgrade:"
        print_info "  - ${CONTROL_PLANE_OUTPUT_FILE}"
    fi
    
    print_success "All operations completed successfully!"
}

# Execute main function
main "${@}"
