#!/bin/bash

#
# © 2023 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

# usage:
# generator.sh <chart-name>

export CHART_NAME=${1}

[[ -z "${CHART_NAME}" ]] && { echo "Please specify chart name as parameter" ; exit 1 ; }

cp -R template "${CHART_NAME}"

# for yq 4
yq eval -i '.name = env(CHART_NAME)' "${CHART_NAME}"/Chart.yaml || { echo "error on yq" ; exit 1 ; }
yq eval -i '.description = env(CHART_NAME)' "${CHART_NAME}"/Chart.yaml || { echo "error on yq" ; exit 1 ; }
yq eval -i '.name = env(CHART_NAME)' "${CHART_NAME}"/values.yaml || { echo "error on yq" ; exit 1 ; }
