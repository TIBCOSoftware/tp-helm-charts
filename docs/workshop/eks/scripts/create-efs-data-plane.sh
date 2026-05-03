#!/bin/bash
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

set +x

echo "Export Global variables"
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"${CLUSTER_NAME}"}
export TP_STORAGE_CLASS_EFS=${TP_STORAGE_CLASS_EFS:-"efs-sc"}

[ "${TP_CLUSTER_NAME}" != "" ] || { echo "Cluster name is not specified"; exit 1; }

_ret=''
./create-efs.sh "${TP_STORAGE_CLASS_EFS}" "${TP_CLUSTER_NAME}"
_ret=$?
[ ${_ret} -eq 0 ] || { echo "Failed to create or detect existing EFS"; }
exit ${_ret}