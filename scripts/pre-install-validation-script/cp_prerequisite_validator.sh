#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Control Plane Installation Prerequisite Validation Script
# Based on the validation requirements for self-hosted Control Plane deployment
# Author: Generated from prerequisite validation document
# Version: 1.0

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
PRE_INSTALL_VALIDATION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${PRE_INSTALL_VALIDATION_SCRIPT_DIR}/cp_validation_$(date +%Y%m%d_%H%M%S).log"
VALIDATION_RESULTS=()
HIGH_SEVERITY_FAILURES=0
MEDIUM_SEVERITY_FAILURES=0
LOW_SEVERITY_FAILURES=0

DEFAULT_CONFIG_FILE="${PRE_INSTALL_VALIDATION_SCRIPT_DIR}/platform_base_default_config.env"

# Validation control flags
SKIP_LOW_SEVERITY=false
SKIP_MEDIUM_SEVERITY=false
VALIDATE_POST_INSTALL=false

# Print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Control Plane Installation Prerequisite Validation Script

OPTIONS:
    -n, --namespace NAME    Kubernetes namespace (default: default)
    -s, --skip-low         Skip low severity validations
    -m, --skip-medium      Skip medium severity validations
    -h, --help             Show this help message

CONFIGURATION FILES:
    1. Default configuration:  ${PRE_INSTALL_VALIDATION_SCRIPT_DIR}/platform_base_default_config.env
    2. YAML configuration:     platform_base_values.yaml (default)
    3. Required images file:   required_images.txt (default)
    You will be prompted to enter the YAML configuration file and required images file names at runtime.

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                if [[ -z "${2:-}" || "${2}" == -* ]]; then
                    NAMESPACE="default"
                    shift 1
                else
                    NAMESPACE="$2"
                    shift 2
                fi
                ;;
            -s|--skip-low)
                SKIP_LOW_SEVERITY=true
                shift
                ;;
            -m|--skip-medium)
                SKIP_MEDIUM_SEVERITY=true
                shift
                ;;
            -p|--post-install)
                VALIDATE_POST_INSTALL=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

get_config_value() {
    local var_name="$1"
    local yaml_path="$2"
    local env_value="${!var_name-}"
    if [[ -n "$env_value" ]]; then
        echo "$env_value"
    else
        yq e "$yaml_path" "$YAML_CONFIG_FILE"
    fi
}

# --- NEW FUNCTION TO PARSE YAML CONFIGURATION ---
parse_yaml_config() {
    local yaml_file="$1"

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
            log "WARN" "Failed to load configuration" "yq version ${yq_version} detected. Recommended: yq v4.0 or higher"
        else
            log "INFO" "yq version ${yq_version} - OK"
        fi
    else
        log "WARN" "Failed to load configuration" "Could not determine yq version. Proceeding with caution..."
    fi

    if [[ ! -f "${yaml_file}" ]]; then
        log "ERROR" "YAML configuration file ${yaml_file} not found."
        return 1
    fi
    
    log "INFO" "Parsing configuration from YAML file: ${yaml_file}"

# Use yq to parse and set the global variables
    # Database Configuration
    POSTGRES_HOST=$(get_config_value "POSTGRES_HOST" ".global.external.db_host")
    POSTGRES_PORT=$(get_config_value "POSTGRES_PORT" ".global.external.db_port")
    POSTGRES_DB=$(get_config_value "POSTGRES_DB" ".global.external.db_name")
    POSTGRES_USER=$(get_config_value "POSTGRES_USER" ".global.external.db_username")
    POSTGRES_PASSWORD=$(get_config_value "POSTGRES_PASSWORD" ".global.external.db_password")

    # Container Registry Repository configuration
    PRIVATE_IMAGE_REPO=$(get_config_value "PRIVATE_IMAGE_REPO_URL" ".global.tibco.containerRegistry.url")
    PRIVATE_IMAGE_USERNAME=$(get_config_value "PRIVATE_IMAGE_USERNAME" ".global.tibco.containerRegistry.username")
    PRIVATE_IMAGE_PASSWORD=$(get_config_value "PRIVATE_IMAGE_PASSWORD" ".global.tibco.containerRegistry.password")
    PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO=$(get_config_value "PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO" ".global.tibco.containerRegistry.repository")

    # Helm Chart Repository configuration
    PRIVATE_CHART_REPO_NAME=$(get_config_value "PRIVATE_CHART_REPO_NAME" ".global.tibco.helm.repo")
    PRIVATE_CHART_REPO_URL=$(get_config_value "PRIVATE_CHART_REPO_URL" ".global.tibco.helm.url")
    PRIVATE_CHART_REPO_USERNAME=$(get_config_value "PRIVATE_CHART_REPO_USERNAME" ".global.tibco.helm.username")
    PRIVATE_CHART_REPO_PASSWORD=$(get_config_value "PRIVATE_CHART_REPO_PASSWORD" ".global.tibco.helm.password")
    PRIVATE_CHART_REPO_PATH=$(get_config_value "PRIVATE_CHART_REPO_PATH" ".global.tibco.helm.repositoryPath")

    # Storage and Ingress
    STORAGE_CLASS=$(get_config_value "STORAGE_CLASS" ".global.storageClass")
    INGRESS_CLASS=$(get_config_value "INGRESS_CLASS" ".global.ingressClass")

    # Email Configuration
    RUN_SMTP_VALIDATIONS=$(get_config_value "RUN_SMTP_VALIDATIONS" "true")
    SMTP_HOST=$(get_config_value "SMTP_HOST" ".global.external.emailServer.smtp.server")
    SMTP_PORT=$(get_config_value "SMTP_PORT" ".global.external.emailServer.smtp.port")
    SMTP_USER=$(get_config_value "SMTP_USER" ".global.external.emailServer.smtp.username")
    SMTP_PASSWORD=$(get_config_value "SMTP_PASSWORD" ".global.external.emailServer.smtp.password")
    ADMIN_EMAIL=$(get_config_value "ADMIN_EMAIL" ".global.external.admin.email")

    # Kubernetes Configuration
    NAMESPACE=$(get_config_value "NAMESPACE" ".global.tibco.namespace")
    INSTANCE_ID=$(get_config_value "INSTANCE_ID" ".global.tibco.controlPlaneInstanceId")
    SERVICE_ACCOUNT=$(get_config_value "SERVICE_ACCOUNT" ".global.tibco.serviceAccount")

    # Resource requirements
    REQUIRED_CPU=$(get_config_value "REQUIRED_CPU" ".global.resources.cpu")
    REQUIRED_MEMORY=$(get_config_value "REQUIRED_MEMORY" ".global.resources.memory")
    REQUIRED_STORAGE=$(get_config_value "REQUIRED_STORAGE" ".global.resources.storage")

}

