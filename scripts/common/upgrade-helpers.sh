#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Common Helper Functions for TIBCO Control Plane Upgrade Scripts
# This library provides reusable functions for chart upgrade scripts (1.13.0+)
#
# Note: For upgrades from 1.13.0 onwards using single tibco-cp-base chart (release: platform-base)
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../common/upgrade-helpers.sh"
#

# Prevent multiple sourcing
if [[ -n "${UPGRADE_HELPERS_LOADED:-}" ]]; then
    return 0
fi
UPGRADE_HELPERS_LOADED=1

# ============================================================================
# COLOR CODES
# ============================================================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# ============================================================================
# PRINT FUNCTIONS
# ============================================================================

# Print informational message
print_info() { 
    echo -e "${BLUE}[INFO]${NC} ${1}" 
}

# Print success message
print_success() { 
    echo -e "${GREEN}[SUCCESS]${NC} ${1}" 
}

# Print warning message
print_warning() { 
    echo -e "${YELLOW}[WARNING]${NC} ${1}" 
}

# Print error message to stderr
print_error() { 
    echo -e "${RED}[ERROR]${NC} ${1}" >&2 
}

# Print step message (for major operations)
print_step() { 
    echo -e "${CYAN}[STEP]${NC} ${1}" 
}

# Print separator line
print_separator() {
    echo ""
    echo "================================================================================"
    echo ""
}

# ============================================================================
# VERSION COMPARISON FUNCTIONS
# ============================================================================

