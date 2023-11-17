#!/bin/bash

#
# Copyright (c) 2023 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#

# need to install
# * ct: brew install chart-testing
# * yamllint: brew install yamllint

# run this script under chart folder like
# ../dev/lint-chart-locally.sh <chart name>

_chart_name=${1}

ct lint --config ../.github/linters/ct.yaml --charts ${_chart_name}