# Load configuration only from user-provided files
load_config() {
    # Load default config (env file) provided by user
    if [[ -f "${DEFAULT_CONFIG_FILE}" ]]; then
        log "INFO" "Loading configuration from: ${DEFAULT_CONFIG_FILE}"
        source "${DEFAULT_CONFIG_FILE}"
    else
        log "ERROR" "Configuration file not found: ${DEFAULT_CONFIG_FILE}"
        exit 1
    fi

    # Load YAML config provided by user (required)
    if [[ -f "${YAML_CONFIG_FILE}" ]]; then
        parse_yaml_config "${YAML_CONFIG_FILE}" || {
            log "ERROR" "Failed to parse YAML configuration: ${YAML_CONFIG_FILE}"
            exit 1
        }
    else
        log "ERROR" "YAML configuration file not found: ${YAML_CONFIG_FILE}"
        exit 1
    fi
}

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    case ${level} in
        "ERROR")
            echo -e "${RED}[ERROR] ${message}${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN] ${message}${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO] ${message}${NC}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG] ${message}${NC}"
            ;;
    esac
}

# Record validation result
record_result() {
    local validation_id=$1
    local category=$2
    local description=$3
    local severity=$4
    local status=$5
    local details=$6
    
    VALIDATION_RESULTS+=("${validation_id}|${category}|${description}|${severity}|${status}|${details}")
    
    case ${severity} in
        "HIGH")
            if [[ "${status}" == "FAIL" ]]; then
                ((HIGH_SEVERITY_FAILURES++))
            fi
            ;;
        "MEDIUM")
            if [[ "${status}" == "FAIL" ]]; then
                ((MEDIUM_SEVERITY_FAILURES++))
            fi
            ;;
        "LOW")
            if [[ "${status}" == "FAIL" ]]; then
                ((LOW_SEVERITY_FAILURES++))
            fi
            ;;
    esac
}

# Check if kubectl is available and working
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log "ERROR" "kubectl is not installed or not in PATH"
        return 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log "ERROR" "Cannot connect to Kubernetes cluster ${EXPECTED_K8S_CLUSTER_NAME}"
        return 1
    fi

    if [[ -n "${EXPECTED_K8S_CLUSTER_NAME}" ]]; then
        local current_cluster
        current_cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | awk -F'/' '{print $NF}')
        if [[ "${current_cluster}" != "$EXPECTED_K8S_CLUSTER_NAME" ]]; then
            log "ERROR" "Connected to cluster '${current_cluster}', but expected '${EXPECTED_K8S_CLUSTER_NAME}'"
            return 1
        fi
    fi

    return 0
}

# Version comparison function
version_compare() {
    local version1=$1
    local operator=$2
    local version2=$3
    
    # Simple version comparison - assumes semantic versioning
    if [[ "${operator}" == "ge" ]]; then
        [[ "$(printf '%s\n' "${version2}" "${version1}" | sort -V | head -n1)" == "${version2}" ]]
    elif [[ "${operator}" == "le" ]]; then
        [[ "$(printf '%s\n' "${version1}" "${version2}" | sort -V | head -n1)" == "${version1}" ]]
    fi
}

# Validation 1: Kubernetes cluster version
validate_k8s_version() {
    local validation_id="1"
    local category="Infrastructure"
    local description="Kubernetes cluster must be within the supported version range"
    local severity="LOW"
    
    if [[ "${SKIP_LOW_SEVERITY}" == "true" ]]; then
        log "INFO" "Skipping validation ${validation_id} (LOW severity)"
        return 0
    fi
    
    log "INFO" "Running validation ${validation_id}: ${description}"
    
    local k8s_version
    if ! k8s_version=$(kubectl version 2>/dev/null | grep "Server Version" | awk '{print $3}' | sed 's/v//'); then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Cannot determine Kubernetes version"
        return 1
    fi
    
    if version_compare "${k8s_version}" "ge" "${MIN_K8S_VERSION}" && version_compare "${k8s_version}" "le" "${MAX_K8S_VERSION}"; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Kubernetes version ${k8s_version} is supported"
        log "INFO" "Kubernetes version $k8s_version is within supported range (${MIN_K8S_VERSION} - ${MAX_K8S_VERSION})"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Kubernetes version $k8s_version is not supported"
        log "WARN" "Kubernetes version $k8s_version is outside supported range (${MIN_K8S_VERSION} - ${MAX_K8S_VERSION})"
    fi
}

