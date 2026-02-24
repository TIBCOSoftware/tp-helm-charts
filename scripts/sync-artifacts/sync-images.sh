#!/bin/bash

# sync-images.sh
#
# Copy container images listed in `*-images.txt` files using docker buildx.
# This script is non-interactive and driven by environment variables.
#
# Required Environment Variables:
#   SOURCE_REGISTRY          - Source Docker registry URL
#   SOURCE_REGISTRY_USERNAME - Username for source registry authentication
#   SOURCE_REGISTRY_PASSWORD - Password for source registry authentication
#   RELEASE_VERSION          - Release version in <major>.<minor>.<patch> format
#   TARGET_REGISTRY          - Target Docker registry URL
#
# Optional Environment Variables:
#   SOURCE_REGISTRY_REPO     - Source repository path (default: tibco-platform-docker-prod)
#   CAPABILITY_NAME          - If set, only sync images from <CAPABILITY_NAME>-<RELEASE_VERSION>-images.txt
#   TARGET_REGISTRY_USERNAME - Username for target registry authentication
#   TARGET_REGISTRY_PASSWORD - Password for target registry authentication
#   TARGET_REGISTRY_REPO     - Target repository path
#   WRITE_SCRIPT_LOGS_TO_FILE - If "true", write logs to file (default: false)
#   MAX_RETRY                - Number of retries for copy operations (default: 0, no retry)
#   WAIT_BEFORE_RETRY        - Seconds to wait before retry (default: 0, no wait)
#   DOCKER_QUIET             - If "false", show buildx output (default: true, output suppressed)
#
# Script behavior:
# - Source registry: logs in using provided credentials
# - Images: reads from ../../artifacts directory based on RELEASE_VERSION (and optionally CAPABILITY_NAME)
# - Target: copies images directly to TARGET_REGISTRY using docker buildx imagetools
# - Summary: provides detailed summary of operations

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/../../artifacts"
DEFAULT_SOURCE_REPO="tibco-platform-docker-prod"

# Retry configuration (from environment variables)
MAX_RETRY="${MAX_RETRY:-0}"
WAIT_BEFORE_RETRY="${WAIT_BEFORE_RETRY:-0}"

# Internal variables
INPUT_SOURCES=()
LOG_FILE=""
WRITE_LOGS="false"

# Statistics tracking
COPIED_COUNT=0
FAILED_COPY_COUNT=0
FAILED_COPY_IMAGES=()

# Initialize logging
init_logging() {
    if [[ "${WRITE_SCRIPT_LOGS_TO_FILE:-false}" == "true" ]]; then
        LOG_FILE="$SCRIPT_DIR/image_sync_$(date +%Y%m%d_%H%M%S).log"
        WRITE_LOGS="true"
        echo "Logging to file: $LOG_FILE"
    fi
}

# Function to strip ANSI color codes
strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Function to log command output
log_output() {
    if [[ "$WRITE_LOGS" == "true" ]]; then
        tee >(strip_colors >> "$LOG_FILE")
    else
        cat
    fi
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo "[INFO] $1" >> "$LOG_FILE"
    fi
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo "[SUCCESS] $1" >> "$LOG_FILE"
    fi
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo "[WARNING] $1" >> "$LOG_FILE"
    fi
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    if [[ "$WRITE_LOGS" == "true" ]]; then
        echo "[ERROR] $1" >> "$LOG_FILE"
    fi
}

