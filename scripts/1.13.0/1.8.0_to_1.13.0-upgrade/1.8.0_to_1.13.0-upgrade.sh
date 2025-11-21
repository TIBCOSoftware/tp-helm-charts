#!/bin/bash
#
# Copyright (c) 2025 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# Tested on: Ubuntu 24.04 LTS; Bash 5.2.21
#
# TIBCO Control Plane Helm Values Generation Script for Platform Upgrade (1.8.0 → 1.13.0)
# Generates an upgrade-ready single combined values.yaml for the platform-base chart (bootstrap + base)
# and can optionally perform a Helm upgrade using the generated values.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults and globals
OPERATION_MODE="generate"   # generate | helm
PLATFORM_BOOTSTRAP_FILE=""
PLATFORM_BASE_FILE=""
PLATFORM_OUTPUT_BASE_FILE="platform-1.13.0-values.yaml"
NAMESPACE=""
TP_HELM_CHARTS_REPO=""
PLATFORM_CHART_VERSION="${PLATFORM_CHART_VERSION:-1.13.0}"
UPGRADE_MINOR_VERSIONS="${UPGRADE_MINOR_VERSIONS:-false}"
TEMP_DIR=""
HELM_UPGRADE_MODE=false
# Verbosity (default: silent for detailed merge logs)
VERBOSE="${VERBOSE:-false}"

# Release names (pre-1.13 split) and combined target
PLATFORM_BOOTSTRAP_RELEASE="platform-bootstrap"
PLATFORM_BASE_RELEASE="platform-base"

print_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $*" 1>&2; }
print_success() { echo -e "${GREEN}[OK]${NC} $*"; }

# Verbose logger (only prints when VERBOSE=true)
log_verbose() { if [[ "${VERBOSE}" == "true" ]]; then print_info "$@"; fi }

# Simple newline helper for readability
nl() { printf '\n'; }

show_usage() {
  cat <<EOF
TIBCO Control Plane Upgrade Script - 1.8.0 to 1.13.0
====================================================

This script runs in INTERACTIVE mode only.

How to run:
  ./upgrade.sh

What it does:
  - Guides you to generate a single combined values.yaml (platform-bootstrap + platform-base)
  - Writes the combined file to ${PLATFORM_OUTPUT_BASE_FILE}
  - Optionally performs a Helm upgrade of the unified platform-base chart

Notes:
  - Use -h or --help to show this help text
  - Requires: bash 5+, yq v4+; for Helm flows: helm 3.17+, jq, kubectl
EOF
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

  # Check helm availability and version (helm/jq/kubectl required for Helm flows)
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
    # kubectl is needed to validate namespaces/releases in helm flows
    if ! command -v kubectl >/dev/null 2>&1; then
      print_error "kubectl is required for helm operations. Install from: https://kubernetes.io/docs/tasks/tools/"
      echo "Dependency check failed: kubectl not found"
      exit 1
    fi
  fi
}

cleanup() { [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}" || true; }
on_sigint() {
  nl; print_warn "Interrupted by user (Ctrl+C). Exiting."; exit 130
}
trap on_sigint INT
trap cleanup EXIT TERM

# Ensure a temp directory exists for intermediate files
setup_temp_dir() {
  if [[ -z "${TEMP_DIR}" || ! -d "${TEMP_DIR}" ]]; then
    TEMP_DIR=$(mktemp -d)
  fi
}

# Small helpers for interactive prompts
prompt_read() {
  # $1 = prompt text, $2 = var name to fill
  local __prompt="$1" __varname="$2" __ans
  read -r -p "${__prompt}" __ans || { print_warn "Input aborted"; exit 130; }
  printf -v "${__varname}" '%s' "${__ans}"
}

confirm_yes_no() {
  # returns 0 for yes, 1 for no
  local ans; read -r -p "$1 (yes/no): " ans || return 1
  [[ "${ans}" == "yes" ]]
}

interactive_mode() {
  nl
  print_info "========================================================="
  print_info " TIBCO Control Plane Upgrade Script - 1.8.0 to 1.13.0"
  print_info "========================================================="
  nl
  echo "Please select your operation mode:"
  echo "1) Generate 1.13.0 values.yaml files from current 1.8.0 setup"
  echo "2) Perform Helm upgrade using existing 1.13.0 compatible values.yaml file"
  echo "3) Clean up remaining platform-bootstrap resources (after successful 1.13.0 upgrade)"
  nl
  while true; do
    read -p "Enter your choice (1 or 3): " choice
    nl
    case "$choice" in
      1)
        print_info "Selected: Generate 1.13.0 values.yaml file"
        interactive_values_generation
        break
        ;;
      2)
        print_info "Selected: Perform Helm upgrade"
        interactive_helm_upgrade_setup
        break
        ;;
      3)
        print_info "Selected: Clean up remaining platform-bootstrap resources"
        cleanup_bootstrap_resources
        break
        ;;
      *)
        print_error "Invalid choice. Please enter 1 or 2."
        ;;
    esac
  done
}

# Values Generation setup
interactive_values_generation() {
  nl
  print_info "Values Generation Setup"
  print_info "======================"
  nl
  echo "How would you like to provide your current 1.8.0 values?"
  echo "1) I have existing 1.8.0 values.yaml files"
  echo "2) Extract values from running Helm deployments"
  nl
  while true; do
    read -p "Enter your choice (1 or 2): " sub
    case "${sub}" in
      1)
        print_info "Selected: Use existing values.yaml files"
        interactive_file_input
        break
        ;;
      2)
        print_info "Selected: Extract from Helm deployments"
        interactive_helm_input
        break
        ;;
      *)
        print_error "Invalid choice. Please enter 1 or 2."
        ;;
    esac
  done
}

