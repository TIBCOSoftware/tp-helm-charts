#!/bin/bash

# need to output empty string otherwise will output null
EFS_ID=$(kubectl get sc ${DP_STORAGE_CLASS_EFS} -oyaml | yq eval '.parameters.fileSystemId // ""')

echo "deleting all ingress objects"
kubectl delete ingress -A --all

echo "sleep 2 minutes"
sleep 120

echo "deleting all installed charts with no layer labels"
helm ls --selector '!layer' -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r line; do
  release=$(echo $line | awk '{print $1}')
  namespace=$(echo $line | awk '{print $2}')
  helm uninstall -n "$namespace" "$release"
done

for (( _chart_layer=2 ; _chart_layer>=0 ; _chart_layer-- ));
do
  echo "deleting all installed charts with layer ${_chart_layer} labels"
  helm ls --selector "layer=${_chart_layer}" -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r line; do
    release=$(echo $line | awk '{print $1}')
    namespace=$(echo $line | awk '{print $2}')
    helm uninstall -n "$namespace" "$release"
  done
done

if [ "${EFS_ID}" != "" ]; then
  echo "detected EFS_ID: ${EFS_ID} now deleting EFS"
  aws efs describe-mount-targets --file-system-id ${EFS_ID} > mount_targets.json
  mount_target_ids=$(jq -r '.MountTargets[].MountTargetId' mount_targets.json)
  for id in ${_mount_target_ids[@]}; do
    echo "Deleting Mount Target with ID: $id"
    aws efs delete-mount-target --mount-target-id $id
  done
  echo "Mount Target deletion is in progress...sleep 2 minutes"
  sleep 120
  aws efs delete-file-system --file-system-id ${EFS_ID}

  EFS_SG_ID=$(aws ec2 describe-security-groups --filters Name=tag:Cluster,Values=${DP_CLUSTER_NAME} --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
  if [ "${EFS_SG_ID}" != "" ]; then
    echo "detected EFS_SG_ID: ${EFS_SG_ID} now deleting EFS_SG_ID"
    aws ec2 delete-security-group --group-id ${EFS_SG_ID}
  fi
fi

echo "deleting cluster"
eksctl delete cluster --name=${DP_CLUSTER_NAME} --disable-nodegroup-eviction --force