# Validate required environment variables
validate_environment() {
    print_status "Validating environment variables..."

    if [[ -z "$SOURCE_REGISTRY" ]]; then
        print_error "SOURCE_REGISTRY environment variable is required"
        exit 1
    fi

    if [[ -z "$SOURCE_REGISTRY_USERNAME" ]]; then
        print_error "SOURCE_REGISTRY_USERNAME environment variable is required"
        exit 1
    fi

    if [[ -z "$SOURCE_REGISTRY_PASSWORD" ]]; then
        print_error "SOURCE_REGISTRY_PASSWORD environment variable is required"
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

    if [[ -z "$TARGET_REGISTRY" ]]; then
        print_error "TARGET_REGISTRY environment variable is required"
        exit 1
    fi

    # Set defaults for variables with defaults
    SOURCE_REGISTRY_REPO="${SOURCE_REGISTRY_REPO:-$DEFAULT_SOURCE_REPO}"

    if [[ "${DOCKER_QUIET:-true}" == "false" ]]; then
        print_status "Buildx quiet mode: disabled (output will be shown)"
    else
        print_status "Buildx quiet mode: enabled (output suppressed)"
    fi
    print_success "Environment variables validated"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v docker >/dev/null 2>&1; then
        print_error "docker CLI not found. Please install Docker and ensure 'docker' is on PATH."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi

    # Check for docker buildx
    if ! docker buildx version >/dev/null 2>&1; then
        print_error "Docker Buildx not found. Buildx is required for this script."
        print_error "Buildx is included with Docker Desktop and Docker Engine 19.03+."
        print_error "If using older Docker, install buildx: https://github.com/docker/buildx#installing"
        exit 1
    fi

    print_success "Prerequisites check passed (Docker and Buildx available)"
}

# Generic function to login to a Docker registry
# Arguments:
#   $1 - registry_type ("source" or "target") - for logging
#   $2 - registry_url
#   $3 - username
#   $4 - password
docker_registry_login() {
    local registry_type="$1"
    local registry_url="$2"
    local username="$3"
    local password="$4"

    print_status "Logging in to $registry_type registry: $registry_url"
    echo "$password" | docker login "$registry_url" --username "$username" --password-stdin 2>&1 | log_output
    local login_status=${PIPESTATUS[0]}

    if [ $login_status -eq 0 ]; then
        print_success "Successfully logged in to $registry_type registry"
    else
        print_error "Failed to login to $registry_type registry"
        exit 1
    fi
}

# Setup source registry (login)
setup_source_registry() {
    print_status "Setting up source registry: $SOURCE_REGISTRY"
    print_status "Source repository: $SOURCE_REGISTRY_REPO"
    docker_registry_login "source" "$SOURCE_REGISTRY" "$SOURCE_REGISTRY_USERNAME" "$SOURCE_REGISTRY_PASSWORD"
}

# Setup target registry (login if credentials provided)
setup_target_registry() {
    print_status "Setting up target registry: $TARGET_REGISTRY"

    if [[ -n "$TARGET_REGISTRY_USERNAME" && -n "$TARGET_REGISTRY_PASSWORD" ]]; then
        docker_registry_login "target" "$TARGET_REGISTRY" "$TARGET_REGISTRY_USERNAME" "$TARGET_REGISTRY_PASSWORD"
    else
        print_status "No target registry credentials provided, using without authentication"
    fi
}

