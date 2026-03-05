#!/bin/bash

# sync-charts.sh
#
# Pull and push Helm charts listed in `*-charts.txt` files.
# This script is non-interactive and driven by environment variables.
#
# Helm Version Requirements:
#   - Helm v3.17.0+: Supports both OCI registry and ChartMuseum (cm-push plugin)
#   - Helm v4.0.0+: Supports OCI registry only (cm-push plugin not compatible)
#
# Required Environment Variables:
#   SOURCE_REPO_NAME      - Name of the source Helm repository (checked/added to helm repos)
#   RELEASE_VERSION       - Release version in <major>.<minor>.<patch> format
#   TARGET_REPO_URL       - Target repository URL (oci:// for OCI registry, otherwise ChartMuseum)
#
# Optional Environment Variables:
#   CAPABILITY_NAME       - If set, only sync charts from <CAPABILITY_NAME>-<RELEASE_VERSION>-charts.txt
#   TARGET_REPO_USERNAME  - Username for target repository authentication
#   TARGET_REPO_PASSWORD  - Password for target repository authentication
#   TARGET_REPO_NAME      - Helm repo name for ChartMuseum target (ignored for OCI)
#   TARGET_REPO_INSECURE  - If "true", use --plain-http for OCI registry (default: false)
#   WRITE_SCRIPT_LOGS_TO_FILE - If "true", write logs to file (default: false)
#   MAX_RETRY             - Number of retries for pull/push operations (default: 0, no retry)
#   WAIT_BEFORE_RETRY     - Seconds to wait before retry (default: 0, no wait)
#
# Script behavior:
# - Source repo: checks if SOURCE_REPO_NAME exists in helm repos; if not, adds public TIBCO repo
# - Charts: reads from ../../artifacts directory based on RELEASE_VERSION (and optionally CAPABILITY_NAME)
# - Target: detects OCI vs ChartMuseum based on TARGET_REPO_URL prefix
# - Cleanup: always cleans up temp directory after execution

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="$SCRIPT_DIR/temp_charts"
ARTIFACTS_DIR="$SCRIPT_DIR/../../artifacts"
DEFAULT_SOURCE_REPO_URL="https://tibcosoftware.github.io/tp-helm-charts"

# Retry configuration (from environment variables)
MAX_RETRY="${MAX_RETRY:-0}"
WAIT_BEFORE_RETRY="${WAIT_BEFORE_RETRY:-0}"

# Internal variables
INPUT_SOURCES=()
CHART_NAMES=()
CHART_VERSIONS=()
TARGET_TYPE=""
CHARTMUSEUM_REPO_NAME=""
DOWNLOAD_DIR=""
LOG_FILE=""
WRITE_LOGS="false"
HELM_MAJOR_VERSION=0

# Statistics tracking
PULLED_COUNT=0
FAILED_PULL_COUNT=0
FAILED_PULL_CHARTS=()
PUSHED_COUNT=0
FAILED_PUSH_COUNT=0
FAILED_PUSH_CHARTS=()

# Initialize logging
init_logging() {
    if [[ "${WRITE_SCRIPT_LOGS_TO_FILE:-false}" == "true" ]]; then
        LOG_FILE="$SCRIPT_DIR/chart_sync_$(date +%Y%m%d_%H%M%S).log"
        WRITE_LOGS="true"
        echo "Logging to file: $LOG_FILE"
    fi
}

