#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
# verify-release.sh
#
# Validates images and Helm charts deployed in a Kubernetes namespace against
# tp-helm-charts/artifacts manifests for a given platform release version.
# If no capability folder is specified, no validation is performed.
#
# Usage:
#   ./verify-release.sh [OPTIONS]
#
# Environment Variables (primary interface):
#   CHECK_RELEASE_NAMESPACE      Kubernetes namespace to validate
#   CHECK_RELEASE_VERSION        Release version in <major>.<minor>.<patch> format (e.g. 1.18.0)
#   CHECK_RELEASE_FOLDER         Capability folder to validate (control-plane, flogo, bw, be, hawk, developer-hub, messaging)
#   CHECK_RELEASE_NAME           Helm release name used to filter deployments via
#                                app.kubernetes.io/instance label (e.g. platform-base)
#   CHECK_RELEASE_ARTIFACTS_DIR  Path to tp-helm-charts/artifacts directory
#                                (default: <script-dir>/../artifacts)
#
# Optional CLI Arguments (override environment variables):
#   -n | --namespace      Override CHECK_RELEASE_NAMESPACE
#   -v | --version        Override CHECK_RELEASE_VERSION
#   -f | --folder         Override CHECK_RELEASE_FOLDER
#   -r | --release        Override CHECK_RELEASE_NAME
#   -a | --artifacts-dir  Override CHECK_RELEASE_ARTIFACTS_DIR
#   -h | --help           Show this help message
#
# Exit codes:
#   0  All checks passed, or no --folder specified (no validation performed)
#   1  One or more image or chart mismatches found
#   2  Bad arguments or prerequisite check failed
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly DIVIDER="========================================="

# ---------------------------------------------------------------------------
# Color helpers — disabled automatically when stdout is not a terminal
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACTS_DIR="${CHECK_RELEASE_ARTIFACTS_DIR:-${SCRIPT_DIR}/../artifacts}"

# Known capability folders and their display names
VALID_FOLDERS=( control-plane flogo bw be hawk developer-hub messaging )
declare -A CAPABILITY_NAMES=(
    [control-plane]="Control Plane"
    [flogo]="Flogo"
    [bw]="BusinessWorks"
    [be]="BusinessEvents"
    [hawk]="Hawk"
    [developer-hub]="Developer Hub"
    [messaging]="Messaging"
)

# Input arguments — initialized from CHECK_RELEASE_* env vars; CLI params override
NAMESPACE="${CHECK_RELEASE_NAMESPACE:-}"
RELEASE_VERSION="${CHECK_RELEASE_VERSION:-}"
CAPABILITY_NAME="${CHECK_RELEASE_FOLDER:-}"
RELEASE_NAME="${CHECK_RELEASE_NAME:-}"

# Cluster state (pre-fetched once to avoid repeated kubectl/helm calls)
POD_IMAGES=""
HELM_RELEASES=""

# Validation statistics
IMG_CHECKED=0
IMG_FOUND=0
IMG_MISMATCH=0
IMG_MISSING=0
CHART_CHECKED=0
CHART_FOUND=0
CHART_MISMATCH=0
CHART_MISSING=0

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
_ts() { date '+%Y-%m-%d %H:%M:%S'; }

print_status()  { echo -e "${BLUE}[INFO]${NC}    $(_ts) ${1}"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $(_ts) ${1}"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $(_ts) ${1}" >&2; }
print_error()   { echo -e "${RED}[ERROR]${NC}   $(_ts) ${1}" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF

NAME
    ${SCRIPT_NAME} - Validate images and Helm charts in a namespace against release artifacts

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS]

ENVIRONMENT VARIABLES (primary interface)
    CHECK_RELEASE_NAMESPACE      Kubernetes namespace to validate
    CHECK_RELEASE_VERSION        Release version in <major>.<minor>.<patch> format (e.g. 1.18.0)
    CHECK_RELEASE_FOLDER         Capability folder to validate
    CHECK_RELEASE_NAME           Helm release name for deployment label filtering
                                 (app.kubernetes.io/instance=<release>)
    CHECK_RELEASE_ARTIFACTS_DIR  Path to tp-helm-charts/artifacts directory
                                 (default: ${SCRIPT_DIR}/../artifacts)

