#!/bin/bash
#
# Copyright (c) 2026 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Tested with: GNU bash, version 5.2.21(1)-release
#
# TIBCO Control Plane Helm Values Generation Script for Platform Upgrade FROM 1.15.0 TO 1.16.0
# Works with the unified tibco-cp-base chart (single chart deployment)

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
FROM_VERSION="${FROM_VERSION:-1.15.0}"  # TODO: Update this (must be 1.13.0+)
TO_VERSION="1.16.0"    # TODO: Update this
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
    local minor_version
    minor_version=$(get_minor_version "${TO_VERSION}")
    print_info "TIBCO Control Plane Upgrade Script - ${FROM_VERSION} to ${minor_version}"
    print_info "Chart: tibco-cp-base"
    print_separator
    
    echo "Please select your operation mode:"
    echo "1) Generate ${minor_version} values.yaml file from current ${FROM_VERSION} setup"
    echo "2) Perform Helm upgrade using existing ${minor_version}-compatible values.yaml file"
    echo ""
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate ${minor_version} values.yaml file"
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
    
    local minor_version
    minor_version=$(get_minor_version "${TO_VERSION}")
    read -p "Custom output file for control plane (default: control-plane-${minor_version}.yaml): " custom_output
    CONTROL_PLANE_OUTPUT_FILE="${custom_output:-control-plane-${minor_version}.yaml}"
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
    
    local minor_version
    minor_version=$(get_minor_version "${TO_VERSION}")
    read -p "Custom output file for control plane (default: control-plane-${minor_version}.yaml): " custom_output
    CONTROL_PLANE_OUTPUT_FILE="${custom_output:-control-plane-${minor_version}.yaml}"
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
    # Version-specific transformation logic for 1.15.0 to 1.16.0
    # ========================================================================
    
    # Start with current values as base
    cp "${CONTROL_PLANE_FILE}" "${CONTROL_PLANE_OUTPUT_FILE}"
    
    print_info "Removing deprecated flags and sections for 1.16.0..."
    
    # Remove tp-cp-prometheus.enabled flag
    yq eval 'del(.tp-cp-prometheus.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove tp-cp-o11y.enabled flag  
    yq eval 'del(.tp-cp-o11y.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove tp-cp-auditsafe.enabled flag
    yq eval 'del(.tp-cp-auditsafe.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove hybrid-proxy.enabled flag
    yq eval 'del(.hybrid-proxy.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove resource-set-operator.enabled flag
    yq eval 'del(.resource-set-operator.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove entire tp-dp-proxy section
    yq eval 'del(.tp-dp-proxy)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove router-operator.enabled flag
    yq eval 'del(.router-operator.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove entire tp-cp-prometheus section
    yq eval 'del(.tp-cp-prometheus)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove db_ssl_root_cert flag under global.external
    yq eval 'del(.global.external.db_ssl_root_cert)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove entire proxy section (httpProxy, httpsProxy, noProxy)
    yq eval 'del(.global.tibco.proxy)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove rbac section under global.tibco if present
    yq eval 'del(.global.tibco.rbac)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove deprecated logging configuration
    yq eval 'del(.global.tibco.logging.fluentbit.image.name)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    yq eval 'del(.global.tibco.logging.fluentbit.image.pullPolicy)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    yq eval 'del(.global.tibco.logging.fluentbit.image.registry)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    yq eval 'del(.global.tibco.logging.fluentbit.image.repo)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    yq eval 'del(.global.tibco.logging.repository)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove deprecated tp-cp-infra configuration
    yq eval 'del(.tp-cp-infra.enabled)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    yq eval 'del(.tp-cp-infra.dpMetadata)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove deprecated finops configuration
    yq eval 'del(.global.tibco.finops)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    print_success "Deprecated flags and sections removed successfully"
    
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
    
    # Validate current deployment version with retry logic
    print_info "Validating current deployment version..."
    validate_helm_release_for_upgrade \
        "${CONTROL_PLANE_RELEASE_NAME}" \
        "${NAMESPACE}" \
        "${FROM_VERSION}" \
        "deployed" \
        "${TO_VERSION}" \
        "true" || return 1
    
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
    local minor_version
    minor_version=$(get_minor_version "${TO_VERSION}")
    print_info "TIBCO Control Plane Upgrade Script - ${FROM_VERSION} to ${minor_version}"
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
        
        # Generate output filename if not set (uses minor version for master script compatibility)
        [[ -z "${CONTROL_PLANE_OUTPUT_FILE}" ]] && \
            CONTROL_PLANE_OUTPUT_FILE="control-plane-$(get_minor_version "${TO_VERSION}").yaml"
        
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