# File-based input wrapper
interactive_file_input() {
  nl
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
    nl
    if [[ ! -f "${PLATFORM_BASE_FILE}" ]]; then
      print_error "File not found: ${PLATFORM_BASE_FILE}"
      PLATFORM_BASE_FILE=""
    fi
  done

  print_success "Input files validated successfully"
  # Ask for custom output file name
  nl
  print_info "Output File Configuration"
  print_info "========================"
  nl
  local custom_out
  read -p "Output ${PLATFORM_BASE_RELEASE} values file (default: ${PLATFORM_OUTPUT_BASE_FILE}): " custom_out
  nl
  [[ -n "${custom_out}" ]] && PLATFORM_OUTPUT_BASE_FILE="${custom_out}"

  # Perform generation inline
  check_dependencies
  nl
  print_info "Merging platform-bootstrap and platform-base values into a simplified platform-base chart for upgrade..."
  nl
  combine_values_files "${PLATFORM_BASE_FILE}" "${PLATFORM_BOOTSTRAP_FILE}" "${PLATFORM_OUTPUT_BASE_FILE}"
  transform_recipe_sections "${PLATFORM_OUTPUT_BASE_FILE}"
  tidy_yaml "${PLATFORM_OUTPUT_BASE_FILE}"
  nl
  print_success "New ${PLATFORM_BASE_RELEASE} values.yaml generation completed successfully!"
  nl
  print_info "Generated ${PLATFORM_OUTPUT_BASE_FILE} values file for ${PLATFORM_BASE_RELEASE} upgrade:"
  print_info "  - ${PLATFORM_BASE_RELEASE}: ${PLATFORM_OUTPUT_BASE_FILE}"
  nl
  print_success "All operations completed successfully!"
}

# Helm extraction wrapper
interactive_helm_input() {
  nl
  # Validate mode-specific dependencies right away (helm/jq)
  OPERATION_MODE="helm"
  HELM_UPGRADE_MODE=false
  print_info "Validating Helm/jq requirements for extraction..."
  check_dependencies
  print_success "All dependencies met!"
  nl
  print_info "Please provide details of your current 1.8.0 Helm deployment..."
  # Get Helm configuration
  while [[ -z "${NAMESPACE}" ]]; do
    read -p "Enter Kubernetes namespace containing your deployments: " NAMESPACE
  done

  # Strict validation: namespace must exist
  if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    print_error "Namespace not found: ${NAMESPACE}. Please provide correct namespace for ${PLATFORM_BOOTSTRAP_RELEASE} and ${PLATFORM_BASE_RELEASE} values extraction."
    exit 1
  fi

  # Ask for release names
  read -p "Platform Bootstrap release name (default: ${PLATFORM_BOOTSTRAP_RELEASE}): " input_bootstrap
  [[ -n "${input_bootstrap}" ]] && PLATFORM_BOOTSTRAP_RELEASE="${input_bootstrap}"
  read -p "Platform Base release name (default: ${PLATFORM_BASE_RELEASE}): " input_base
  [[ -n "${input_base}" ]] && PLATFORM_BASE_RELEASE="${input_base}"

  # Require at least one platform release to exist for extraction
  if ! helm status "${PLATFORM_BOOTSTRAP_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 \
     && ! helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    print_error "No platform releases found in namespace ${NAMESPACE}. Use 'I have existing values.yaml files' option."
    exit 1
  fi

  # Ask for output file
  nl
  print_info "Output File Configuration"
  print_info "========================"
  nl
  local custom_out
  read -p "Output ${PLATFORM_BASE_RELEASE} values file (default: ${PLATFORM_OUTPUT_BASE_FILE}): " custom_out
  [[ -n "${custom_out}" ]] && PLATFORM_OUTPUT_BASE_FILE="${custom_out}"

  generation_from_helm
}

# Helm upgrade executor
perform_helm_upgrade() {
  helm_upgrade_combined
}

generation_from_helm() {
  nl
  print_info "Extracting values from Helm releases (no upgrade)"
  # Dependencies already validated in interactive_helm_input(); skip re-check here
  # Defensive re-checks
  if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    print_error "Namespace not found: ${NAMESPACE}. Aborting Helm extraction."
    exit 1
  fi
  if ! helm status "${PLATFORM_BOOTSTRAP_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 \
     && ! helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    print_error "No platform releases found in namespace ${NAMESPACE}. Aborting Helm extraction."
    exit 1
  fi
  # Use namespace and output file already provided in interactive_helm_input(); do not prompt again
  TEMP_DIR=$(mktemp -d)
  local bs_vals="${TEMP_DIR}/bs.yaml" base_vals="${TEMP_DIR}/base.yaml"
  fetch_release_values "${PLATFORM_BOOTSTRAP_RELEASE}" "${NAMESPACE}" "${bs_vals}"
  fetch_release_values "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}" "${base_vals}"
  print_info "Merging ${PLATFORM_BOOTSTRAP_RELEASE} and ${PLATFORM_BASE_RELEASE} values into a simplified ${PLATFORM_BASE_RELEASE} chart for upgrade..."
  combine_values_files "${base_vals}" "${bs_vals}" "${PLATFORM_OUTPUT_BASE_FILE}"
  transform_recipe_sections "${PLATFORM_OUTPUT_BASE_FILE}"
  tidy_yaml "${PLATFORM_OUTPUT_BASE_FILE}"
  nl
  print_success "Values.yaml generation completed successfully!"
  print_info "Generated values.yaml file for upgrade:"
  print_info "  - ${PLATFORM_BASE_RELEASE}: ${PLATFORM_OUTPUT_BASE_FILE}"
  nl
  print_success "All operations completed successfully!"
}

