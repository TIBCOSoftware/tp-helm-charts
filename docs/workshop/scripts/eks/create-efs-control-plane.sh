#!/bin/bash

set +x

echo "Export Global variables"
export CP_CLUSTER_NAME=${CP_CLUSTER_NAME:-"cp-cluster-infra"}
export CP_STORAGE_CLASS_EFS=${CP_STORAGE_CLASS_EFS:-"efs-sc"}

_ret=''
./create-efs.sh "${CP_STORAGE_CLASS_EFS}" "${CP_CLUSTER_NAME}"
_ret=$?
[ ${_ret} -eq 0 ] || { echo "Failed to create or detect existing EFS"; }
exit ${_ret}