# Compare versions using semantic versioning
# Returns 0 if v1 >= v2, 1 otherwise
# Usage: version_ge "1.13.0" "1.12.0"
version_ge() {
    local v1="$1" v2="$2"
    
    # Normalize version string
    norm() {
        local v="$1"
        v=$(echo "$v" | grep -oE '[0-9]+(\.[0-9]+){1,2}' || echo "0.0.0")
        local a b c
        IFS='.' read -r a b c <<<"$v"
        [[ -z "$a" ]] && a=0
        [[ -z "$b" ]] && b=0
        [[ -z "$c" ]] && c=0
        printf "%d.%d.%d\n" "$a" "$b" "$c"
    }
    
    v1=$(norm "$v1")
    v2=$(norm "$v2")
    IFS='.' read -r a1 b1 c1 <<<"$v1"
    IFS='.' read -r a2 b2 c2 <<<"$v2"
    
    if (( a1 > a2 )) || { (( a1 == a2 )) && (( b1 > b2 )); } || { (( a1 == a2 )) && (( b1 == b2 )) && (( c1 >= c2 )); }; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# TEMPORARY DIRECTORY MANAGEMENT
# ============================================================================

# Setup temporary directory with automatic cleanup on exit
# Sets TEMP_DIR global variable
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "${TEMP_DIR}" 2>/dev/null || true' EXIT
    print_info "Temp directory: ${TEMP_DIR}"
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check yq availability and version
check_yq() {
    local required_version="${1:-4.0}"
    
    if ! command_exists yq; then
        print_error "yq is required. Install with: sudo apt-get install yq or brew install yq"
        return 1
    fi
    
    local yq_version=$(yq --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -1)
    if [[ -n "${yq_version}" ]]; then
        if version_ge "${yq_version}" "${required_version}"; then
            print_info "yq version ${yq_version} - OK"
            return 0
        else
            print_error "yq version ${yq_version} detected. Required: yq v${required_version} or higher"
            return 1
        fi
    else
        print_warning "Could not determine yq version. Required: yq v${required_version} or higher"
        return 1
    fi
}

# Check helm availability and version
check_helm() {
    local required_version="${1:-3.17}"
    
    if ! command_exists helm; then
        print_error "helm is required. Install from: https://helm.sh/docs/intro/install/"
        return 1
    fi
    
    local helm_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+' | head -1 | sed 's/v//')
    if [[ -n "${helm_version}" ]]; then
        local helm_major=$(echo "${helm_version}" | cut -d. -f1)
        local helm_minor=$(echo "${helm_version}" | cut -d. -f2)
        local req_major=$(echo "${required_version}" | cut -d. -f1)
        local req_minor=$(echo "${required_version}" | cut -d. -f2)
        
        if [[ ${helm_major} -lt ${req_major} ]] || [[ ${helm_major} -eq ${req_major} && ${helm_minor} -lt ${req_minor} ]]; then
            print_error "Helm version ${helm_version} detected. Required: Helm v${required_version} or higher"
            return 1
        else
            print_info "Helm version ${helm_version} - OK"
            return 0
        fi
    else
        print_warning "Could not determine Helm version. Proceeding with caution..."
        return 0
    fi
}

# Check jq availability and version
check_jq() {
    local required_version="${1:-1.5}"
    
    if ! command_exists jq; then
        print_error "jq is required. Install with: sudo apt-get install jq or brew install jq"
        return 1
    fi
    
    local jq_version=$(jq --version 2>/dev/null | sed -E 's/^[^0-9]*//' | grep -oE '^[0-9]+(\.[0-9]+){1,2}' | head -1)
    if [[ -n "${jq_version}" ]]; then
        if version_ge "${jq_version}" "${required_version}"; then
            print_info "jq version ${jq_version} - OK"
            return 0
        else
            print_error "jq version ${jq_version} detected. Required: jq v${required_version} or higher"
            return 1
        fi
    else
        print_warning "Could not determine jq version. Required: jq v${required_version} or higher"
        return 0
    fi
}

# Check kubectl availability
check_kubectl() {
    if ! command_exists kubectl; then
        print_error "kubectl is required. Install from: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    print_info "kubectl - OK"
    return 0
}

# Comprehensive dependency check for upgrade operations
# Usage: check_dependencies [yq_min_version] [helm_mode] [upgrade_mode]
check_dependencies() {
    local yq_min_version="${1:-4.0}"
    local helm_mode="${2:-false}"
    local upgrade_mode="${3:-false}"
    
    print_info "Checking dependencies..."
    
    local check_failed=false
    
    # yq is always required
    if ! check_yq "${yq_min_version}"; then
        check_failed=true
    fi
    
    # helm and jq required for helm operations
    if [[ "${helm_mode}" == "true" || "${upgrade_mode}" == "true" ]]; then
        if ! check_helm "3.17"; then
            check_failed=true
        fi
        
        if ! check_jq "1.5"; then
            check_failed=true
        fi
    fi
    
    # kubectl required for upgrade mode
    if [[ "${upgrade_mode}" == "true" ]]; then
        if ! check_kubectl; then
            check_failed=true
        fi
    fi
    
    if [[ "${check_failed}" == "true" ]]; then
        echo "Dependency check failed"
        return 1
    fi
    
    print_success "All required dependencies are installed"
    return 0
}

# ============================================================================
# HELM OPERATIONS
# ============================================================================

# Get Helm release chart version
# Usage: get_helm_release_version <release_name> <namespace>
get_helm_release_version() {
    local release_name="$1"
    local namespace="$2"
    
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        echo "not-found"
        return
    fi
    
    helm list -n "${namespace}" -f "^${release_name}$" -o json 2>/dev/null | \
        jq -r '.[0].app_version // "unknown"'
}

# Get Helm release status
# Usage: get_helm_release_status <release_name> <namespace>
get_helm_release_status() {
    local release_name="$1"
    local namespace="$2"
    
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        echo "not-found"
        return
    fi
    
    helm status "${release_name}" -n "${namespace}" -o json 2>/dev/null | \
        jq -r '.info.status // "unknown"'
}

# Extract values from Helm release
# Usage: extract_helm_values <release_name> <namespace> <output_file>
extract_helm_values() {
    local release_name="$1"
    local namespace="$2"
    local output_file="$3"
    
    print_info "Extracting Helm values from release: ${release_name}"
    
    # Check if release exists
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        print_error "Release '${release_name}' not found in namespace '${namespace}'"
        return 1
    fi
    
    # Extract values
    local temp_file="${output_file}.raw"
    if ! helm get values -n "${namespace}" "${release_name}" > "${temp_file}"; then
        print_error "Failed to extract values from release: ${release_name}"
        return 1
    fi
    
    # Remove header if present and create clean file
    if head -1 "${temp_file}" | grep -q "USER-SUPPLIED VALUES"; then
        tail -n +2 "${temp_file}" > "${output_file}"
    else
        cp "${temp_file}" "${output_file}"
    fi
    
    # Ensure file has content
    if [[ ! -s "${output_file}" ]]; then
        echo "{}" > "${output_file}"
    fi
    
    rm -f "${temp_file}"
    print_success "Values extracted successfully to: ${output_file}"
    return 0
}

# Validate Helm release for upgrade
# Usage: validate_helm_release_for_upgrade <release_name> <namespace> <expected_version> <expected_status>
validate_helm_release_for_upgrade() {
    local release_name="$1"
    local namespace="$2"
    local expected_version="$3"
    local expected_status="${4:-deployed}"
    
    # Check if release exists
    if ! helm status "${release_name}" -n "${namespace}" >/dev/null 2>&1; then
        print_error "Release '${release_name}' not found in namespace '${namespace}'"
        return 1
    fi
    
    # Get status and version
    local current_status=$(get_helm_release_status "${release_name}" "${namespace}")
    local current_version=$(get_helm_release_version "${release_name}" "${namespace}")
    
    print_info "Release '${release_name}' status: ${current_status}, version: ${current_version}"
    
    # Validate status
    if [[ "${current_status}" != "${expected_status}" ]]; then
        print_error "Release status is '${current_status}', expected '${expected_status}'"
        return 1
    fi
    
    # Validate version
    if [[ "${current_version}" != "${expected_version}" ]]; then
        print_error "Release version is '${current_version}', expected '${expected_version}'"
        return 1
    fi
    
    print_success "Release validation passed"
    return 0
}

# ============================================================================
# KUBECTL OPERATIONS
# ============================================================================

# Verify namespace exists
# Usage: verify_namespace <namespace>
verify_namespace() {
    local namespace="$1"
    
    print_info "Verifying namespace: ${namespace}"
    
    if ! kubectl get namespace "${namespace}" >/dev/null 2>&1; then
        print_error "Namespace '${namespace}' not found"
        return 1
    fi
    
    print_success "Namespace verified"
    return 0
}

# Check pod status in namespace
# Usage: check_pod_status <namespace>
check_pod_status() {
    local namespace="$1"
    
    print_info "Checking pod readiness in namespace ${namespace}..."
    
    if kubectl get pods -n "${namespace}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | grep -q .; then
        print_warning "Some pods are not in Running/Completed state:"
        kubectl get pods -n "${namespace}" --no-headers | grep -v "Running\|Completed" || true
        return 1
    else
        print_success "All pods are in Running/Completed state"
        return 0
    fi
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Validate file exists and is readable
# Usage: validate_file <file_path> <description>
validate_file() {
    local file_path="$1"
    local description="${2:-File}"
    
    if [[ ! -f "${file_path}" ]]; then
        print_error "${description} not found: ${file_path}"
        return 1
    fi
    
    if [[ ! -r "${file_path}" ]]; then
        print_error "${description} not readable: ${file_path}"
        return 1
    fi
    
    return 0
}

# Generate output filename with version
# Usage: generate_output_filename <base_name> <version> <operation_mode> <base_dir>
generate_output_filename() {
    local base_name="$1"
    local version="$2"
    local operation_mode="${3:-file}"
    local base_dir="${4:-.}"
    
    if [[ "${operation_mode}" == "helm" ]]; then
        echo "./${base_name}-${version}.yaml"
    else
        echo "${base_dir}/${base_name}-${version}.yaml"
    fi
}

# ============================================================================
# INTERACTIVE INPUT HELPERS
# ============================================================================

# Prompt for file input with validation
# Usage: prompt_for_file <prompt_text> <validation_required>
prompt_for_file() {
    local prompt_text="$1"
    local validation_required="${2:-true}"
    local file_path=""
    
    while [[ -z "${file_path}" ]]; do
        read -p "${prompt_text}: " file_path
        
        if [[ "${validation_required}" == "true" && ! -f "${file_path}" ]]; then
            print_error "File not found: ${file_path}"
            file_path=""
        fi
    done
    
    echo "${file_path}"
}

# Prompt for namespace input
# Usage: prompt_for_namespace
prompt_for_namespace() {
    local namespace=""
    
    while [[ -z "${namespace}" ]]; do
        read -p "Enter Kubernetes namespace containing your deployments: " namespace
        if [[ -z "${namespace}" ]]; then
            print_error "Namespace cannot be empty"
        fi
    done
    
    echo "${namespace}"
}

# Prompt for release name with default
# Usage: prompt_for_release_name <prompt_text> <default_value>
prompt_for_release_name() {
    local prompt_text="$1"
    local default_value="$2"
    local release_name=""
    
    read -p "${prompt_text} (default: ${default_value}): " release_name
    
    if [[ -z "${release_name}" ]]; then
        echo "${default_value}"
    else
        echo "${release_name}"
    fi
}

# Prompt for yes/no confirmation
# Usage: prompt_yes_no <prompt_text> [default]
prompt_yes_no() {
    local prompt_text="$1"
    local default="${2:-no}"
    local response=""
    
    while true; do
        read -p "${prompt_text} (yes/no): " response
        case "${response,,}" in
            yes|y)
                return 0
                ;;
            no|n)
                return 1
                ;;
            "")
                if [[ "${default,,}" == "yes" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *)
                print_error "Invalid response. Please enter 'yes' or 'no'."
                ;;
        esac
    done
}