interactive_helm_upgrade_setup() {
  nl
  print_info "Helm Upgrade Setup"
  print_info "=================="
  # Set upgrade mode early so deps enforce helm/jq
  print_info "Validating Helm/jq requirements for upgrade..."
  HELM_UPGRADE_MODE=true
  check_dependencies
  print_success "All dependencies met!"
  nl
  print_info "This mode will perform actual Helm upgrades on your cluster using ${PLATFORM_CHART_VERSION} values.yaml file."
  nl
  while [[ -z "${NAMESPACE}" ]]; do
    read -p "Enter target namespace for upgrade: " NAMESPACE
    [[ -n "${NAMESPACE}" ]] || print_error "Namespace is required"
  done
  read -p "Enter Helm repository name (default: tp-helm-charts): " TP_HELM_REPO_NAME
  [[ -z "${TP_HELM_REPO_NAME}" ]] && TP_HELM_REPO_NAME="tp-helm-charts"
  # Use PLATFORM_CHART_VERSION as provided by env/default (do not prompt)
  # Always ask for values file to use for the unified chart upgrade
  while true; do
    local __vf
    read -p "Enter file name of 1.13.0 ${PLATFORM_BASE_RELEASE} values.yaml file (default: ${PLATFORM_OUTPUT_BASE_FILE}): " __vf
    [[ -n "${__vf}" ]] && PLATFORM_OUTPUT_BASE_FILE="${__vf}"
    if [[ -f "${PLATFORM_OUTPUT_BASE_FILE}" ]]; then
      break
    else
      print_error "File not found: ${PLATFORM_OUTPUT_BASE_FILE}"
    fi
  done
  nl
  print_info "Summary:"
  print_info "  Namespace: ${NAMESPACE}"
  print_info "  Helm repo name: ${TP_HELM_REPO_NAME}"
  print_info "  Target chart version: ${PLATFORM_CHART_VERSION}"
  print_info "  Values file: ${PLATFORM_OUTPUT_BASE_FILE}"
  nl
  read -p "Proceed with Helm upgrade? (yes/no): " confirm
  if [[ "${confirm}" == "yes" ]]; then
    helm_upgrade_combined
  else
    print_info "Helm upgrade cancelled by user."
  fi
}

