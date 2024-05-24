#!/bin/bash
set +x

_ret=''
_deleted=''
_status=''

echo "Export Global variables"
export CP_CLUSTER_NAME=${CP_CLUSTER_NAME:-"cp-cluster-infra"}
export CP_STORAGE_CLASS_EFS=${CP_STORAGE_CLASS_EFS:-"efs-sc"}
export CP_CROSSPLANE_ENABLED=${CP_CROSSPLANE_ENABLED:-"true"}

# need to output empty string otherwise will output null
_efs_id=$(kubectl get sc ${CP_STORAGE_CLASS_EFS} -oyaml | yq eval '.parameters.fileSystemId // ""')

echo "Deleting all installed charts with no layer labels"
helm ls --selector '!layer' -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r _line; do
  _release=$(echo ${_line} | awk '{print $1}')
  _namespace=$(echo ${_line} | awk '{print $2}')
  helm uninstall -n "${_namespace}" "${_release}"
  sleep 60 # sleep to wait for uninstallation
done

for (( _chart_layer=4 ; _chart_layer>=0 ; _chart_layer-- ));
do
  echo "Deleting all installed charts with layer ${_chart_layer} labels"
  helm ls --selector "layer=${_chart_layer}" -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r _line; do
    _release=$(echo ${_line} | awk '{print $1}')
    _namespace=$(echo ${_line} | awk '{print $2}')
    helm uninstall -n "${_namespace}" "${_release}"
    sleep 60 # sleep to wait for uninstallation
  done
done