# Validation 2: Kubernetes cluster resources
validate_k8s_resources() {
    local validation_id="2"
    local category="Infrastructure"
    local description="Kubernetes Cluster must have resources (cpu, mem, storage) required for the deployment"
    local severity="LOW"

    if [[ "${SKIP_LOW_SEVERITY}" == "true" ]]; then
        log "INFO" "Skipping validation ${validation_id} (LOW severity)"
        return 0
    fi

    log "INFO" "Running validation ${validation_id}: ${description}"

    # Get and calculate resources
    local total_cpu
    local total_memory

    total_cpu=$(kubectl get nodes -o json | jq '[.items[].status.allocatable.cpu | if test("m$") then sub("m$";"") | tonumber / 1000 else tonumber end] | add')
    total_memory=$(kubectl get nodes -o json | jq '[.items[].status.allocatable.memory | if test("Ki$") then sub("Ki$";"") | tonumber / 1048576 elif test("Mi$") then sub("Mi$";"") | tonumber / 1024 elif test("Gi$") then sub("Gi$";"") | tonumber else 0 end] | add')

    local required_cpu_num=${REQUIRED_CPU//[!0-9.]/}
    local required_memory_num=${REQUIRED_MEMORY//[!0-9.]/}

    # Compare using awk for reliable floating point comparison
    local has_enough_resources
    has_enough_resources=$(awk -v cpu="$total_cpu" -v req_cpu="$required_cpu_num" -v mem="$total_memory" -v req_mem="$required_memory_num" 'BEGIN { print (cpu >= req_cpu && mem >= req_mem) ? 1 : 0 }')

    local total_cpu_int=$(awk 'BEGIN{print int('$total_cpu')}')
    local total_memory_int=$(awk 'BEGIN{print int('$total_memory')}')
    if [ "${has_enough_resources}" = "1" ]; then
        log "INFO" "Cluster has sufficient resources (CPU: ${total_cpu_int} , Memory: ${total_memory_int}Gi)"
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Sufficient resources available"
    else
        log "WARN" "Cluster may not have sufficient resources (Available - CPU: ${total_cpu_int} , Memory: ${total_memory_int}Gi, Required - CPU: ${required_cpu_num}, Memory: ${required_memory_num}Gi)"
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "WARN" "Insufficient resources"
    fi
}

# Validation 3: Database accessibility
validate_database_accessibility() {
    local validation_id="3"
    local category="Database"
    local description="Postgres database must be accessible from within the cluster"
    local severity="HIGH"
    
    log "INFO" "Running validation ${validation_id}: ${description}"
    
    if [[ -z "${POSTGRES_HOST}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Database configuration not provided"
        log "WARN" "Database configuration not provided, skipping validation"
        return 0
    fi
    
    # Create a test pod to check database connectivity
    local test_pod_name="db-connectivity-test-$(date +%s)"
    local test_result
    
    kubectl run "$test_pod_name" --image=postgres:13 --restart=Never --rm -i --quiet \
        --env="PGPASSWORD=${POSTGRES_PASSWORD}" \
        --command -- psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT 1;" \
        > /dev/null 2>&1 && test_result="success" || test_result="failed"
    
    if [[ "${test_result}" == "success" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Database is accessible"
        log "INFO" "Database connectivity test passed"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Database is not accessible"
        log "ERROR" "Database connectivity test failed"
    fi
}

# Validation 4: Database user permissions
validate_database_permissions() {
    local validation_id="4"
    local category="Database"
    local description="Database user provided must have the ability to create/update/delete databases and users"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${POSTGRES_HOST}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Database configuration not provided"
        log "WARN" "Database configuration not provided, skipping validation"
        return 0
    fi

    local test_pod_name="db-permissions-test-$(date +%s)"
    local test_db_name="test_db_$(date +%s)"
    local test_user_name="test_user_$(date +%s)"
    local sql_file="/tmp/validate_db_perm_${test_db_name}.sql"

    cat > "$sql_file" <<EOF
CREATE DATABASE $test_db_name;
CREATE USER $test_user_name WITH PASSWORD 'testpass';
GRANT ALL PRIVILEGES ON DATABASE $test_db_name TO $test_user_name;
REVOKE CONNECT ON DATABASE $test_db_name FROM public;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$test_db_name';
DROP DATABASE $test_db_name;
DROP USER $test_user_name;
EOF

    if kubectl run "${test_pod_name}" --image=postgres:13 --restart=Never --rm -i --quiet \
        --env="PGPASSWORD=${POSTGRES_PASSWORD}" \
        --command -- bash -c "cat > /tmp/test.sql && psql -h '${POSTGRES_HOST}' -p '${POSTGRES_PORT}' -U '${POSTGRES_USER}' -d '${POSTGRES_DB}' -f /tmp/test.sql" < "$sql_file" \
        --timeout=60s > /dev/null 2>&1; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Database user has required permissions"
        log "INFO" "Database user permissions test passed"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Database user lacks required permissions"
        log "ERROR" "Database user permissions test failed"
    fi

    rm -f "$sql_file"
}

# Validation 5: Service account existence
validate_service_account_exists() {
    local validation_id="5"
    local category="Access"
    local description="ServiceAccount '${SERVICE_ACCOUNT}' must exist in namespace '${NAMESPACE}'"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${SERVICE_ACCOUNT}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "ServiceAccount name not specified in configuration"
        log "ERROR" "ServiceAccount name not specified in configuration"
        return 1
    fi

    if kubectl get serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" > /dev/null 2>&1; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "ServiceAccount '${SERVICE_ACCOUNT}' exists"
        log "INFO" "ServiceAccount '${SERVICE_ACCOUNT}' exists in namespace '${NAMESPACE}'"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "ServiceAccount '${SERVICE_ACCOUNT}' does not exist"
        log "ERROR" "ServiceAccount '${SERVICE_ACCOUNT}' does not exist in namespace '${NAMESPACE}'"
    fi
}

# Validation 6: Private chart repo accessibility
validate_private_chart_repo() {
    local validation_id="6"
    local category="Private Repos"
    local description="If specified, private chart repo must be accessible from within the cluster"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${PRIVATE_CHART_REPO_URL}" || -z "${PRIVATE_CHART_REPO_NAME}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Private chart repo not specified"
        log "INFO" "Private chart repo not specified, skipping validation"
        return 0
    fi

    local FULL_REPO_URL
    if [[ -n "${PRIVATE_CHART_REPO_PATH}" && "${PRIVATE_CHART_REPO_PATH}" != "null" ]]; then
        FULL_REPO_URL="${PRIVATE_CHART_REPO_URL%/}/${PRIVATE_CHART_REPO_PATH}"
    else
        FULL_REPO_URL="${PRIVATE_CHART_REPO_URL}"
    fi

    if [[ "${FULL_REPO_URL}" == oci://* ]]; then
        # OCI registry: use helm registry login
        if helm registry login "${FULL_REPO_URL#oci://}" --username "${PRIVATE_CHART_REPO_USERNAME}" --password "${PRIVATE_CHART_REPO_PASSWORD}" > /dev/null 2>&1; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "OCI registry login successful"
            log "INFO" "OCI registry login successful for ${FULL_REPO_URL}"
        else
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "OCI registry login failed"
            log "ERROR" "OCI registry login failed for ${FULL_REPO_URL}"
        fi
    else
        # Standard Helm repo
        if kubectl run "chart-repo-test-$(date +%s)" --image=alpine/helm:latest --restart=Never --rm -i --quiet \
            --command -- helm repo add "${PRIVATE_CHART_REPO_NAME}" "${FULL_REPO_URL}" \
            --username "${PRIVATE_CHART_REPO_USERNAME}" --password "${PRIVATE_CHART_REPO_PASSWORD}" > /dev/null 2>&1; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Private chart repo is accessible"
            log "INFO" "Private chart repo accessibility test passed"
        else
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Private chart repo is not accessible"
            log "ERROR" "Private chart repo accessibility test failed"
        fi
    fi
}

# Validation 7: Charts availability in private repo
validate_charts_availability() {
    local validation_id="7"
    local category="Private Repos"
    local description="If specified, all charts for the release must be available in the private chart repo with required version"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${PRIVATE_CHART_REPO_URL}" || -z "${PRIVATE_CHART_REPO_NAME}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Private chart repo not specified"
        log "INFO" "Private chart repo not specified, skipping validation"
        return 0
    fi

   local artifacts_dir="${PRE_INSTALL_VALIDATION_SCRIPT_DIR}/../../artifacts"
   local charts_files
   local charts_list=()

   # Get RELEASE_VERSION from env file
   local RELEASE_VERSION
   RELEASE_VERSION=$(grep '^RELEASE_VERSION=' "${DEFAULT_CONFIG_FILE}" | cut -d'"' -f2)

   # Find all matching charts files
   charts_files=$(find "${artifacts_dir}" -type f -name "*-${RELEASE_VERSION}-charts.txt")

   if [[ -z "${charts_files}" ]]; then
       log "ERROR" "No charts files found for release version ${RELEASE_VERSION} in artifacts"
       record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No charts files found for release version ${RELEASE_VERSION} in artifacts"
       return 1
   fi

   # Read all chart entries from the found files
   while IFS= read -r charts_file; do
       while IFS= read -r chart_entry || [[ -n "${chart_entry}" ]]; do
           chart_entry=$(echo "${chart_entry}" | xargs) # Trim whitespace
           [[ -z "${chart_entry}" || "${chart_entry}" =~ ^# ]] && continue
           charts_list+=("${chart_entry}")
       done < "${charts_file}"
   done < <(echo "${charts_files}")

   REQUIRED_CHARTS=$(IFS=','; echo "${charts_list[*]}")

   if [[ -z "${REQUIRED_CHARTS}" ]]; then
           record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No charts found in chart list files"
           log "ERROR" "No charts found in chart list files"
           return 1
   fi


   if [[ -z "${REQUIRED_CHARTS}" ]]; then
      record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No required charts found for release version ${RELEASE_VERSION} in artifacts"
      return 1
   fi

   REQUIRED_CHARTS_ARRAY=()
       if [[ -n "${REQUIRED_CHARTS}" ]]; then
           IFS=',' read -ra REQUIRED_CHARTS_ARRAY <<< "${REQUIRED_CHARTS}"
       fi

    local FULL_REPO_URL
    if [[ -n "${PRIVATE_CHART_REPO_PATH}" && "${PRIVATE_CHART_REPO_PATH}" != "null" ]]; then
        FULL_REPO_URL="${PRIVATE_CHART_REPO_URL%/}/${PRIVATE_CHART_REPO_PATH}"
    else
        FULL_REPO_URL="${PRIVATE_CHART_REPO_URL}"
    fi

    IFS=',' read -ra REQUIRED_CHARTS_ARRAY <<< "${REQUIRED_CHARTS}"
    local missing_charts=()

    if [[ "${FULL_REPO_URL}" == oci://* ]]; then
        # OCI registry: login first
        if ! helm registry login "${FULL_REPO_URL#oci://}" --username "${PRIVATE_CHART_REPO_USERNAME}" --password "${PRIVATE_CHART_REPO_PASSWORD}" > /dev/null 2>&1; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "OCI registry login failed"
            log "ERROR" "OCI registry login failed for ${FULL_REPO_URL}"
            return 1
        fi

        for chart_entry in "${REQUIRED_CHARTS_ARRAY[@]}"; do
            local chart_name="${chart_entry%%:*}"
            local chart_version="${chart_entry##*:}"
            local oci_ref="${FULL_REPO_URL}/${chart_name}:${chart_version}"

            helm show chart "${oci_ref}" > /dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                missing_charts+=("${chart_name}:${chart_version}")
            fi
        done
    else
        # Standard Helm repo
        if ! helm repo list | grep -q "${PRIVATE_CHART_REPO_NAME}"; then
            helm repo add "${PRIVATE_CHART_REPO_NAME}" "${FULL_REPO_URL}" \
                --username "${PRIVATE_CHART_REPO_USERNAME}" --password "${PRIVATE_CHART_REPO_PASSWORD}" >/dev/null 2>&1
        fi
        helm repo update "${PRIVATE_CHART_REPO_NAME}" >/dev/null 2>&1

        for chart_entry in "${REQUIRED_CHARTS_ARRAY[@]}"; do
            local chart_name="${chart_entry%%:*}"
            local chart_version="${chart_entry##*:}"

            helm show chart "${PRIVATE_CHART_REPO_NAME}/${chart_name}" --version "${chart_version}" > /dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                missing_charts+=("${chart_name}:${chart_version}")
            fi
        done
    fi

    if [[ ${#missing_charts[@]} -eq 0 ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "All required charts and versions are available"
        log "INFO" "All required charts and versions found in private repo"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Missing charts/versions: ${missing_charts[*]}"
        log "ERROR" "Missing charts/versions in private repo: ${missing_charts[*]}"
    fi
}

# Validation 8: Private image repo accessibility
validate_private_image_repo() {
    local validation_id="8"
    local category="Private Repos"
    local description="Container image repo must be accessible"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${PRIVATE_IMAGE_REPO}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Private image repo not specified"
        log "INFO" "Private image repo not specified, skipping validation"
        return 0
    fi

    # Authenticate to the image repo
    if echo "${PRIVATE_IMAGE_PASSWORD}" | docker login "${PRIVATE_IMAGE_REPO}" --username "${PRIVATE_IMAGE_USERNAME}" --password-stdin > /dev/null 2>&1; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Docker login successful for image repo"
        log "INFO" "Docker login successful for image repo: ${PRIVATE_IMAGE_REPO}"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Docker login failed for image repo"
        log "ERROR" "Docker login failed for image repo: ${PRIVATE_IMAGE_REPO}"
    fi
}

# Validation 9: Images availability in private repo
validate_images_availability() {
    local validation_id="9"
    local category="Private Repos"
    local description="Required images must be available in the container registry repo"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO is not set"
        log "ERROR" "PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO is not set, cannot proceed with image validation"
        return 1
    fi

    local output
    output=$(docker manifest inspect "${PRIVATE_IMAGE_REPO}/${PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO}/dummy:latest" 2>&1)
    if echo "$output" | grep -q "unknown: Repository"; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Container registry repo '${PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO}' is not accessible"
        log "ERROR" "Container registry repo '${PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO}' is not accessible"
        return 1
    fi

    if [[ -z "${PRIVATE_IMAGE_REPO}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Private image repo not specified"
        log "INFO" "Private image repo not specified, skipping validation"
        return 0
    fi

    # Read RELEASE_VERSION from default config file
    local RELEASE_VERSION
    RELEASE_VERSION=$(grep '^RELEASE_VERSION=' "${DEFAULT_CONFIG_FILE}" | cut -d'"' -f2)

    # Find all matching image list files in artifacts subfolders
    local image_files
    local artifacts_dir="${PRE_INSTALL_VALIDATION_SCRIPT_DIR}/../../artifacts"
    image_files=$(find "${artifacts_dir}" -type f -name "*-${RELEASE_VERSION}-images.txt")

    if [[ -z "${image_files}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No image list files found for release version ${RELEASE_VERSION} in artifacts"
        log "ERROR" "No image list files found for release version ${RELEASE_VERSION} in artifacts"
        return 1
    fi

    # Read all images from the found files
    local required_images=()
    while IFS= read -r image_file; do
        while IFS= read -r image_tag || [[ -n "${image_tag}" ]]; do
            image_tag=$(echo "${image_tag}" | xargs) # Trim whitespace
            # Skip empty lines or comments
            [[ -z "${image_tag}" || "${image_tag}" =~ ^# ]] && continue
            required_images+=("${image_tag}")
        done < "${image_file}"
    done < <(echo "${image_files}")

    if [[ ${#required_images[@]} -eq 0 ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No images found in image list files"
        log "ERROR" "No images found in image list files"
        return 1
    fi

    local missing_images=()
    local temp_dir=$(mktemp -d)
    
    # Check images in parallel (up to 100 concurrent checks for faster validation)
    local max_jobs=100
    local total_images=${#required_images[@]}
    
    log "INFO" "Checking ${total_images} images in parallel (max ${max_jobs} concurrent checks)..."
    
    for image_tag in "${required_images[@]}"; do
        local full_image="${PRIVATE_IMAGE_REPO}/${PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO}/${image_tag}"
        (
            if ! docker manifest inspect "${full_image}" > /dev/null 2>&1; then
                echo "${image_tag}" >> "${temp_dir}/missing.txt"
            fi
        ) &
        
        # Wait when max concurrent jobs reached
        if (( $(jobs -r | wc -l) >= max_jobs )); then
            wait -n 2>/dev/null || true
        fi
    done
    wait  # Wait for all remaining jobs
    
    # Collect missing images
    if [[ -f "${temp_dir}/missing.txt" ]]; then
        while IFS= read -r missing_image; do
            missing_images+=("${missing_image}")
        done < "${temp_dir}/missing.txt"
    fi
    rm -rf "${temp_dir}"

    if [[ ${#missing_images[@]} -eq 0 ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "All required images and tags are available"
        log "INFO" "All required images and tags found in private registry"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Missing images/tags: ${missing_images[*]}"
        log "ERROR" "Missing images/tags in private registry: ${missing_images[*]}"
    fi
}

# Validation 10: Storage class availability
validate_storage_class() {
    local validation_id="10"
    local category="Storage"
    local description="StorageClass must be available and accessible"
    local severity="HIGH"
    
    log "INFO" "Running validation ${validation_id}: ${description}"
    
    if [[ -z "${STORAGE_CLASS}" ]]; then
        # Check for default storage class
        if kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' | grep -q .; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Default storage class is available"
            log "INFO" "Default storage class found"
        else
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No storage class specified and no default found"
            log "ERROR" "No storage class specified and no default storage class found"
        fi
    else
        if kubectl get storageclass "${STORAGE_CLASS}" > /dev/null 2>&1; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Storage class ${STORAGE_CLASS} is available"
            log "INFO" "Storage class ${STORAGE_CLASS} found"
        else
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Storage class ${STORAGE_CLASS} not found"
            log "ERROR" "Storage class ${STORAGE_CLASS} not found"
        fi
    fi
}

# Validation 11: Dynamic PVC creation
validate_dynamic_pvc() {
    local validation_id="11"
    local category="Storage"
    local description="Dynamic PVC creation must be allowed with the specified Storage Class"
    local severity="HIGH"

    log "INFO" "Running validation ${validation_id}: ${description}"

    local storage_class_to_test="${STORAGE_CLASS}"
    if [[ -z "${storage_class_to_test}" ]]; then
        storage_class_to_test=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    fi

    if [[ -z "${storage_class_to_test}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No storage class available for testing"
        log "ERROR" "No storage class available for PVC testing"
        return 1
    fi

    local test_pvc_name="test-pvc-$(date +%s)"
    local pvc_manifest="
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${test_pvc_name}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${storage_class_to_test}
  resources:
    requests:
      storage: 1Gi
"

    local pvc_status=""
    if echo "${pvc_manifest}" | kubectl apply -f - > /dev/null 2>&1; then
        local timeout=60
        local elapsed=0

        while [[ ${elapsed} -lt ${timeout} ]]; do
            pvc_status=$(kubectl get pvc "$test_pvc_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
            if [[ "${pvc_status}" == "Bound" ]]; then
                break
            fi
            sleep 5
            ((elapsed += 5))
        done
    else
        pvc_status="CreateFailed"
    fi

    # Always attempt to delete the test PVC at the end
    if kubectl get pvc "${test_pvc_name}" -n "${NAMESPACE}" &>/dev/null; then
        kubectl delete pvc "${test_pvc_name}" -n "${NAMESPACE}" > /dev/null 2>&1 || true
    fi

    if [[ "${pvc_status}" == "Bound" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Dynamic PVC creation successful"
        log "INFO" "Dynamic PVC creation test passed"
    elif [[ "${pvc_status}" == "CreateFailed" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Failed to create test PVC"
        log "ERROR" "Failed to create test PVC"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "PVC creation failed or timed out"
        log "ERROR" "Dynamic PVC creation test failed - PVC status: ${pvc_status:-empty}"
    fi
}

# Validation 12: Ingress class availability
validate_ingress_class() {
    local validation_id="12"
    local category="Ingress"
    local description="IngressClass must be available and accessible"
    local severity="HIGH"
    
    log "INFO" "Running validation ${validation_id}: ${description}"
    
    if [[ -z "${INGRESS_CLASS}" ]]; then
        # Check for default ingress class
        if kubectl get ingressclass -o jsonpath='{.items[?(@.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' | grep -q .; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Default ingress class is available"
            log "INFO" "Default ingress class found"
        else
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "No ingress class specified and no default found"
            log "ERROR" "No ingress class specified and no default ingress class found"
        fi
    else
        if kubectl get ingressclass "${INGRESS_CLASS}" > /dev/null 2>&1; then
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Ingress class $INGRESS_CLASS is available"
            log "INFO" "Ingress class ${INGRESS_CLASS} found"
        else
            record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Ingress class $INGRESS_CLASS not found"
            log "ERROR" "Ingress class ${INGRESS_CLASS} not found"
        fi
    fi
}

# Validation 13: SMTP accessibility
validate_smtp_accessibility() {
    local validation_id="13"
    local category="Email"
    local description="SMTP must be accessible from within the cluster"
    local severity="HIGH"

    if [[ "${RUN_SMTP_VALIDATIONS}" == "false" ]]; then
            log "INFO" "Skipping validation ${validation_id} because RUN_SMTP_VALIDATIONS is set to false"
            return 0
    fi
    
    log "INFO" "Running validation ${validation_id}: ${description}"
    
    if [[ -z "${SMTP_HOST}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "SMTP configuration not provided"
        log "WARN" "SMTP configuration not provided, skipping validation"
        return 0
    fi
    
    # Test SMTP connectivity using a test pod
    local test_pod_name="smtp-test-$(date +%s)"
    
    if kubectl run "${test_pod_name}" --image=alpine --restart=Never --rm -i --quiet \
        --command -- nc -z "${SMTP_HOST}" "${SMTP_PORT}" > /dev/null 2>&1; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "SMTP server is accessible"
        log "INFO" "SMTP connectivity test passed"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "SMTP server is not accessible"
        log "ERROR" "SMTP connectivity test failed"
    fi
}

# Validation 14: Email service permissions
validate_email_permissions() {
    local validation_id="14"
    local category="Email"
    local description="Email Service user provided must have the ability to send email"
    local severity="HIGH"

    if [[ "${RUN_SMTP_VALIDATIONS}" == "false" ]]; then
                log "INFO" "Skipping validation ${validation_id} because RUN_SMTP_VALIDATIONS is set to false"
                return 0
        fi

    log "INFO" "Running validation ${validation_id}: ${description}"

    if [[ -z "${SMTP_HOST}" ]] || [[ -z "${ADMIN_EMAIL}" ]]; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Email configuration not complete"
        log "WARN" "Email configuration not complete, skipping validation"
        return 0
    fi

    local test_pod_name="email-test-$(date +%s)"
    local email_test_script="/tmp/email_test.py"

    cat <<EOF > "$email_test_script"
import smtplib
from email.mime.text import MIMEText
import sys
import os

smtp_host = os.environ.get('SMTP_HOST')
smtp_port = int(os.environ.get('SMTP_PORT', 25))
smtp_user = os.environ.get('SMTP_USER')
smtp_pass = os.environ.get('SMTP_PASSWORD')
admin_email = os.environ.get('ADMIN_EMAIL')

try:
    server = smtplib.SMTP(smtp_host, smtp_port, timeout=10)
    msg = MIMEText('Control plane validation test email')
    msg['Subject'] = 'CP Validation Test'
    msg['From'] = smtp_user if smtp_user else 'validator@localhost'
    msg['To'] = admin_email

    server.sendmail(msg['From'], [admin_email], msg.as_string())
    server.quit()
except Exception as e:
    sys.exit(1)
EOF

    if kubectl run "${test_pod_name}" --image=python:3.9-alpine --restart=Never --rm -i --quiet \
        --env="SMTP_HOST=${SMTP_HOST}" --env="SMTP_PORT=${SMTP_PORT}" \
        --env="SMTP_USER=${SMTP_USER}" --env="SMTP_PASSWORD=${SMTP_PASSWORD}" \
        --env="ADMIN_EMAIL=${ADMIN_EMAIL}" \
        --command -- sh -c "cat > /tmp/email_test.py && python3 /tmp/email_test.py" < "${email_test_script}" > /dev/null 2>&1; then
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "Email service authentication successful"
        log "INFO" "Email service permissions test passed"
    else
        record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Email service authentication failed"
        log "ERROR" "Email service user permissions test failed"
    fi

    rm -f "${email_test_script}"
}

# Post-install validation functions (optional)
validate_admin_subscription() {
    local validation_id="P1"
    local category="Access"
    local description="Admin subscription must be successfully created"
    local severity="HIGH"
    
    log "INFO" "Running post-install validation ${validation_id}: ${description}"
    
    # This would typically check if the admin subscription exists in the system
    # Implementation depends on the specific control plane APIs
    record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Post-install validation - requires CP-specific implementation"
    log "INFO" "Post-install validation requires control plane-specific implementation"
}

validate_admin_invitation() {
    local validation_id="P2"
    local category="Email"
    local description="Admin invitation must be successfully sent"
    local severity="HIGH"
    
    log "INFO" "Running post-install validation ${validation_id}: ${description}"
    
    # This would typically check if the admin invitation email was sent successfully
    # Implementation depends on the specific control plane APIs
    record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Post-install validation - requires CP-specific implementation"
    log "INFO" "Post-install validation requires control plane-specific implementation"
}

validate_endpoint_accessibility() {
    local validation_id="P3"
    local category="Ingress"
    local description="Tunnel and Router endpoints must be accessible outside the cluster over FQDN"
    local severity="MEDIUM"
    
    if [[ "${SKIP_MEDIUM_SEVERITY}" == "true" ]]; then
        log "INFO" "Skipping validation ${validation_id} (MEDIUM severity)"
        return 0
    fi
    
    log "INFO" "Running post-install validation ${validation_id}: ${description}"
    
    # This would typically test external endpoint accessibility
    # Implementation depends on the specific control plane configuration
    record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Post-install validation - requires CP-specific implementation"
    log "INFO" "Post-install validation requires control plane-specific implementation"
}

validate_tls_endpoints() {
    local validation_id="P4"
    local category="Ingress"
    local description="Tunnel and Router endpoints must be present secure (TLS) endpoints"
    local severity="MEDIUM"
    
    if [[ "${SKIP_MEDIUM_SEVERITY}" == "true" ]]; then
        log "INFO" "Skipping validation ${validation_id} (MEDIUM severity)"
        return 0
    fi
    
    log "INFO" "Running post-install validation ${validation_id}: ${description}"
    
    # This would typically test TLS configuration of endpoints
    # Implementation depends on the specific control plane configuration
    record_result "${validation_id}" "${category}" "${description}" "${severity}" "SKIP" "Post-install validation - requires CP-specific implementation"
    log "INFO" "Post-install validation requires control plane-specific implementation"
}

# Generate validation report
generate_report() {
    log "INFO" "Generating validation report"
    
    local report_file="${PRE_INSTALL_VALIDATION_SCRIPT_DIR}/cp_validation_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "${report_file}" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Control Plane Installation Prerequisite Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f5f5f5; padding: 20px; border-radius: 5px; }
        .summary { background-color: #e7f3ff; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .validation { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; }
        .pass { border-left-color: #4CAF50; background-color: #f1f8e9; }
        .fail { border-left-color: #f44336; background-color: #ffebee; }
        .warn { border-left-color: #ff9800; background-color: #fff3e0; }
        .skip { border-left-color: #9e9e9e; background-color: #f5f5f5; }
        .high { font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Control Plane Installation Prerequisite Validation Report</h1>
        <p>Generated on: $(date)</p>
        <p>Configuration: $DEFAULT_CONFIG_FILE</p>
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>High Severity Failures:</strong> $HIGH_SEVERITY_FAILURES</p>
        <p><strong>Medium Severity Failures:</strong> $MEDIUM_SEVERITY_FAILURES</p>
        <p><strong>Low Severity Failures:</strong> $LOW_SEVERITY_FAILURES</p>
        <p><strong>Total Validations:</strong> ${#VALIDATION_RESULTS[@]}</p>
    </div>
    
    <h2>Validation Results</h2>
    <table>
        <tr>
            <th>ID</th>
            <th>Category</th>
            <th>Description</th>
            <th>Severity</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
EOF
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r validation_id category description severity status details <<< "${result}"
        local css_class=""
        
        case ${status} in
            "PASS") css_class="pass" ;;
            "FAIL") css_class="fail" ;;
            "WARN") css_class="warn" ;;
            "SKIP") css_class="skip" ;;
        esac
        
        cat >> "${report_file}" << EOF
        <tr class="$css_class">
            <td>$validation_id</td>
            <td>$category</td>
            <td>$description</td>
            <td class="${severity,,}">$severity</td>
            <td>$status</td>
            <td>$details</td>
        </tr>
EOF
    done
    
    cat >> "${report_file}" << EOF
    </table>
    
    <h2>Recommendations</h2>
    <ul>
EOF
    
    if [[ ${HIGH_SEVERITY_FAILURES} -gt 0 ]]; then
        cat >> "${report_file}" << EOF
        <li><strong>CRITICAL:</strong> $HIGH_SEVERITY_FAILURES high severity validation(s) failed. Control plane installation will likely fail. Please address these issues before proceeding.</li>
EOF
    fi
    
    if [[ ${MEDIUM_SEVERITY_FAILURES} -gt 0 ]]; then
        cat >> "${report_file}" << EOF
        <li><strong>WARNING:</strong> $MEDIUM_SEVERITY_FAILURES medium severity validation(s) failed. Control plane installation may succeed but functionality may be limited.</li>
EOF
    fi
    
    if [[ ${LOW_SEVERITY_FAILURES} -gt 0 ]]; then
        cat >> "${report_file}" << EOF
        <li><strong>INFO:</strong> $LOW_SEVERITY_FAILURES low severity validation(s) failed. These are informational and should not block installation.</li>
EOF
    fi
    
    if [[ ${HIGH_SEVERITY_FAILURES} -eq 0 ]] && [[ ${MEDIUM_SEVERITY_FAILURES} -eq 0 ]] && [[ ${LOW_SEVERITY_FAILURES} -eq 0 ]]; then
        cat >> "${report_file}" << EOF
        <li><strong>SUCCESS:</strong> All validations passed. The cluster appears ready for control plane installation.</li>
EOF
    fi
    
    cat >> "${report_file}" << EOF
    </ul>
    
    <p><em>For detailed logs, please check: $LOG_FILE</em></p>
</body>
</html>
EOF
    
    log "INFO" "Validation report generated: ${report_file}"
    echo -e "${GREEN}Validation report generated: ${report_file}${NC}"
}

# Main execution function
main() {
    echo -e "${BLUE}Control Plane Installation Prerequisite Validation Script${NC}"
    echo -e "${BLUE}=========================================================${NC}"

    # Parse command line arguments
    parse_args "$@"

# Prompt user for YAML config file
    read -p "Enter YAML configuration file name [platform_base_values.yaml]: " user_yaml_file
    YAML_CONFIG_FILE="${user_yaml_file:-platform_base_values.yaml}"

    # Load configuration
    load_config || {
        log "ERROR" "Failed to load configuration"
        exit 1
    }

    # Initialize log file
    log "INFO" "Starting control plane prerequisite validation"
    log "INFO" "Namespace: ${NAMESPACE}"

    # Check prerequisites
    if ! check_kubectl; then
        log "ERROR" "Prerequisites check failed"
        exit 1
    fi

    # Run all validations - errors won't stop execution
    validate_k8s_version || true
    validate_k8s_resources || true
    validate_database_accessibility || true
    validate_database_permissions || true
    validate_service_account_exists || true
    validate_private_chart_repo || true
    validate_charts_availability || true
    validate_private_image_repo || true
    validate_images_availability || true
    validate_storage_class || true
    validate_dynamic_pvc || true
    validate_ingress_class || true
    validate_smtp_accessibility || true
    validate_email_permissions || true

    # Run post-install validations if requested
    if [[ "${VALIDATE_POST_INSTALL}" == "true" ]]; then
        log "INFO" "Running post-install validations"
        validate_admin_subscription || true
        validate_admin_invitation || true
        validate_endpoint_accessibility || true
        validate_tls_endpoints || true
    fi

    # Generate report
    generate_report

    # Print summary
    echo -e "\n${BLUE}Validation Summary:${NC}"
    echo -e "High Severity Failures: ${RED}${HIGH_SEVERITY_FAILURES}${NC}"
    echo -e "Medium Severity Failures: ${YELLOW}${MEDIUM_SEVERITY_FAILURES}${NC}"
    echo -e "Low Severity Failures: ${YELLOW}${LOW_SEVERITY_FAILURES}${NC}"
    echo -e "Total Validations: ${GREEN}${#VALIDATION_RESULTS[@]}${NC}"

    # Set exit code based on high severity failures
    if [[ ${HIGH_SEVERITY_FAILURES} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Execute main function with all arguments
main "$@"