# Function to print colored output
print_status() {
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_success() {
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

print_warning() {
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

print_error() {
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

# Function to log command output
log_output() {
    if [[ "$WRITE_LOGS" == "true" ]]; then
        tee -a "$LOG_FILE"
    else
        cat
    fi
}

# Validate required environment variables
validate_environment() {
    print_status "Validating environment variables..."

    if [[ -z "$SOURCE_REPO_NAME" ]]; then
        print_error "SOURCE_REPO_NAME environment variable is required"
        exit 1
    fi

    if [[ -z "$RELEASE_VERSION" ]]; then
        print_error "RELEASE_VERSION environment variable is required"
        exit 1
    fi

    if [[ ! "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "RELEASE_VERSION must be in <major>.<minor>.<patch> format (e.g., 1.15.0)"
        print_error "Provided: $RELEASE_VERSION"
        exit 1
    fi

    if [[ -z "$TARGET_REPO_URL" ]]; then
        print_error "TARGET_REPO_URL environment variable is required"
        exit 1
    fi

    print_success "Environment variables validated"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v helm >/dev/null 2>&1; then
        print_error "helm is not installed. Please install Helm and try again."
        exit 1
    fi

    local helm_ver_short
    local helm_ver
    local helm_major
    local helm_minor

    helm_ver_short=$(helm version --short 2>/dev/null || true)
    helm_ver=$(echo "$helm_ver_short" | sed -n 's/.*v\([0-9][0-9]*\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2 \3/p')

    if [[ -z "$helm_ver" ]]; then
        print_error "Unable to detect Helm version. Please ensure Helm v3.17.0+ is installed."
        exit 1
    fi

    read -r helm_major helm_minor _ <<< "$helm_ver"

    # Store major version globally for later checks
    HELM_MAJOR_VERSION=$helm_major

    if (( helm_major < 3 )); then
        print_error "Helm v3.17.0+ or v4.0.0+ is required. Detected: $helm_ver_short"
        exit 1
    fi

    # For Helm v3, require minimum v3.17.0
    if (( helm_major == 3 )) && (( helm_minor < 17 )); then
        print_error "Helm v3.17.0+ is required. Detected: $helm_ver_short"
        exit 1
    fi

    print_success "Prerequisites check passed (Helm $helm_ver_short)"
}

# Generic function to ensure a Helm repository exists and is updated
# Arguments:
#   $1 - repo_name
#   $2 - repo_url
#   $3 - repo_type ("source" or "target") - for logging
#   $4 - error_on_url_mismatch ("true" or "false")
#   $5 - username (optional)
#   $6 - password (optional)
ensure_helm_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_type="$3"
    local error_on_url_mismatch="$4"
    local username="${5:-}"
    local password="${6:-}"

    print_status "Setting up $repo_type repository: $repo_name"

    local existing_url=""
    if helm repo list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$repo_name"; then
        existing_url=$(helm repo list 2>/dev/null | awk -v name="$repo_name" '$1 == name {print $2}')
        print_status "Repository '$repo_name' already exists with URL: $existing_url"

        # Check URL mismatch if required
        if [[ "$error_on_url_mismatch" == "true" && "$existing_url" != "$repo_url" ]]; then
            print_error "Repository '$repo_name' exists but URL mismatch!"
            print_error "  Existing URL: $existing_url"
            print_error "  Provided URL: $repo_url"
            exit 1
        fi

        # Update existing repository
        print_status "Updating existing $repo_type repository..."
        helm repo update "$repo_name" 2>&1 | log_output
        local update_status=${PIPESTATUS[0]}
        if [ $update_status -eq 0 ]; then
            print_success "Repository '$repo_name' updated"
        else
            if [[ "$repo_type" == "source" ]]; then
                print_error "Failed to update $repo_type repository"
                exit 1
            else
                print_warning "Failed to update $repo_type repository, continuing..."
            fi
        fi
        return 0
    fi

    # Add new repository
    print_status "Adding $repo_type repository '$repo_name' with URL: $repo_url"

    local add_args=("repo" "add" "$repo_name" "$repo_url")
    if [[ -n "$username" && -n "$password" ]]; then
        add_args+=("--username" "$username" "--password" "$password")
    fi

    helm "${add_args[@]}" 2>&1 | log_output
    local add_status=${PIPESTATUS[0]}

    if [ $add_status -eq 0 ]; then
        print_success "Repository '$repo_name' added"
        helm repo update "$repo_name" 2>&1 | log_output
        local update_status=${PIPESTATUS[0]}
        if [ $update_status -eq 0 ]; then
            print_success "Repository '$repo_name' updated"
        else
            print_error "Failed to update $repo_type repository"
            exit 1
        fi
    else
        print_error "Failed to add $repo_type repository"
        exit 1
    fi
}

# Setup source repository
setup_source_repo() {
    ensure_helm_repo "$SOURCE_REPO_NAME" "$DEFAULT_SOURCE_REPO_URL" "source" "false"
}

# Select charts based on RELEASE_VERSION and optional CAPABILITY_NAME
select_charts() {
    print_status "Selecting charts for release version: $RELEASE_VERSION"

    if [[ ! -d "$ARTIFACTS_DIR" ]]; then
        print_error "Artifacts directory not found: $ARTIFACTS_DIR"
        print_error "Please clone the public repo: https://github.com/TIBCOSoftware/tp-helm-charts"
        exit 1
    fi

    INPUT_SOURCES=()

    if [[ -n "$CAPABILITY_NAME" ]]; then
        print_status "Filtering by capability: $CAPABILITY_NAME"
        local expected_file="$ARTIFACTS_DIR/$CAPABILITY_NAME/$CAPABILITY_NAME-${RELEASE_VERSION}-charts.txt"

        if [[ -f "$expected_file" ]]; then
            INPUT_SOURCES+=("$expected_file")
            print_status "Found charts file: $expected_file"
        else
            print_error "Charts file not found: $expected_file"
            exit 1
        fi
    else
        print_status "Searching for all *-${RELEASE_VERSION}-charts.txt files..."
        while IFS= read -r -d '' f; do
            INPUT_SOURCES+=("$f")
        done < <(find "$ARTIFACTS_DIR" -type f -name "*-${RELEASE_VERSION}-charts.txt" -print0 2>/dev/null)

        if [ ${#INPUT_SOURCES[@]} -eq 0 ]; then
            print_error "No matching *-${RELEASE_VERSION}-charts.txt files found under $ARTIFACTS_DIR"
            exit 1
        fi
    fi

    print_success "Found ${#INPUT_SOURCES[@]} chart list file(s)"
}

# Function to read charts from charts.txt file
read_charts_list() {
    local src
    local line
    local chart_name
    local chart_version

    print_status "Reading charts list from input source(s):"

    for src in "${INPUT_SOURCES[@]}"; do
        print_status "  - $src"
        if [[ ! -f "$src" ]]; then
            print_error "Charts file $src not found!"
            exit 1
        fi
    done

    # Read charts into arrays
    CHART_NAMES=()
    CHART_VERSIONS=()

    for src in "${INPUT_SOURCES[@]}"; do
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ -z "$line" ]] || [[ "$line" =~ ^#.* ]]; then
                continue
            fi

            if [[ "$line" != *":"* ]]; then
                print_warning "Skipping invalid chart entry (expected <chart-name>:<version>): $line"
                continue
            fi

            chart_name="${line%%:*}"
            chart_version="${line#*:}"

            if [[ -z "$chart_name" || -z "$chart_version" ]]; then
                print_warning "Skipping invalid chart entry (missing chart name or version): $line"
                continue
            fi

            CHART_NAMES+=("$chart_name")
            CHART_VERSIONS+=("$chart_version")
        done < "$src"
    done

    if [ ${#CHART_NAMES[@]} -eq 0 ]; then
        print_error "No charts found in input files"
        return 1
    fi

    print_status "Found ${#CHART_NAMES[@]} chart(s) to process:"
    for i in "${!CHART_NAMES[@]}"; do
        print_status "  - ${CHART_NAMES[$i]}:${CHART_VERSIONS[$i]}"
    done

    return 0
}

# Function to pull Helm charts
pull_charts() {
    print_status "Pulling Helm charts from $SOURCE_REPO_NAME..."

    # Calculate total attempts (1 initial + MAX_RETRY retries)
    local max_attempts=$((1 + MAX_RETRY))

    # Create download directory
    mkdir -p "$TEMP_DIR/downloaded_charts"
    cd "$TEMP_DIR/downloaded_charts"

    # Store the absolute path for later use
    DOWNLOAD_DIR=$(pwd)

    for i in "${!CHART_NAMES[@]}"; do
        local chart_name="${CHART_NAMES[$i]}"
        local chart_version="${CHART_VERSIONS[$i]}"
        local chart_ref="$chart_name:$chart_version"

        local attempt=1
        local success=false

        while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
            if [ $max_attempts -gt 1 ]; then
                print_status "Pulling $chart_ref (attempt $attempt/$max_attempts)..."
            else
                print_status "Pulling $chart_ref..."
            fi

            helm pull "$SOURCE_REPO_NAME/$chart_name" --version "$chart_version" 2>&1 | log_output
            local pull_status=${PIPESTATUS[0]}

            if [ $pull_status -eq 0 ]; then
                print_success "Successfully pulled $chart_ref"
                ((PULLED_COUNT++))
                success=true
            else
                print_warning "Failed to pull $chart_ref on attempt $attempt"
                if [ $attempt -lt $max_attempts ] && [ "$WAIT_BEFORE_RETRY" -gt 0 ]; then
                    print_status "Retrying in $WAIT_BEFORE_RETRY seconds..."
                    sleep "$WAIT_BEFORE_RETRY"
                fi
            fi

            ((attempt++))
        done

        if [ "$success" = false ]; then
            print_error "Failed to pull $chart_ref after $max_attempts attempt(s)"
            ((FAILED_PULL_COUNT++))
            FAILED_PULL_CHARTS+=("$chart_ref")
        fi
    done

    print_status "Pull Summary: $PULLED_COUNT succeeded, $FAILED_PULL_COUNT failed"

    # Return 0 for success, 1 for any failures (bash return codes must be 0-255)
    [ $FAILED_PULL_COUNT -eq 0 ]
}

# Ensure helm cm-push plugin is available (for ChartMuseum)
ensure_helm_cm_push_available() {
    # Helm v4 does not support cm-push plugin
    if (( HELM_MAJOR_VERSION >= 4 )); then
        print_error "ChartMuseum (cm-push) is not supported with Helm v4."
        print_error "Helm v4 only supports OCI registries. Use TARGET_REPO_URL=oci://..."
        print_error "For ChartMuseum support, use Helm v3.17.0+"
        exit 1
    fi

    # Check if plugin is listed
    if ! helm plugin list 2>/dev/null | grep -qE '(^|[[:space:]])cm-push([[:space:]]|$)'; then
        print_error "Required Helm plugin 'helm-push' (cm-push) is not installed."
        print_error "Install it with: helm plugin install https://github.com/chartmuseum/helm-push"
        exit 1
    fi

    # Verify plugin actually works (may need reinstall after Helm upgrade)
    if ! helm cm-push --help &>/dev/null; then
        print_error "Helm plugin 'cm-push' is installed but not working."
        print_error "Try reinstalling: helm plugin uninstall cm-push && helm plugin install https://github.com/chartmuseum/helm-push"
        exit 1
    fi
}

# Setup target repository based on TARGET_REPO_URL
setup_target_repo() {
    print_status "Setting up target repository..."

    # Detect target type based on URL prefix
    if [[ "$TARGET_REPO_URL" == oci://* ]]; then
        TARGET_TYPE="oci"
        print_status "Target type: OCI registry"
        setup_oci_target
    else
        TARGET_TYPE="chartmuseum"
        print_status "Target type: ChartMuseum"
        setup_chartmuseum_target
    fi
}

# Setup OCI target
setup_oci_target() {
    print_status "Configuring OCI target: $TARGET_REPO_URL"

    # Check if insecure mode is enabled
    if [[ "${TARGET_REPO_INSECURE:-false}" == "true" ]]; then
        print_status "Insecure mode enabled (using --plain-http for HTTP registry)"
    fi

    # Login to OCI registry if credentials provided
    if [[ -n "$TARGET_REPO_USERNAME" && -n "$TARGET_REPO_PASSWORD" ]]; then
        # Extract registry host from oci:// URL
        local oci_registry="${TARGET_REPO_URL#oci://}"
        oci_registry="${oci_registry%%/*}"

        print_status "Logging in to OCI registry: $oci_registry"

        local login_args=("registry" "login" "$oci_registry" "--username" "$TARGET_REPO_USERNAME" "--password-stdin")
        if [[ "${TARGET_REPO_INSECURE:-false}" == "true" ]]; then
            login_args+=("--plain-http")
        fi

        echo "$TARGET_REPO_PASSWORD" | helm "${login_args[@]}" 2>&1 | log_output
        local login_status=${PIPESTATUS[0]}
        if [ $login_status -eq 0 ]; then
            print_success "Successfully logged in to OCI registry"
        else
            print_error "Failed to login to OCI registry"
            exit 1
        fi
    else
        print_status "Using OCI registry without authentication"
    fi
}

# Setup ChartMuseum target
setup_chartmuseum_target() {
    ensure_helm_cm_push_available

    # Determine repo name
    if [[ -z "$TARGET_REPO_NAME" ]]; then
        CHARTMUSEUM_REPO_NAME="target-repo-temp"
        print_status "TARGET_REPO_NAME not provided, using temporary name: $CHARTMUSEUM_REPO_NAME"
    else
        CHARTMUSEUM_REPO_NAME="$TARGET_REPO_NAME"
    fi

    ensure_helm_repo "$CHARTMUSEUM_REPO_NAME" "$TARGET_REPO_URL" "target" "true" "$TARGET_REPO_USERNAME" "$TARGET_REPO_PASSWORD"
}

# Generic function to push a single chart with retry logic
# Arguments:
#   $1 - chart_package (path to .tgz file)
#   $2 - push_command (the helm command to use: "helm push" or "helm cm-push")
#   $3 - push_target (TARGET_REPO_URL for OCI, CHARTMUSEUM_REPO_NAME for ChartMuseum)
push_chart_with_retry() {
    local chart_package="$1"
    local push_command="$2"
    local push_target="$3"

    local chart_filename
    chart_filename=$(basename "$chart_package")

    # Calculate total attempts (1 initial + MAX_RETRY retries)
    local max_attempts=$((1 + MAX_RETRY))
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        if [ $max_attempts -gt 1 ]; then
            print_status "Pushing $chart_filename (attempt $attempt/$max_attempts)..."
        else
            print_status "Pushing $chart_filename..."
        fi

        $push_command "$chart_package" "$push_target" 2>&1 | log_output
        local push_status=${PIPESTATUS[0]}

        if [ $push_status -eq 0 ]; then
            print_success "Successfully pushed $chart_filename"
            ((PUSHED_COUNT++))
            success=true
        else
            print_warning "Failed to push $chart_filename on attempt $attempt"
            if [ $attempt -lt $max_attempts ] && [ "$WAIT_BEFORE_RETRY" -gt 0 ]; then
                print_status "Retrying in $WAIT_BEFORE_RETRY seconds..."
                sleep "$WAIT_BEFORE_RETRY"
            fi
        fi

        ((attempt++))
    done

    if [ "$success" = false ]; then
        print_error "Failed to push $chart_filename after $max_attempts attempt(s)"
        ((FAILED_PUSH_COUNT++))
        FAILED_PUSH_CHARTS+=("$chart_filename")
        return 1
    fi

    return 0
}

# Generic function to push all charts
# Arguments:
#   $1 - target_description (for logging)
#   $2 - push_command
#   $3 - push_target
push_charts() {
    local target_description="$1"
    local push_command="$2"
    local push_target="$3"

    print_status "Pushing charts to $target_description"

    cd "$DOWNLOAD_DIR" || {
        print_error "Failed to change to download directory: $DOWNLOAD_DIR"
        return 1
    }

    local chart_packages=()
    while IFS= read -r -d '' file; do
        chart_packages+=("$file")
    done < <(find . -name "*.tgz" -type f -print0 2>/dev/null)

    if [ ${#chart_packages[@]} -eq 0 ]; then
        print_warning "No downloaded charts found to push"
        return 1
    fi

    for chart_package in "${chart_packages[@]}"; do
        push_chart_with_retry "$chart_package" "$push_command" "$push_target"
    done

    print_status "Push Summary: $PUSHED_COUNT succeeded, $FAILED_PUSH_COUNT failed"

    # Return 0 for success, 1 for any failures (bash return codes must be 0-255)
    [ $FAILED_PUSH_COUNT -eq 0 ]
}

# Push charts to OCI registry
push_to_oci() {
    local push_cmd="helm push"
    if [[ "${TARGET_REPO_INSECURE:-false}" == "true" ]]; then
        push_cmd="helm push --plain-http"
    fi
    push_charts "OCI registry: $TARGET_REPO_URL" "$push_cmd" "$TARGET_REPO_URL"
}

# Push charts to ChartMuseum
push_to_chartmuseum() {
    push_charts "ChartMuseum: $TARGET_REPO_URL" "helm cm-push" "$CHARTMUSEUM_REPO_NAME"
}

# Cleanup temporary files (always runs)
cleanup() {
    print_status "Cleaning up..."

    # Always cleanup temp directory (using absolute path)
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_success "Cleaned up temporary directory: $TEMP_DIR"
    fi

    # Remove temporary target repo if we created one
    if [[ "$CHARTMUSEUM_REPO_NAME" == "target-repo-temp" ]]; then
        if helm repo list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "target-repo-temp"; then
            helm repo remove target-repo-temp 2>/dev/null || true
            print_status "Removed temporary target repository"
        fi
    fi
}

# Show summary
show_summary() {
    echo ""
    print_status "========================================="
    print_status "Chart Sync Summary"
    print_status "========================================="
    print_status "Source Repository: $SOURCE_REPO_NAME"
    print_status "Release Version: $RELEASE_VERSION"
    if [[ -n "$CAPABILITY_NAME" ]]; then
        print_status "Capability: $CAPABILITY_NAME"
    fi
    print_status "Target: $TARGET_REPO_URL"
    if [[ "$TARGET_TYPE" == "chartmuseum" ]]; then
        print_status "Target Repo Name: $CHARTMUSEUM_REPO_NAME"
    fi
    print_status "-----------------------------------------"
    print_status "Pull Statistics:"
    print_status "  Number of Charts pulled successfully: $PULLED_COUNT"
    if [ $FAILED_PULL_COUNT -gt 0 ]; then
        print_status "  Number of Charts failed to pull: $FAILED_PULL_COUNT"
        print_status "  Failed Charts:"
        for chart in "${FAILED_PULL_CHARTS[@]}"; do
            print_error "    - $chart"
        done
    fi
    print_status "-----------------------------------------"
    print_status "Push Statistics:"
    print_status "  Number of Charts pushed successfully: $PUSHED_COUNT"
    if [ $FAILED_PUSH_COUNT -gt 0 ]; then
        print_status "  Number of Charts failed to push: $FAILED_PUSH_COUNT"
        print_status "  Failed Charts:"
        for chart in "${FAILED_PUSH_CHARTS[@]}"; do
            print_error "    - $chart"
        done
    fi
    print_status "-----------------------------------------"
    if [[ "$WRITE_LOGS" == "true" ]]; then
        print_status "Log file: $LOG_FILE"
    fi
    print_status "========================================="
}

# Main execution
main() {
    # Initialize logging first
    init_logging

    print_status "Starting Chart Sync Script at $(date)"

    # Validate environment
    validate_environment

    # Check prerequisites
    check_prerequisites

    # Setup source repository
    setup_source_repo

    # Select and read charts
    select_charts
    if ! read_charts_list; then
        exit 1
    fi

    # Setup target repository
    setup_target_repo

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Pull charts
    if ! pull_charts; then
        print_warning "Some charts failed to pull, continuing with successful ones..."
    fi

    # Push charts based on target type
    if [[ "$TARGET_TYPE" == "chartmuseum" ]]; then
        if ! push_to_chartmuseum; then
            print_warning "Some charts failed to push to ChartMuseum"
        fi
    elif [[ "$TARGET_TYPE" == "oci" ]]; then
        if ! push_to_oci; then
            print_warning "Some charts failed to push to OCI registry"
        fi
    fi

    # Show summary
    show_summary

    # Cleanup (always)
    cleanup

    print_success "Chart sync completed at $(date)"
}

# Handle script interruption
trap 'print_error "Script interrupted"; show_summary; cleanup; exit 1' INT TERM

# Run main function
main "$@"