if [ "${CP_CROSSPLANE_ENABLED}" == "false" ]; then
  if [ "${_efs_id}" != "" ]; then
    echo "Detected EFS_ID: ${_efs_id}; Now deleting EFS"
    aws efs describe-mount-targets --file-system-id ${_efs_id} > mount_targets.json
    _mount_target_ids=$(jq -r '.MountTargets[].MountTargetId' mount_targets.json)
    for _id in ${_mount_target_ids[@]}; do
      echo "Deleting Mount Target with ID: ${_id}"
      aws efs delete-mount-target --mount-target-id ${_id}
    done
    echo "Mount Target deletion is in progress...Sleep 2 minutes"
    sleep 120
    aws efs delete-file-system --file-system-id ${_efs_id}

    _efs_sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Resource,Values=${CP_CLUSTER_NAME}-efs --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
    if [ "${_efs_sg_id}" != "" ]; then
      echo "Detected EFS_SG_ID: ${_efs_sg_id} now deleting EFS_SG_ID"
      aws ec2 delete-security-group --group-id ${_efs_sg_id}
    fi
    rm -rf mount_targets.json
  fi

  echo "Deleting RDS db instance"
  aws rds delete-db-instance --db-instance-identifier ${CP_CLUSTER_NAME}-db --skip-final-snapshot --no-paginate

  # echo "Deleting Redis"
  # aws elasticache delete-replication-group --replication-group-id ${CP_CLUSTER_NAME}-redis --no-retain-primary-cluster --no-paginate

  echo "Waiting to delete RDS db instance"
  aws rds wait db-instance-deleted --db-instance-identifier ${CP_CLUSTER_NAME}-db
  _deleted=$?
  [ ${_deleted} -eq 0 ] || { echo "### ERROR: Failed to delete RDS db instance ${CP_CLUSTER_NAME}-db after maximum 30 minutes (30 seconds, 60 checks)"; echo "Error code ${_deleted}"; }
  if [ ${_deleted} -ne 0 ]; then
    echo "Waiting additional 5 minutes to delete RDS db instance"
    for n in {1..5};
    do
      _status=$(aws rds describe-db-instances --db-instance-identifier ${CP_CLUSTER_NAME}-db --query DBInstances[0].DBInstanceStatus --output text)
      _ret=$?
      if [ ${_ret} -eq 0 -o "${_status}" -eq "deleting" ]; then
        # sleep for a minute
        echo "RDS db instance ${CP_CLUSTER_NAME}-db is in ${_status} state; Waiting for 1 more minute to check status"
        sleep 60
      elif [ ${_ret} -eq 254 -o "${_status}" -eq "" ]; then
        # return code 254 indicates that db instance is not found i.e. deleted
        break
      else
        echo "### ERROR: deleting ${CP_CLUSTER_NAME}-db did not finish correctly; Exiting!"
        echo "### Please check AWS Console and re-run the script when ${CP_CLUSTER_NAME}-db is deleted"
        exit ${_ret}
      fi
    done
  fi

  # echo "Waiting to delete Redis"
  # aws elasticache wait replication-group-deleted --replication-group-id ${CP_CLUSTER_NAME}-redis
  # _deleted=$?
  # [ ${_deleted} -eq 0 ] || { echo "### ERROR: Failed to delete Redis replication group ${CP_CLUSTER_NAME}-redis after 10 minutes (15 seconds, 40 checks)"; echo "Error code ${_deleted}"; }
  # if [ ${_deleted} -ne 0 ]; then
  #   echo "Waiting additional 5 minutes to delete Redis replication group"
  #   for n in {1..5};
  #   do
  #     _status=$(aws elasticache describe-replication-groups --replication-group-id ${CP_CLUSTER_NAME}-redis --query ReplicationGroups[0].Status --output text)
  #     _ret=$?
  #     if [ ${_ret} -eq 0 -o "${_status}" -eq "deleting" ]; then
  #       # sleep for a minute
  #       echo "Redis replication group ${CP_CLUSTER_NAME}-redis is in ${_status} state; Waiting for 1 more minute to check status"
  #       sleep 60
  #     elif [ ${_ret} -eq 254 -o "${_status}" -eq "" ]; then
  #       # return code 254 indicates that db instance is not found
  #       break
  #     else
  #       echo "### ERROR: deleting ${CP_CLUSTER_NAME}-redis operation did not finish correctly; Exiting!"
  #       echo "### ### Please check AWS Console and re-run the script when ${CP_CLUSTER_NAME}-redis is deleted"
  #       exit ${_ret}
  #     fi
  #   done
  # fi

  echo "Deleting RDS db subnet group"
  aws rds delete-db-subnet-group --db-subnet-group-name ${CP_CLUSTER_NAME}-subnet-group

  # echo "Deleting Cache subnet group"
  # aws elasticache delete-cache-subnet-group --cache-subnet-group-name ${CP_CLUSTER_NAME}-cache-subnet-group --no-paginate

  echo "Deleting RDS security group"
  _rds_sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Resource,Values=${CP_CLUSTER_NAME}-rds --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
  if [ "${_rds_sg_id}" != "" ]; then
    echo "Detected RDS_SG_ID: ${_rds_sg_id}; Now deleting RDS_SG_ID"
    aws ec2 delete-security-group --group-id ${_rds_sg_id}
  fi

  # echo "Deleting Redis security group"
  # _redis_sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Resource,Values=${CP_CLUSTER_NAME}-redis --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
  # if [ "${_redis_sg_id}" != "" ]; then
  #   echo "Detected Redis security group id: ${_redis_sg_id}; Now deleting"
  #   aws ec2 delete-security-group --group-id ${_redis_sg_id}
  # fi
fi

if [ "${CP_CROSSPLANE_ENABLED}" == "true" ]; then
  echo "Detaching role policy to IAM role ${CP_CROSSPLANE_ROLE}"
  aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --role-name ${CP_CROSSPLANE_ROLE}
  _ret=$?
  [ ${_ret} -eq 0 ] || { echo "### ERROR: failed to detach policy to IAM role for crossplane. Please re-run the script"; exit ${_ret}; }

  echo "Deleting crossplane role"
  aws iam delete-role --role-name ${CP_CROSSPLANE_ROLE}
  _ret=$?
  [ ${_ret} -eq 0 ] || { echo "### ERROR: failed to delete IAM role for crossplane. Please re-run the script"; exit ${_ret}; }
fi

echo "Deleting cluster"
eksctl delete cluster --name=${CP_CLUSTER_NAME} --disable-nodegroup-eviction --force