# Function to clean and validate image names and construct full URLs
clean_image_url() {
    local image="$1"
    local registry="$2"
    local repository="$3"
    
    # Remove leading/trailing whitespace
    image=$(echo "$image" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Remove quotes
    image=$(echo "$image" | sed 's/^"//;s/"$//')
    
    # Skip empty lines or comments
    if [[ -z "$image" ]] || [[ "$image" =~ ^[[:space:]]*$ ]] || [[ "$image" =~ ^[[:space:]]*# ]]; then
        return 1
    fi
    
    # Skip images with wildcards (they need special handling)
    if [[ "$image" == *"*"* ]]; then
        print_warning "Skipping image with wildcard: $image (wildcards not supported)"
        return 1
    fi
    
    # Validate image name format: should contain at least one colon for tag
    if [[ "$image" != *":"* ]]; then
        print_warning "Skipping invalid image (no tag): $image"
        return 1
    fi
    
    # Construct full image URL: registry/repository/image:tag
    local full_image_url="${registry}/${repository}/${image}"
    
    echo "$full_image_url"
    return 0
}

# Function to construct target image name for target registry
construct_target_image() {
    local image_name_tag="$1"
    local target_image

    if [[ -n "$TARGET_REGISTRY_REPO" ]]; then
        target_image="${TARGET_REGISTRY}/${TARGET_REGISTRY_REPO}/${image_name_tag}"
    else
        target_image="${TARGET_REGISTRY}/${image_name_tag}"
    fi

    echo "$target_image"
}

# Select images based on RELEASE_VERSION and optional CAPABILITY_NAME
select_images() {
    print_status "Selecting images for release version: $RELEASE_VERSION"

    if [[ ! -d "$ARTIFACTS_DIR" ]]; then
        print_error "Artifacts directory not found: $ARTIFACTS_DIR"
        print_error "Please clone the public repo: https://github.com/TIBCOSoftware/tp-helm-charts"
        exit 1
    fi

    INPUT_SOURCES=()

    if [[ -n "$CAPABILITY_NAME" ]]; then
        print_status "Filtering by capability: $CAPABILITY_NAME"
        local expected_file="$ARTIFACTS_DIR/$CAPABILITY_NAME/$CAPABILITY_NAME-${RELEASE_VERSION}-images.txt"

        if [[ -f "$expected_file" ]]; then
            INPUT_SOURCES+=("$expected_file")
            print_status "Found images file: $expected_file"
        else
            print_error "Images file not found: $expected_file"
            exit 1
        fi
    else
        print_status "Searching for all *-${RELEASE_VERSION}-images.txt files..."
        while IFS= read -r -d '' f; do
            INPUT_SOURCES+=("$f")
        done < <(find "$ARTIFACTS_DIR" -type f -name "*-${RELEASE_VERSION}-images.txt" -print0 2>/dev/null)

        if [ ${#INPUT_SOURCES[@]} -eq 0 ]; then
            print_error "No matching *-${RELEASE_VERSION}-images.txt files found under $ARTIFACTS_DIR"
            exit 1
        fi
    fi

    print_success "Found ${#INPUT_SOURCES[@]} image list file(s)"
}

# =============================================================================
# BUILDX APPROACH: Uses docker buildx imagetools create to copy images directly
# between registries without pulling locally. Preserves multi-arch manifests.
# =============================================================================
copy_image_buildx() {
    local source_image="$1"

    # Calculate total attempts (1 initial + MAX_RETRY retries)
    local max_attempts=$((1 + MAX_RETRY))

    # Extract image name and tag from full URL
    local image_part="${source_image##*/}"  # Get everything after the last slash (image_name:tag)

    # Construct target image name for target registry
    local target_image
    target_image=$(construct_target_image "$image_part")

    print_status "Copying image (buildx): $source_image -> $target_image"

    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        if [ $max_attempts -gt 1 ]; then
            print_status "Copying $target_image (attempt $attempt/$max_attempts)..."
        fi

        # Use buildx imagetools create to copy image directly between registries
        # Note: For insecure (HTTP) registries, configure Docker daemon or use a buildx builder
        # with insecure registry config. See: https://docs.docker.com/build/buildkit/toml-configuration/
        local copy_output
        copy_output=$(docker buildx imagetools create --tag "$target_image" "$source_image" 2>&1)
        local copy_status=$?

        # Log output (suppress console if DOCKER_QUIET is true)
        if [[ -n "$copy_output" ]]; then
            if [[ "${DOCKER_QUIET:-true}" == "false" ]]; then
                echo "$copy_output" | log_output
            elif [[ "$WRITE_LOGS" == "true" ]]; then
                echo "$copy_output" | strip_colors >> "$LOG_FILE"
            fi
        fi

        if [ $copy_status -eq 0 ]; then
            print_success "Successfully copied $target_image"
            ((COPIED_COUNT++))
            success=true
        else
            print_warning "Failed to copy $target_image on attempt $attempt"
            if [[ -n "$copy_output" ]]; then
                print_warning "Error: $copy_output"
                # Check for insecure registry error and provide helpful hint
                if echo "$copy_output" | grep -qi "http:.*https\|server gave HTTP response to HTTPS"; then
                    print_warning "Hint: For insecure (HTTP) registries, configure a buildx builder:"
                    print_warning "  1. Create ~/.docker/buildkitd.toml:"
                    print_warning "     [registry.\"$TARGET_REGISTRY\"]"
                    print_warning "       http = true"
                    print_warning "       insecure = true"
                    print_warning "  2. Create builder: docker buildx create --name insecure-builder --config ~/.docker/buildkitd.toml --use"
                    print_warning "  See: https://docs.docker.com/build/buildkit/toml-configuration/"
                fi
            fi
            if [ $attempt -lt $max_attempts ] && [ "$WAIT_BEFORE_RETRY" -gt 0 ]; then
                print_status "Retrying in $WAIT_BEFORE_RETRY seconds..."
                sleep "$WAIT_BEFORE_RETRY"
            fi
        fi

        ((attempt++))
    done

    if [ "$success" = false ]; then
        print_error "Failed to copy $target_image after $max_attempts attempt(s)"
        ((FAILED_COPY_COUNT++))
        FAILED_COPY_IMAGES+=("$image_part")
        return 1
    fi

    return 0
}

# Function to read and process all images
process_images() {
    print_status "Reading images from input source(s):"
    for src in "${INPUT_SOURCES[@]}"; do
        print_status "  - $src"
        if [[ ! -f "$src" ]]; then
            print_error "Images file $src not found!"
            exit 1
        fi
    done

    # Create array of valid images
    local images=()
    for src in "${INPUT_SOURCES[@]}"; do
        while IFS= read -r line || [[ -n "$line" ]]; do
            if cleaned_image=$(clean_image_url "$line" "$SOURCE_REGISTRY" "$SOURCE_REGISTRY_REPO"); then
                images+=("$cleaned_image")
            fi
        done < "$src"
    done

    local total_count=${#images[@]}
    print_status "Found $total_count valid images to process"

    if [ $total_count -eq 0 ]; then
        print_error "No valid images found in provided input source(s)"
        exit 1
    fi

    # Process each image - temporarily disable set -e to handle failures gracefully
    set +e
    for image in "${images[@]}"; do
        print_status "Processing image: $image"

        copy_image_buildx "$image"
        print_status "----------------------------------------"
    done
    # Re-enable set -e
    set -e

    print_status "Copy Summary: $COPIED_COUNT succeeded, $FAILED_COPY_COUNT failed"
}

# Show summary
show_summary() {
    echo ""
    print_status "========================================="
    print_status "Image Sync Summary"
    print_status "========================================="
    print_status "Source Registry: $SOURCE_REGISTRY"
    print_status "Source Repository: $SOURCE_REGISTRY_REPO"
    print_status "Release Version: $RELEASE_VERSION"
    if [[ -n "$CAPABILITY_NAME" ]]; then
        print_status "Capability: $CAPABILITY_NAME"
    fi
    print_status "Target Registry: $TARGET_REGISTRY"
    if [[ -n "$TARGET_REGISTRY_REPO" ]]; then
        print_status "Target Repository: $TARGET_REGISTRY_REPO"
    fi
    print_status "-----------------------------------------"
    print_status "Copy Statistics:"
    print_status "  Number of images copied successfully: $COPIED_COUNT"
    if [ $FAILED_COPY_COUNT -gt 0 ]; then
        print_status "  Number of images failed to copy: $FAILED_COPY_COUNT"
        print_status "  Failed Images:"
        for img in "${FAILED_COPY_IMAGES[@]}"; do
            print_error "    - $img"
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

    print_status "Starting Image Sync Script at $(date)"

    # Validate environment
    validate_environment

    # Check prerequisites
    check_prerequisites

    # Setup source registry
    setup_source_registry

    # Setup target registry
    setup_target_registry

    # Select images
    select_images

    # Process images (copy using buildx)
    process_images

    # Show summary
    show_summary

    print_success "Image sync completed at $(date)"
}

# Handle script interruption
trap 'print_error "Script interrupted"; show_summary; exit 1' INT TERM

# Run main function
main "$@"