# Merge helpers
# Start with BASE; overlay bootstrap components; migrate compute-services to tp-cp-infra
combine_values_files() {
  local base_file="$1"; local bs_file="$2"; local out_file="$3"

  yq eval '.' "${base_file}" > "${out_file}" || { print_error "Failed to read base file"; exit 1; }

  # If bootstrap values are nested under tp-cp-bootstrap, merge its children into root first
  if yq eval 'has("tp-cp-bootstrap")' "${bs_file}" | grep -q true; then
    log_verbose "Merging bootstrap.tp-cp-bootstrap subtree into root"
    local bs_nested
    bs_nested=$(mktemp)
    yq eval '."tp-cp-bootstrap"' "${bs_file}" > "${bs_nested}"
    yq eval-all 'select(fileIndex==0) *+ select(fileIndex==1)' "${out_file}" "${bs_nested}" > "${out_file}.tmp"
    mv "${out_file}.tmp" "${out_file}"
    rm -f "${bs_nested}"
  fi

  # Remove deprecated tp-cp-bootstrap section from the output if accidentally introduced
  if yq eval 'has("tp-cp-bootstrap")' "${out_file}" | grep -q true; then
    yq eval 'del(."tp-cp-bootstrap")' -i "${out_file}"
  fi

  # Copy top-level bootstrap components commonly present in bootstrap chart
  for sect in hybrid-proxy router-operator resource-set-operator otel-collector platform-cp-messaging; do
    # Try root path in bootstrap
    if yq eval "has(\"${sect}\")" "${bs_file}" | grep -q true; then
      yq eval-all "select(fileIndex==0) as \$o | select(fileIndex==1) as \$b | \$o | .${sect} = (\$b.${sect} // .${sect})" \
        "${out_file}" "${bs_file}" > "${out_file}.tmp" && mv "${out_file}.tmp" "${out_file}"
      log_verbose "Merged bootstrap section: ${sect}"
      continue
    fi
    # Try nested path under tp-cp-bootstrap in bootstrap
    if yq eval "has(\"tp-cp-bootstrap\") and .\"tp-cp-bootstrap\" | has(\"${sect}\")" "${bs_file}" | grep -q true; then
      yq eval-all "select(fileIndex==0) as \$o | select(fileIndex==1) as \$b | \$o | .${sect} = (\$b.\"tp-cp-bootstrap\".${sect} // .${sect})" \
        "${out_file}" "${bs_file}" > "${out_file}.tmp" && mv "${out_file}.tmp" "${out_file}"
      log_verbose "Merged bootstrap section (nested): ${sect}"
    fi
  done

  # Migrate compute-services -> tp-cp-infra (as 1.10 logic)
  # Support both root-level and nested under tp-cp-bootstrap
  local cs_yaml
  cs_yaml=$(yq eval '."compute-services" // ."tp-cp-bootstrap"."compute-services" // "null"' "${bs_file}" || echo "null")
  if [[ "${cs_yaml}" != "null" ]]; then
    log_verbose "Found compute-services in bootstrap; migrating to tp-cp-infra"
    # Capture the effective compute-services object into a temp file for consistent access
    local tmp_cs
    tmp_cs=$(mktemp)
    yq eval '."compute-services" // ."tp-cp-bootstrap"."compute-services"' "${bs_file}" > "${tmp_cs}"
    # Split resources if present
    local cs_res cs_wo
    cs_res=$(yq eval '.resources // "null"' "${tmp_cs}" 2>/dev/null || echo "null")
    cs_wo=$(yq eval 'del(.resources)' "${tmp_cs}" 2>/dev/null || echo "null")

    if [[ "${cs_res}" != "null" ]]; then
      # Ensure tp-cp-infra root exists and is enabled (true by default if cs present)
      yq eval '."tp-cp-infra".enabled = true' -i "${out_file}"
      # Place compute-services (minus resources) under tp-cp-infra (same as 1.10 structure), using a temp file to merge
      local tmp_cswo
      tmp_cswo=$(mktemp)
      yq eval 'del(.resources)' "${tmp_cs}" > "${tmp_cswo}"
      yq eval-all 'select(fileIndex==0) as $o | select(fileIndex==1) as $cs | $o | .["tp-cp-infra"] = ((.["tp-cp-infra"] // {}) * {"enabled": true} * $cs)' \
        "${out_file}" "${tmp_cswo}" > "${out_file}.tmp"
      mv "${out_file}.tmp" "${out_file}"
      rm -f "${tmp_cswo}"
      # Place resources under tp-cp-infra.resources.infra-compute-services
      # Build small doc for resources
      local tmp_res
      tmp_res=$(mktemp)
      printf "tp-cp-infra:\n  resources:\n    infra-compute-services:\n" > "${tmp_res}"
      # indent resources under key
      yq eval '.resources' "${tmp_cs}" | sed 's/^/      /' >> "${tmp_res}"
      yq eval-all 'select(fileIndex==0) * select(fileIndex==1)' "${out_file}" "${tmp_res}" > "${out_file}.tmp"
      mv "${out_file}.tmp" "${out_file}"
      rm -f "${tmp_res}"
    else
      # No resources; merge compute-services body into tp-cp-infra using eval-all
      local tmp_cswo
      tmp_cswo=$(mktemp)
      yq eval '.' "${tmp_cs}" > "${tmp_cswo}"
      yq eval-all 'select(fileIndex==0) as $o | select(fileIndex==1) as $cs | $o | .["tp-cp-infra"] = ((.["tp-cp-infra"] // {}) * {"enabled": true} * $cs)' \
        "${out_file}" "${tmp_cswo}" > "${out_file}.tmp"
      mv "${out_file}.tmp" "${out_file}"
      rm -f "${tmp_cswo}"
    fi
    rm -f "${tmp_cs}"
  fi

  # dnsTunnelDomain carry-over: prefer base, else bootstrap
  local base_dns bs_dns
  base_dns=$(yq eval '.global.external.dnsTunnelDomain // ""' "${base_file}")
  bs_dns=$(yq eval '.global.external.dnsTunnelDomain // ""' "${bs_file}")
  if [[ -n "${base_dns}" && "${base_dns}" != '""' ]]; then
    yq eval ".global.external.dnsTunnelDomain = \"${base_dns}\"" -i "${out_file}"
  elif [[ -n "${bs_dns}" && "${bs_dns}" != '""' ]]; then
    yq eval ".global.external.dnsTunnelDomain = \"${bs_dns}\"" -i "${out_file}"
  fi

  # Final safety net: deep-merge all remaining bootstrap values into output (excluding keys we already handled)
  # Exclude tp-cp-bootstrap (removed) and compute-services (migrated)
  local filtered_bs
  filtered_bs=$(mktemp)
  yq eval 'del(."tp-cp-bootstrap") | del(."compute-services")' "${bs_file}" > "${filtered_bs}"
  yq eval-all 'select(fileIndex==0) *+ select(fileIndex==1)' "${out_file}" "${filtered_bs}" > "${out_file}.tmp"
  mv "${out_file}.tmp" "${out_file}"
  rm -f "${filtered_bs}"

  # Ensure no lingering top-level compute-services key remains in the output
  yq eval 'del(."compute-services")' -i "${out_file}"

  # Safety check: generated file must not be empty
  if [[ ! -s "${out_file}" ]]; then
    print_error "Combined values output is empty after merge. Please verify input files and yq version (need yq v4)."
    exit 1
  fi

  # Ensure new defaults are present in generated values
  yq eval -i '."tp-cp-integration-common".enabled = true' "${out_file}"
  yq eval -i '."tp-cp-cli".enabled = true' "${out_file}"
  yq eval -i '."tp-cp-prometheus".enabled = true' "${out_file}"
  yq eval -i '."tp-cp-auditsafe".enabled = true' "${out_file}"

  print_success "Merged platform-bootstrap & platform-base values written -> ${out_file}"
}