OPTIONAL CLI OVERRIDES
    -n | --namespace      Override CHECK_RELEASE_NAMESPACE
    -v | --version        Override CHECK_RELEASE_VERSION
    -f | --folder         Override CHECK_RELEASE_FOLDER
    -r | --release        Override CHECK_RELEASE_NAME
    -a | --artifacts-dir  Override CHECK_RELEASE_ARTIFACTS_DIR
    -h | --help           Show this help message

VALID CAPABILITY FOLDERS
    control-plane, flogo, bw, be, hawk, developer-hub, messaging

EXIT CODES
    0  All checks passed, or no --folder specified (no validation performed)
    1  One or more image or chart mismatches found
    2  Bad arguments or prerequisite check failed

EXAMPLES
    # Using environment variables
    export CHECK_RELEASE_NAMESPACE=my-namespace
    export CHECK_RELEASE_VERSION=1.18.0
    export CHECK_RELEASE_FOLDER=control-plane
    export CHECK_RELEASE_NAME=platform-base
    ${SCRIPT_NAME}

    # Using CLI overrides
    ${SCRIPT_NAME} -n my-namespace -v 1.18.0 -f control-plane -r platform-base

EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                [[ -z "${2:-}" || "${2}" == -* ]] && { print_error "--namespace requires a value."; exit 2; }
                NAMESPACE="$2"; shift 2 ;;
            -v|--version)
                [[ -z "${2:-}" || "${2}" == -* ]] && { print_error "--version requires a value."; exit 2; }
                RELEASE_VERSION="$2"; shift 2 ;;
            -f|--folder)
                [[ -z "${2:-}" || "${2}" == -* ]] && { print_error "--folder requires a value."; exit 2; }
                CAPABILITY_NAME="$2"; shift 2 ;;
            -r|--release)
                [[ -z "${2:-}" || "${2}" == -* ]] && { print_error "--release requires a value."; exit 2; }
                RELEASE_NAME="$2"; shift 2 ;;
            -a|--artifacts-dir)
                [[ -z "${2:-}" || "${2}" == -* ]] && { print_error "--artifacts-dir requires a value."; exit 2; }
                ARTIFACTS_DIR="$2"; shift 2 ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                print_error "Unknown option: ${1}. Use --help for usage."
                exit 2 ;;
        esac
    done

    # Fallback to env vars exported by scripts/upgrade.sh when used as POST_UPGRADE_VALIDATION_SCRIPT.
    # Usage: export POST_UPGRADE_VALIDATION_SCRIPT="/path/to/dev/check-release.sh"
    #        export TP_UPGRADE_CAPABILITY_NAME="control-plane"  # must be set; no default
    NAMESPACE="${NAMESPACE:-${TP_UPGRADE_NAMESPACE:-}}"
    RELEASE_VERSION="${RELEASE_VERSION:-${TP_UPGRADE_TARGET_VERSION:-}}"
    RELEASE_NAME="${RELEASE_NAME:-${TP_UPGRADE_PLATFORM_BASE_RELEASE:-}}"
    CAPABILITY_NAME="${CAPABILITY_NAME:-${TP_UPGRADE_CAPABILITY_NAME:-}}"
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------
validate_inputs() {
    print_status "🔍 Validating inputs..."

    if [[ -z "$NAMESPACE" ]]; then
        print_error "Namespace is required: set --namespace or CHECK_RELEASE_NAMESPACE. Use --help for usage."
        exit 2
    fi

    if [[ -z "$RELEASE_VERSION" ]]; then
        print_error "Version is required: set --version or CHECK_RELEASE_VERSION. Use --help for usage."
        exit 2
    fi

    if [[ ! "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "--version must be in <major>.<minor>.<patch> format (e.g. 1.18.0). Provided: ${RELEASE_VERSION}"
        exit 2
    fi

    if [[ -z "$CAPABILITY_NAME" ]]; then
        print_status "No capability folder specified (--folder or CHECK_RELEASE_FOLDER) — no validation will be performed."
        exit 0
    fi

    if [[ -z "$RELEASE_NAME" ]]; then
        print_error "Release name is required: set --release or CHECK_RELEASE_NAME. Use --help for usage."
        exit 2
    fi

    local folder valid=false
    for folder in "${VALID_FOLDERS[@]}"; do
        if [[ "$folder" == "$CAPABILITY_NAME" ]]; then
            valid=true
            break
        fi
    done

    if [[ "$valid" == "false" ]]; then
        print_error "Unknown capability folder: '${CAPABILITY_NAME}'"
        print_error "Valid folders: ${VALID_FOLDERS[*]}"
        exit 2
    fi

    print_success "Inputs validated"
}

# ---------------------------------------------------------------------------
# Prerequisites check
# ---------------------------------------------------------------------------
check_prerequisites() {
    print_status "🔧 Checking prerequisites..."

    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl not found in PATH. Please install kubectl and try again."
        exit 2
    fi

    if ! command -v helm >/dev/null 2>&1; then
        print_error "helm not found in PATH. Please install Helm and try again."
        exit 2
    fi

    local helm_version helm_major helm_minor
    helm_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    helm_major=$(echo "$helm_version" | cut -d. -f1 | tr -d 'v')
    helm_minor=$(echo "$helm_version" | cut -d. -f2)
    if [[ "$helm_major" != "3" || "$helm_minor" -lt 6 ]]; then
        print_error "Helm 3.6.0 or higher is required. Found: ${helm_version:-unknown}"
        exit 2
    fi

    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_error "Namespace '${NAMESPACE}' not found or no cluster access."
        exit 2
    fi

    if [[ ! -d "$ARTIFACTS_DIR" ]]; then
        print_error "Artifacts directory not found: ${ARTIFACTS_DIR}"
        exit 2
    fi

    print_success "Prerequisites check passed (kubectl and helm available)"
}

# ---------------------------------------------------------------------------
# Cluster state pre-fetch — single kubectl/helm call shared across all checks
# ---------------------------------------------------------------------------
fetch_cluster_state() {
    print_status "📡 Fetching cluster state for namespace '${NAMESPACE}' (release: ${RELEASE_NAME})..."

    # Fetch images from pods matching the release label
    POD_IMAGES=$(kubectl get pods -n "$NAMESPACE" \
        -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
        -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{range .spec.initContainers[*]}{.image}{"\n"}{end}{end}' 2>/dev/null \
        | awk -F/ '{print $NF}' | sort -u || true)

    # Chart for the specific release only — scoped by release name to avoid
    # picking up charts from other capabilities deployed in the same namespace
    HELM_RELEASES=$(helm list -n "$NAMESPACE" --filter "^${RELEASE_NAME}$" --deployed --no-headers 2>/dev/null \
        | awk '{print $(NF-1)}' | sort -u || true)

    if [[ -z "$POD_IMAGES" ]]; then
        print_warning "⚠️  No deployments found for release '${RELEASE_NAME}' in namespace '${NAMESPACE}'."
    fi

    if [[ -z "$HELM_RELEASES" ]]; then
        print_warning "No deployed Helm releases found in namespace '${NAMESPACE}'."
    fi

    print_success "Cluster state fetched"
}

# ---------------------------------------------------------------------------
# Pod health check — all pods matching the release label must be Running or
# Completed before image validation is meaningful. Exits early if any pod is
# in Pending, Error, CrashLoopBackOff, OOMKilled, ImagePullBackOff, etc.
# ---------------------------------------------------------------------------
check_pod_health() {
    print_status "🏥 Checking pod health for release '${RELEASE_NAME}' in namespace '${NAMESPACE}'..."

    local pod_output
    pod_output=$(kubectl get pods -n "$NAMESPACE" \
        -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
        --no-headers 2>/dev/null || true)

    if [[ -z "$pod_output" ]]; then
        print_warning "⚠️  No pods found for release '${RELEASE_NAME}' — skipping pod health check."
        return
    fi

    local unhealthy
    unhealthy=$(echo "$pod_output" | grep -Ev "(Running|Completed|Succeeded)" || true)

    if [[ -n "$unhealthy" ]]; then
        print_error "One or more pods are not in a healthy state. Ensure all pods are Running or Completed before running validation."
        print_error "Unhealthy pods:"
        while IFS= read -r line; do
            print_error "  ${line}"
        done <<< "$unhealthy"
        exit 1
    fi

    local total
    total=$(echo "$pod_output" | wc -l | tr -d ' ')
    print_success "All ${total} pod(s) are in healthy state (Running/Completed)"
}

# ---------------------------------------------------------------------------
# Helm release health check — all Helm releases in the namespace must be in
# deployed state. Exits early if any release is in failed, pending-upgrade,
# pending-install, or any other non-deployed state.
# ---------------------------------------------------------------------------
check_helm_health() {
    print_status "⚓ Checking Helm release health for '${RELEASE_NAME}' in namespace '${NAMESPACE}'..."

    local release_status
    release_status=$(helm list -n "$NAMESPACE" --filter "^${RELEASE_NAME}$" --no-headers 2>/dev/null \
        | awk '{print $(NF-2)}' | head -1 || true)

    if [[ -z "$release_status" ]]; then
        print_warning "⚠️  Helm release '${RELEASE_NAME}' not found — skipping Helm health check."
        return
    fi

    if [[ "$release_status" != "deployed" ]]; then
        print_error "Helm release '${RELEASE_NAME}' is not in deployed state: ${release_status}"
        print_error "Ensure the release is in deployed state before running validation."
        exit 1
    fi

    print_success "Helm release '${RELEASE_NAME}' is in deployed state"
}

# ---------------------------------------------------------------------------
# Component validation — both image and chart checks are cluster-driven.
#
# Image logic : iterate pods (main + init containers) filtered by release label
#               → matched (correct tag) | mismatched (wrong tag) | missing (not in artifacts)
# Chart logic : iterate deployed helm releases filtered by release name
#               → matched (correct version) | mismatched (wrong version) | missing (not in artifacts)
# ---------------------------------------------------------------------------
validate_component() {
    local folder="$1"
    local name="${CAPABILITY_NAMES[$folder]}"
    local images_file="${ARTIFACTS_DIR}/${folder}/${folder}-${RELEASE_VERSION}-images.txt"
    local charts_file="${ARTIFACTS_DIR}/${folder}/${folder}-${RELEASE_VERSION}-charts.txt"

    print_status "📦 Validating capability: ${name} (folder: ${folder}, version: ${RELEASE_VERSION})"

    if [[ ! -f "$images_file" && ! -f "$charts_file" ]]; then
        print_error "No artifact files found for '${folder}' at version ${RELEASE_VERSION}."
        exit 1
    fi

    # ── Images ───────────────────────────────────────────────────────────────
    # Cluster-driven: walk running pods, check each against artifact lookup.
    # Missing = running in cluster but not listed in artifacts.
    if [[ -f "$images_file" ]]; then
        print_status "  🖼️  Checking images..."

        declare -A artifact_imgs
        local entry
        while IFS= read -r entry; do
            [[ -z "${entry// }" || "$entry" == \#* ]] && continue
            artifact_imgs["${entry%%:*}"]="${entry##*:}"
        done < "$images_file"

        local running img_name img_tag expected_tag
        while IFS= read -r running; do
            [[ -z "$running" ]] && continue
            img_name="${running%%:*}"
            img_tag="${running##*:}"
            IMG_CHECKED=$(( IMG_CHECKED + 1 ))
            if [[ -v artifact_imgs["$img_name"] ]]; then
                expected_tag="${artifact_imgs[$img_name]}"
                if [[ "$img_tag" == "$expected_tag" ]]; then
                    print_success "  ✅  ${running}"
                    IMG_FOUND=$(( IMG_FOUND + 1 ))
                else
                    print_error "  ❌  ${img_name}  [version mismatch]"
                    print_error "       In cluster  : ${img_tag}"
                    print_error "       In artifact : ${expected_tag}"
                    IMG_MISMATCH=$(( IMG_MISMATCH + 1 ))
                fi
            else
                print_error "  ❌  ${running}  [not found in artifacts]"
                IMG_MISSING=$(( IMG_MISSING + 1 ))
            fi
        done <<< "$POD_IMAGES"

        unset artifact_imgs
    else
        print_warning "  No images file found for version ${RELEASE_VERSION} — images check skipped."
    fi

    # ── Charts ───────────────────────────────────────────────────────────────
    # Cluster-driven: walk deployed helm releases, check each against artifact lookup.
    # Missing = deployed in cluster but not listed in artifacts.
    if [[ -f "$charts_file" ]]; then
        print_status "  📋 Checking charts..."

        declare -A artifact_charts
        local entry
        while IFS= read -r entry; do
            [[ -z "${entry// }" || "$entry" == \#* ]] && continue
            artifact_charts["${entry%%:*}"]="${entry##*:}"
        done < "$charts_file"

        local deployed chart_name chart_ver expected_ver
        while IFS= read -r deployed; do
            [[ -z "$deployed" ]] && continue
            chart_name=$(echo "$deployed" | sed 's/-[0-9].*$//')
            chart_ver=$(echo "$deployed" | sed "s/^${chart_name}-//")
            CHART_CHECKED=$(( CHART_CHECKED + 1 ))
            if [[ -v artifact_charts["$chart_name"] ]]; then
                expected_ver="${artifact_charts[$chart_name]}"
                if [[ "$chart_ver" == "$expected_ver" ]]; then
                    print_success "  ✅  ${chart_name}:${chart_ver}"
                    CHART_FOUND=$(( CHART_FOUND + 1 ))
                else
                    print_error "  ❌  ${chart_name}  [version mismatch]"
                    print_error "       In cluster  : ${chart_ver}"
                    print_error "       In artifact : ${expected_ver}"
                    CHART_MISMATCH=$(( CHART_MISMATCH + 1 ))
                fi
            else
                print_error "  ❌  ${chart_name}:${chart_ver}  [not found in artifacts]"
                CHART_MISSING=$(( CHART_MISSING + 1 ))
            fi
        done <<< "$HELM_RELEASES"

        unset artifact_charts
    else
        print_warning "  No charts file found for version ${RELEASE_VERSION} — charts check skipped."
    fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
show_summary() {
    local total_failures=$(( IMG_MISMATCH + IMG_MISSING + CHART_MISMATCH + CHART_MISSING ))

    echo ""
    print_status "${DIVIDER}"
    print_status "📊 Release Validation Summary"
    print_status "${DIVIDER}"
    print_status "Namespace       : ${NAMESPACE}"
    print_status "Release Name    : ${RELEASE_NAME}"
    print_status "Release Version : ${RELEASE_VERSION}"
    print_status "Capability      : ${CAPABILITY_NAME} (${CAPABILITY_NAMES[${CAPABILITY_NAME}]})"
    print_status "-----------------------------------------"
    print_status "Images  : ${IMG_CHECKED} checked | ${IMG_FOUND} matched | ${IMG_MISMATCH} mismatched | ${IMG_MISSING} missing"
    print_status "Charts  : ${CHART_CHECKED} checked | ${CHART_FOUND} matched | ${CHART_MISMATCH} mismatched | ${CHART_MISSING} missing"
    print_status "-----------------------------------------"
    print_status "${DIVIDER}"
    echo ""

    if [[ $total_failures -gt 0 ]]; then
        local detail=""
        [[ $IMG_MISMATCH -gt 0 ]]  && detail+="${IMG_MISMATCH} image(s) mismatched"
        [[ $IMG_MISSING -gt 0 ]]   && { [[ -n "$detail" ]] && detail+=", "; detail+="${IMG_MISSING} image(s) missing"; }
        [[ $CHART_MISMATCH -gt 0 ]] && { [[ -n "$detail" ]] && detail+=", "; detail+="${CHART_MISMATCH} chart(s) mismatched"; }
        [[ $CHART_MISSING -gt 0 ]] && { [[ -n "$detail" ]] && detail+=", "; detail+="${CHART_MISSING} chart(s) missing"; }
        print_error "Overall Result: ❌ FAILED — ${detail}"
        return 1
    else
        print_success "Overall Result: ✅ PASSED"
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    print_status "🚀 Starting ${SCRIPT_NAME} at $(_ts)"

    parse_args "$@"
    validate_inputs
    check_prerequisites
    fetch_cluster_state
    check_pod_health
    check_helm_health
    validate_component "$CAPABILITY_NAME"

    local exit_code=0
    show_summary || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_success "🎉 Release validation completed successfully."
    else
        print_error "💥 Release validation completed with failures. Review the mismatches and missing entries above."
    fi

    exit $exit_code
}

# ---------------------------------------------------------------------------
# Signal handling
# ---------------------------------------------------------------------------
trap 'print_error "Script interrupted."; exit 2' INT TERM

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main "$@"