# ============================================================================
# USAGE/HELP DISPLAY
# ============================================================================

# Show standard usage help for upgrade scripts
# Usage: show_standard_usage <from_version> <to_version>
show_standard_usage() {
    local from_version="$1"
    local to_version="$2"
    
    cat << EOF
TIBCO Control Plane Upgrade Assistant - ${from_version} to ${to_version}
==================================================

This script provides an interactive experience to help you upgrade your TIBCO Control Plane
from version ${from_version} to ${to_version}.

USAGE:
  Simply run: \$0

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
  - It assumes all chart values are correct, performs the upgrade from ${from_version} to ${to_version}
    and verifies that the pods in the target namespace are in Running/Completed state.
  - We recommend you run your own post-upgrade tests as required.
EOF
}

# ============================================================================
# UPGRADE VERIFICATION
# ============================================================================

# Verify upgrade was successful
# Usage: verify_upgrade <release_name> <namespace> <expected_version>
verify_upgrade() {
    local release_name="$1"
    local namespace="$2"
    local expected_version="$3"
    
    print_info "Verifying upgrade..."
    
    local current_version=$(get_helm_release_version "${release_name}" "${namespace}")
    local current_status=$(get_helm_release_status "${release_name}" "${namespace}")
    
    print_info "Release '${release_name}': status=${current_status}, version=${current_version}"
    
    if [[ "${current_version}" == "${expected_version}" ]]; then
        print_success "Version verified: ${current_version}"
    else
        print_warning "Version mismatch: expected ${expected_version}, got ${current_version}"
        return 1
    fi
    
    if [[ "${current_status}" != "deployed" ]]; then
        print_warning "Release status is '${current_status}', expected 'deployed'"
        return 1
    fi
    
    print_success "Upgrade verification passed"
    return 0
}

# ============================================================================
# LOGGING
# ============================================================================

# Setup logging to file
# Usage: setup_logging <log_dir> <log_prefix>
setup_logging() {
    local log_dir="$1"
    local log_prefix="${2:-upgrade}"
    
    mkdir -p "${log_dir}"
    local log_file="${log_dir}/${log_prefix}-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "${log_file}") 2>&1
    print_info "Logging to: ${log_file}"
    echo "${log_file}"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Handle fatal error and exit
# Usage: fatal_error <message>
fatal_error() {
    local message="$1"
    print_error "${message}"
    exit 1
}

# ============================================================================
# COMMON VARIABLE INITIALIZATION
# ============================================================================

# Initialize common global variables for upgrade scripts
init_common_variables() {
    # Set strict error handling
    set -euo pipefail
    
    # Initialize common variables if not already set
    export TEMP_DIR="${TEMP_DIR:-}"
    export OPERATION_MODE="${OPERATION_MODE:-}"
    export HELM_UPGRADE_MODE="${HELM_UPGRADE_MODE:-false}"
    export NAMESPACE="${NAMESPACE:-}"
}

# ============================================================================
# SCRIPT INITIALIZATION
# ============================================================================

print_info "Common upgrade helpers loaded successfully"