# Transform recipe sections per 1.13 combined chart rules
transform_recipe_sections() {
  local out_file="$1"
  if yq eval 'has("tp-cp-recipes")' "${out_file}" | grep -q true; then
    log_verbose "Transforming tp-cp-recipes into component-specific sections"
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
    # Note: tp-cp-hawk-console-recipes is under tp-cp-recipes, so it's removed with above deletion
  fi

  # Cleanup: remove deprecated/disabled top-level sections if present
  yq eval -i 'del(."tp-cp-msg-contrib")' "${out_file}"
  yq eval -i 'del(."tp-cp-msg-recipes")' "${out_file}"
  yq eval -i 'del(."tp-cp-tibcohub-contrib")' "${out_file}"
  yq eval -i 'del(."tp-cp-integration")' "${out_file}"
  yq eval -i 'del(."tp-cp-hawk")' "${out_file}"
}

# Remove empty lines and trailing spaces from YAML output
tidy_yaml() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    sed -e 's/[[:space:]]\+$//' -e '/^[[:space:]]*$/d' "${f}" > "${f}.clean"
    mv "${f}.clean" "${f}"
  fi
}

fetch_release_values() {
  local rel="$1" ns="$2" out="$3"
  if helm status "${rel}" -n "${ns}" >/dev/null 2>&1; then
    # Fetch only USER-SUPPLIED VALUES (no --all), and strip the header line if present
    local tmp
    tmp=$(mktemp)
    helm get values "${rel}" -n "${ns}" > "${tmp}" || { echo "{}" > "${out}"; return; }
    if head -1 "${tmp}" | grep -q "USER-SUPPLIED VALUES"; then
      tail -n +2 "${tmp}" > "${out}"
    else
      cp "${tmp}" "${out}"
    fi
    [[ ! -s "${out}" ]] && echo "{}" > "${out}"
    rm -f "${tmp}"
  else
    print_warn "Helm release ${rel} not found in namespace ${ns}; creating empty values"
    echo "{}" > "${out}"
  fi
}

ensure_secrets_preupgrade() {
  local ns="$1" values_file="$2"
  nl
  print_info "Ensuring required secrets exist in namespace ${ns}"

  # session-keys from tibcoclusterenv if present
  local TSC_SESSION_KEY DOMAIN_SESSION_KEY
  TSC_SESSION_KEY=$(kubectl get tibcoclusterenv ops.tsc.session.key -n "${ns}" -o jsonpath='{.spec.value}' 2>/dev/null || true)
  DOMAIN_SESSION_KEY=$(kubectl get tibcoclusterenv ops.domain.session.key -n "${ns}" -o jsonpath='{.spec.value}' 2>/dev/null || true)
  if [[ -n "${TSC_SESSION_KEY}" && -n "${DOMAIN_SESSION_KEY}" ]]; then
    if kubectl get secret -n "${ns}" session-keys --ignore-not-found | grep -q session-keys; then
      print_info "session-keys secret already exists"
    else
      print_info "Creating session-keys secret from tibcoclusterenv values"
      kubectl create secret -n "${ns}" generic session-keys \
        --from-literal=TSC_SESSION_KEY="${TSC_SESSION_KEY}" \
        --from-literal=DOMAIN_SESSION_KEY="${DOMAIN_SESSION_KEY}"
    fi
  else
    if kubectl get secret -n "${ns}" session-keys --ignore-not-found | grep -q session-keys; then
      print_info "session-keys secret already exists"
    else
      print_info "Creating session-keys secret with random values"
      kubectl create secret -n "${ns}" generic session-keys \
        --from-literal=TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32) \
        --from-literal=DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
    fi
  fi

  # CP encryption secret
  local CP_ENCRYPTION_SECRET_NAME CP_ENCRYPTION_SECRET_KEY
  CP_ENCRYPTION_SECRET_NAME=$(yq eval '.global.external.cpEncryptionSecretName // "cporch-encryption-secret"' "${values_file}")
  CP_ENCRYPTION_SECRET_KEY=$(yq eval '.global.external.cpEncryptionSecretKey // "CP_ENCRYPTION_SECRET"' "${values_file}")
  if kubectl get secret -n "${ns}" "${CP_ENCRYPTION_SECRET_NAME}" --ignore-not-found | grep -q "${CP_ENCRYPTION_SECRET_NAME}"; then
    print_info "${CP_ENCRYPTION_SECRET_NAME} already exists; annotate to keep on helm upgrade"
    kubectl annotate secret "${CP_ENCRYPTION_SECRET_NAME}" helm.sh/resource-policy=keep --overwrite -n "${ns}" || true
  else
    print_info "Creating ${CP_ENCRYPTION_SECRET_NAME} with random value key=${CP_ENCRYPTION_SECRET_KEY}"
    kubectl create secret -n "${ns}" generic "${CP_ENCRYPTION_SECRET_NAME}" \
      --from-literal="${CP_ENCRYPTION_SECRET_KEY}"=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)
  fi
  nl
}

