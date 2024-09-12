#!/bin/bash

echo "Export Global variables"
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"${CLUSTER_NAME}"}
export TP_STORAGE_CLASS_EFS=${TP_STORAGE_CLASS_EFS:-"efs-sc"}
export TP_CROSSPLANE_ENABLED=${TP_CROSSPLANE_ENABLED:-"${CROSSPLANE_ENABLED}"}
export TP_DELETE_CLUSTER=${TP_DELETE_CLUSTER:-"true"}

[ "${TP_CLUSTER_NAME}" != "" ] || { echo "Cluster name is not specified"; exit 1; }
[ "${TP_CROSSPLANE_ENABLED}" != "" ] || { echo "Crossplane enabled flag is not specified"; exit 1; }
[ "${TP_DELETE_CLUSTER}" != "" ] || { echo "Delete cluster flag is not specified"; exit 1; }

# need to output empty string otherwise will output null
_efs_id=$(kubectl get sc ${TP_STORAGE_CLASS_EFS} -oyaml --ignore-not-found=true | yq eval '.parameters.fileSystemId // ""')
[ "${_efs_id}" != "" ] || { echo "Storage class ${TP_STORAGE_CLASS_EFS} not found, continuing with deletion of other objects"; }

>/dev/null 2>&1
echo "Deleting all ingress objects"
kubectl delete ingress -A --all

echo "Sleep 2 minutes"
sleep 120

echo "Deleting all installed charts with no layer labels"
helm ls --selector '!layer' -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r line; do
  release=$(echo $line | awk '{print $1}')
  namespace=$(echo $line | awk '{print $2}')
  helm uninstall -n "$namespace" "$release"
done

for (( _chart_layer=2 ; _chart_layer>=0 ; _chart_layer-- ));
do
  echo "Deleting all installed charts with layer ${_chart_layer} labels"
  helm ls --selector "layer=${_chart_layer}" -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r line; do
    release=$(echo $line | awk '{print $1}')
    namespace=$(echo $line | awk '{print $2}')
    helm uninstall -n "$namespace" "$release"
  done
done

if [ "${TP_CROSSPLANE_ENABLED}" == "false" ]; then
  if [ "${_efs_id}" != "" ]; then
    echo "Detected EFS_ID: ${_efs_id} now deleting EFS"
    aws efs describe-mount-targets --file-system-id ${_efs_id} > mount_targets.json
    mount_target_ids=$(jq -r '.MountTargets[].MountTargetId' mount_targets.json)
    for id in ${_mount_target_ids[@]}; do
      echo "Deleting Mount Target with ID: $id"
      aws efs delete-mount-target --mount-target-id $id
    done
    echo "Mount Target deletion is in progress...sleep 2 minutes"
    sleep 120
    aws efs delete-file-system --file-system-id ${_efs_id}

    _efs_sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Cluster,Values=${TP_CLUSTER_NAME} --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
    if [ "${_efs_sg_id}" != "" ]; then
      echo "Detected EFS_SG_ID: ${_efs_sg_id} now deleting EFS_SG_ID"
      aws ec2 delete-security-group --group-id ${_efs_sg_id}
    fi
  fi
fi

if [ "${TP_DELETE_CLUSTER}" == "true" ]; then
  echo "Deleting cluster"
  eksctl delete cluster --name=${TP_CLUSTER_NAME} --disable-nodegroup-eviction --force
else 
  echo "Not deleting cluster"
fi