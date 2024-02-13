#!/bin/bash

set +x

echo "Export Global variables"
export DP_CLUSTER_NAME=${DP_CLUSTER_NAME:-"dp-cluster"}
export DP_STORAGE_CLASS_EFS=${DP_STORAGE_CLASS_EFS:-"efs-sc"}

_ret=''
./create-efs.sh "${DP_STORAGE_CLASS_EFS}" "${DP_CLUSTER_NAME}"
_ret=$?
[ ${_ret} -eq 0 ] || { echo "Failed to create or detect existing EFS"; }
exit ${_ret}