helm_upgrade_combined() {
  # Set upgrade mode and check dependencies first
  HELM_UPGRADE_MODE=true
  [[ -n "${NAMESPACE}" ]] || { print_error "--namespace is required for --helm-upgrade"; exit 1; }

  if [[ -f "${PLATFORM_OUTPUT_BASE_FILE}" ]]; then
    print_info "Using existing values file: ${PLATFORM_OUTPUT_BASE_FILE}"
  else
    TEMP_DIR=$(mktemp -d)
    local bs_vals="${TEMP_DIR}/bs.yaml" base_vals="${TEMP_DIR}/base.yaml"

    print_info "Fetching Helm values from existing releases in namespace ${NAMESPACE}"
    fetch_release_values "${PLATFORM_BOOTSTRAP_RELEASE}" "${NAMESPACE}" "${bs_vals}"
    fetch_release_values "${PLATFORM_BASE_RELEASE}" "${NAMESPACE}" "${base_vals}"

    print_info "Combining values into ${PLATFORM_OUTPUT_BASE_FILE}"
    combine_values_files "${base_vals}" "${bs_vals}" "${PLATFORM_OUTPUT_BASE_FILE}"
    transform_recipe_sections "${PLATFORM_OUTPUT_BASE_FILE}"
    tidy_yaml "${PLATFORM_OUTPUT_BASE_FILE}"
  fi

  ensure_secrets_preupgrade "${NAMESPACE}" "${PLATFORM_OUTPUT_BASE_FILE}"

  # Show environment variable status only when enabled
  if [[ "${UPGRADE_MINOR_VERSIONS}" == "true" ]]; then
    print_info "Environment: UPGRADE_MINOR_VERSIONS=true (1.13.x minor version upgrades enabled with confirmation prompts)"
  fi

  # Inline validation of current deployment versions
  nl
  print_info "Validating current deployment versions..."
  local FAILED_STATES="failed pending-install pending-rollback pending-upgrade superseded"
  if helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    local base_status base_app
    base_status=$(helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    base_app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
    print_info "${PLATFORM_BASE_RELEASE} current status: ${base_status}, app_version: ${base_app}"

    if [[ "${base_status}" == "deployed" ]]; then
      if [[ "${base_app}" =~ ^1\.13\. ]]; then
        if [[ "${UPGRADE_MINOR_VERSIONS}" == "true" ]]; then
          nl
          print_warn "${PLATFORM_BASE_RELEASE} is already deployed at version ${base_app}"
          print_warn "You are attempting to upgrade/re-deploy to version ${PLATFORM_CHART_VERSION}"
          print_warn "This will perform a minor version upgrade within the 1.13.x series"
          read -p "Do you want to proceed with the 1.13.x minor version upgrade? (yes/no): " proceed_minor
          if [[ "${proceed_minor}" != "yes" ]]; then
            print_info "Minor version upgrade cancelled by user."
            exit 0
          fi
        else
          nl
          print_error "Current ${PLATFORM_BASE_RELEASE} version is '${base_app}'. This script only supports standard upgrades from 1.8.0 to 1.13.0 by default."
          print_error "To enable 1.13.x minor version upgrades, set UPGRADE_MINOR_VERSIONS=true"
          exit 1
        fi
      elif [[ "${base_app}" != "1.8.0" ]]; then
        nl
        print_error "Current ${PLATFORM_BASE_RELEASE} version is '${base_app}', expected '1.8.0'"
        exit 1
      fi
    else
      # Non-deployed state
      if echo " ${FAILED_STATES} " | grep -q " ${base_status} "; then
        if [[ "${base_app}" =~ ^1\.13\. ]]; then
          nl
          print_warn "${PLATFORM_BASE_RELEASE} is already at app_version ${base_app} but in '${base_status}' state."
          read -p "Do you want to retry the 1.13.x upgrade for ${PLATFORM_BASE_RELEASE}? (yes/no): " retry
          if [[ "${retry}" != "yes" ]]; then
            print_info "Skipping upgrade retry per user choice."
            exit 0
          fi
        else
          print_error "Upgrade blocked: ${PLATFORM_BASE_RELEASE} status is '${base_status}'. Resolve (e.g., rollback) and retry."
          exit 1
        fi
      else
        print_error "Upgrade blocked: ${PLATFORM_BASE_RELEASE} status is '${base_status}'. Expected 'deployed' or a retry-able failed state."
        exit 1
      fi
    fi
  else
    print_warn "${PLATFORM_BASE_RELEASE} release not found in namespace ${NAMESPACE}. Proceeding assuming pre-1.13 split releases exist."
  fi
  if helm status "${PLATFORM_BOOTSTRAP_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    local bs_status bs_app
    bs_status=$(helm status "${PLATFORM_BOOTSTRAP_RELEASE}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    bs_app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BOOTSTRAP_RELEASE}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
    print_info "${PLATFORM_BOOTSTRAP_RELEASE} current status: ${bs_status}, app_version: ${bs_app}"
    if [[ "${bs_status}" == "deployed" ]]; then
      if [[ "${bs_app}" =~ ^1\.13\. ]]; then
        if [[ "${UPGRADE_MINOR_VERSIONS}" == "true" ]]; then
          nl
          print_warn "${PLATFORM_BOOTSTRAP_RELEASE} is already deployed at version ${bs_app}"
          print_warn "You are attempting to upgrade/re-deploy to version ${PLATFORM_CHART_VERSION}"
          print_warn "This will perform a minor version upgrade within the 1.13.x series"
          read -p "Do you want to proceed with the 1.13.x minor version upgrade? (yes/no): " proceed_bs_minor
          if [[ "${proceed_bs_minor}" != "yes" ]]; then
            print_info "Minor version upgrade cancelled by user."
            exit 0
          fi
        else
          nl
          print_error "Current ${PLATFORM_BOOTSTRAP_RELEASE} version is '${bs_app}'. This script only supports standard upgrades from 1.8.0 to 1.13.0 by default."
          print_error "To enable 1.13.x minor version upgrades, set UPGRADE_MINOR_VERSIONS=true"
          exit 1
        fi
      elif [[ "${bs_app}" != "1.8.0" ]]; then
        nl
        print_error "Current ${PLATFORM_BOOTSTRAP_RELEASE} version is '${bs_app}', expected '1.8.0'"
        exit 1
      fi
    else
      if echo " ${FAILED_STATES} " | grep -q " ${bs_status} "; then
        if [[ "${bs_app}" =~ ^1\.13\. ]]; then
          nl
          print_warn "${PLATFORM_BOOTSTRAP_RELEASE} is already at app_version ${bs_app} but in '${bs_status}' state."
          read -p "Do you want to retry the 1.13.x upgrade for ${PLATFORM_BOOTSTRAP_RELEASE}? (yes/no): " retry_bs
          if [[ "${retry_bs}" != "yes" ]]; then
            print_info "Skipping upgrade retry per user choice."
            exit 0
          fi
        else
          print_error "Upgrade blocked: ${PLATFORM_BOOTSTRAP_RELEASE} status is '${bs_status}'. Resolve (e.g., rollback) and retry."
          exit 1
        fi
      else
        print_error "Upgrade blocked: ${PLATFORM_BOOTSTRAP_RELEASE} status is '${bs_status}'. Expected 'deployed' or a retry-able failed state."
        exit 1
      fi
    fi
  fi

  nl
  print_info "Updating Helm repository ${TP_HELM_REPO_NAME}..."
  helm repo update "${TP_HELM_REPO_NAME}"
  print_success "Repository updated successfully"

  # Pre-upgrade cleanup: silent deletion of legacy services (if present) so upgrade can recreate them
  {
    # Detect resource-set-operator service name dynamically (handles suffix like -cp1)
    local __rso_svc
    __rso_svc=$(kubectl get svc -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.items[].metadata.name | select(test("^resource-set-operator(-[a-z0-9-]+)?$"))' | head -n1)

    kubectl delete svc -n "${NAMESPACE}" router --ignore-not-found >/dev/null 2>&1 &
    kubectl delete svc -n "${NAMESPACE}" hybrid-proxy --ignore-not-found >/dev/null 2>&1 &
    if [[ -n "${__rso_svc}" ]]; then
      kubectl delete svc -n "${NAMESPACE}" "${__rso_svc}" --ignore-not-found >/dev/null 2>&1 &
    fi
    kubectl delete svc -n "${NAMESPACE}" compute-services --ignore-not-found >/dev/null 2>&1 &
    wait
  } || true

  nl
  print_info "Upgrading ${PLATFORM_BASE_RELEASE} to version ${PLATFORM_CHART_VERSION} (single combined chart)"
  helm upgrade "${PLATFORM_BASE_RELEASE}" "${TP_HELM_REPO_NAME}/tibco-cp-base" \
    --version "${PLATFORM_CHART_VERSION}" \
    -n "${NAMESPACE}" \
    -f "${PLATFORM_OUTPUT_BASE_FILE}" \
    --take-ownership \
    --wait --timeout 45m

  print_success "Helm upgrade completed successfully"

  verify_helm_upgrades
}

# Verify the unified chart upgrade
verify_helm_upgrades() {
  nl
  # Expected app_version should be the base semantic version (e.g., 1.13.0) even if chart has a pre-release tag
  # Derive by stripping any '-' suffix from PLATFORM_CHART_VERSION
  local EXPECTED_POST_APP_VERSION="${PLATFORM_CHART_VERSION%%-*}"
  if helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    local app chart
    app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE}$" -o json | jq -r '.[0].app_version // "unknown"')
    chart=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE}$" -o json | jq -r '.[0].chart // "unknown"')
    print_success "Helm chart upgrade successful to chart version ${PLATFORM_CHART_VERSION}. ${PLATFORM_BASE_RELEASE} upgraded: app_version=${app}, chart=${chart}"
    nl
    if [[ "${app}" != "${EXPECTED_POST_APP_VERSION}" ]]; then
      print_error "${PLATFORM_BASE_RELEASE} app_version (${app}) does not match expected ${EXPECTED_POST_APP_VERSION}"
    fi
    if [[ "${chart}" != *"-${PLATFORM_CHART_VERSION}" ]]; then
      print_error "${PLATFORM_BASE_RELEASE} chart (${chart}) does not match desired version ${PLATFORM_CHART_VERSION}"
    fi
  else
    print_error "${PLATFORM_BASE_RELEASE} upgrade failed or release not found"
  fi
  print_info "Checking pod readiness in namespace ${NAMESPACE}..."
  if kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -v "Running\|Completed" | grep -q .; then
    print_warn "Some pods are not in Running/Completed state:"
    kubectl get pods -n "${NAMESPACE}" --no-headers | grep -v "Running\|Completed" || true
  else
    print_success "All pods are in Running/Completed state"
  fi
  nl
  print_info "NOTE: This script does NOT perform application-level or functional tests of the upgraded chart."
  print_info "It assumes chart values are correct, performs the upgrade to ${PLATFORM_CHART_VERSION},"
  print_info "and verifies that the pods in namespace '${NAMESPACE}' are in Running/Completed state."
  print_info "We recommend you run your own post-upgrade tests as required."
  print_success "Upgrade verification completed"
}

# Cleanup remaining bootstrap resources after successful upgrade
cleanup_bootstrap_resources() {
  nl
  print_info "Bootstrap Resources Cleanup"
  print_info "==========================="
  print_warn "We don't want to uninstall the platform-bootstrap release using 'helm uninstall',"
  print_warn "as this will delete resources still managed by the ${PLATFORM_BASE_RELEASE} release after the upgrade."
  print_warn "Instead, we will only delete the platform-bootstrap Helm secrets and clean up any orphaned resources."
  nl
  # Determine expected base version (strip any pre-release tags); require 1.13.0 explicitly
  local EXPECTED_BASE_VER="${PLATFORM_CHART_VERSION%%-*}"
  EXPECTED_BASE_VER="1.13.0"

  # Ask for base and bootstrap release names (defaults to current variables)
  local BASE_REL_ANS BS_REL_ANS
  read -p "Enter base chart release name (default: ${PLATFORM_BASE_RELEASE}): " BASE_REL_ANS
  [[ -n "${BASE_REL_ANS}" ]] && PLATFORM_BASE_RELEASE="${BASE_REL_ANS}"
  read -p "Enter bootstrap chart release name (default: ${PLATFORM_BOOTSTRAP_RELEASE}): " BS_REL_ANS
  [[ -n "${BS_REL_ANS}" ]] && PLATFORM_BOOTSTRAP_RELEASE="${BS_REL_ANS}"

  # Ensure namespace (ask after release names for consistent flow)
  while [[ -z "${NAMESPACE}" ]]; do
    read -p "Enter namespace where platform-base is deployed: " NAMESPACE
    [[ -n "${NAMESPACE}" ]] || print_error "Namespace is required"
  done

  # Fetch status and app_version of platform-base
  local base_status base_app
  if helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    base_status=$(helm status "${PLATFORM_BASE_RELEASE}" -n "${NAMESPACE}" -o json 2>/dev/null | jq -r '.info.status // "unknown"')
    base_app=$(helm list -n "${NAMESPACE}" -f "^${PLATFORM_BASE_RELEASE}$" -o json 2>/dev/null | jq -r '.[0].app_version // "unknown"')
  else
    print_error "${PLATFORM_BASE_RELEASE} not found in namespace ${NAMESPACE}. Aborting cleanup."
    return 1
  fi

  nl
  print_info "${PLATFORM_BASE_RELEASE} current status: ${base_status}, app_version: ${base_app}"
  if [[ "${base_status}" != "deployed" || "${base_app}" != "${EXPECTED_BASE_VER}" ]]; then
    print_error "Cleanup blocked: Base chart must be deployed and at app_version ${EXPECTED_BASE_VER}."
    print_error "Current status='${base_status}', app_version='${base_app}'."
    return 1
  fi

  # Final confirmation from user
  nl
  read -p "Has your base chart been upgraded to 1.13.0 and is in 'deployed' state? (yes/no): " confirm
  if [[ "${confirm}" != "yes" ]]; then
    print_info "Cleanup cancelled by user."
    return 0
  fi

  # Perform cleanup (step-wise with messages)
  nl
  local cleanup_failed=false

  # 1) Clean up roles and rolebindings (label-based first)
  print_info "Cleaning up roles and rolebindings..."
  if kubectl delete role,rolebinding -n "${NAMESPACE}" -l app.kubernetes.io/instance="${PLATFORM_BOOTSTRAP_RELEASE}" >/dev/null 2>&1; then
    print_success "Roles and rolebindings cleaned up successfully"
  else
    # Fallback to name patterns if labels are missing
    if kubectl get role -n "${NAMESPACE}" -o name 2>/dev/null | grep -q '^role/cp-bootstrap-'; then
      kubectl delete -n "${NAMESPACE}" $(kubectl get role -n "${NAMESPACE}" -o name | grep '^role/cp-bootstrap-') --ignore-not-found >/dev/null 2>&1 || true
    fi
    if kubectl get rolebinding -n "${NAMESPACE}" -o name 2>/dev/null | grep -q '^rolebinding/cp-bootstrap-'; then
      kubectl delete -n "${NAMESPACE}" $(kubectl get rolebinding -n "${NAMESPACE}" -o name | grep '^rolebinding/cp-bootstrap-') --ignore-not-found >/dev/null 2>&1 || true
    fi
    print_warn "No roles/rolebindings found or failed to delete (this may be expected)"
  fi

  # 2) Clean up orphaned deployments and HPAs
  print_info "Cleaning up orphaned deployments and HPAs..."
  local resources_to_delete
  resources_to_delete="deployment/hybrid-proxy deployment/resource-set-operator deployment/router hpa/hybrid-proxy hpa/router deployment/compute-services hpa/compute-services configmap/compute-services-monitor-services"
  if kubectl delete -n "${NAMESPACE}" ${resources_to_delete} >/dev/null 2>&1; then
    print_success "Orphaned deployments and HPAs cleaned up successfully"
  else
    print_warn "Some resources not found or failed to delete (this may be expected if already managed by ${PLATFORM_BASE_RELEASE} release)"
  fi

  # 3) Clean up platform-bootstrap Helm secrets
  print_info "Cleaning up platform-bootstrap Helm secrets..."
  if kubectl delete secret -n "${NAMESPACE}" -l "owner=helm,name=${PLATFORM_BOOTSTRAP_RELEASE}" >/dev/null 2>&1; then
    print_success "Platform-bootstrap Helm secrets cleaned up successfully"
  else
    print_warn "No platform-bootstrap Helm secrets found or failed to delete"
    cleanup_failed=true
  fi

  nl
  if [[ "${cleanup_failed}" == "false" ]]; then
    print_success "Platform-bootstrap cleanup completed successfully"
    return 0
  else
    print_warn "Platform-bootstrap cleanup completed with some warnings"
    return 0
  fi
}

main() {
  print_info "TIBCO Control Plane Upgrade Script - 1.8.0 to 1.13.0"
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
}

# Execute main function
main "$@"
