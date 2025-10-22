#!/bin/bash

#
# © 2025 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

# Tested with: GNU bash, version 5.2.21(1)-release
#
# Usage:
#   ./get-image-tags.sh fetch <namespace>      - Fetch all container images and their versions from a namespace
#   ./get-image-tags.sh compare <namespace> <previous_image_file> - Compare current images with previous version
#
# Note: The previous_image_file should be in the following format:
#   Image                                    Version
#   -----                                    -------
#   <<image-name>>                           <<image-version>>

# Fetch current images and versions from a Kubernetes namespace
fetch_images() {
    local namespace="${1}"

    echo "Fetching current images from namespace: ${namespace} ..."
    echo
    printf "%-40s %-20s\n" "Image" "Version"
    printf "%-40s %-20s\n" "-----" "-------"

    # Get pod images, format them as "image version", and sort uniquely
    kubectl get pods -n "${namespace}" -o json | \
    grep -oP '"image": *"\K[^"]+' | \
    awk -F'/' '{print $NF}' | \
    awk -F':' '{image=$1; version=$2 ? $2 : "latest"; printf "%-40s %-20s\n", image, version}' | \
    sort -u
}

# Compare current images with a previous image list
compare_images() {
    local namespace="${1}"
    local previous_image_file="${2}"
    local tmp_current="/tmp/current_images_$$.txt"
    local tmp_previous="/tmp/previous_images_$$.txt"
    local changes=0

    # Check if previous image file exists
    if [ ! -f "${previous_image_file}" ]; then
        echo "Previous image file not found: ${previous_image_file}"
        exit 1
    fi

    # Fetch current images and save to temp file
    kubectl get pods -n "${namespace}" -o json | \
    grep -oP '"image": *"\K[^"]+' | \
    awk -F'/' '{print $NF}' | \
    awk -F':' '{print $1, ($2 ? $2 : "latest")}' | \
    sort -u > "${tmp_current}"

    # Prepare previous image list (skip headers) and save to temp file
    tail -n +2 "${previous_image_file}" | sort -u > "${tmp_previous}"

    echo
    echo "Image:Tag Changes Compared to Previous Release:"
    echo
    printf "%-40s %-20s %-20s\n" "Image" "Previous Version" "Current Version"
    printf "%-40s %-20s %-20s\n" "-----" "----------------" "---------------"
    
    # Compare previous and current images
    while read -r previous_line; do
        local previous_image
        local previous_version
        previous_image=$(echo "${previous_line}" | awk '{print $1}')
        previous_version=$(echo "${previous_line}" | awk '{print $2}')
        local current_version
        current_version=$(grep "^${previous_image} " "${tmp_current}" | awk '{print $2}')

        if [ -n "${current_version}" ] && [ "${previous_version}" != "${current_version}" ]; then
            printf "%-40s %-20s %-20s\n" "${previous_image}" "${previous_version}" "${current_version}"
            changes=$((${changes} + 1))
        fi
    done < "${tmp_previous}"

    # If no changes found
    if [ "${changes}" -eq 0 ]; then
        echo
        echo "No image version changes compared to previous release."
    fi

    # Cleanup temp files
    rm -f "${tmp_current}" "${tmp_previous}"
}

# Main entry point
if [[ "${1}" == "fetch" ]]; then
    if [[ -z "${2}" ]]; then
        echo "Usage: ${0} fetch <namespace>"
        exit 1
    fi
    fetch_images "${2}"

elif [[ "${1}" == "compare" ]]; then
    if [[ -z "${2}" || -z "${3}" ]]; then
        echo "Usage: ${0} compare <namespace> <previous_image_file>"
        exit 1
    fi
    compare_images "${2}" "${3}"

else
    echo "Usage:"
    echo "  ${0} fetch <namespace>"
    echo "  ${0} compare <namespace> <previous_image_file>"
    exit 1
fi
