#!/bin/bash
set +x

_ret=''
_deleted=''
_status=''
_db_parameter_group=''
_db_cluster_parameter_group=''
_db_subnet_group=''
_db_security_group_name=''
_db_security_group_id=''

usage() {
  echo "Make sure following variables are set before running the script"
  echo -e "export TP_CLUSTER_NAME"
  echo -e "export TP_CLUSTER_REGION"
  echo -e "export TP_STORAGE_CLASS_EFS (Default value: efs-sc)"
  echo -e "export TP_CROSSPLANE_ENABLED (Allowed values: true/false)"
  echo -e "export TP_DELETE_CLUSTER (Allowed values: true/false)"
  echo -e "export TP_DELETE_TIBCO_RESOURCE_SET (Default value: true)"
  echo -e "export TP_CROSSPLANE_ROLE (Default value: \${TP_CLUSTER_NAME}-crossplane-\${TP_CLUSTER_REGION})"
  echo -e "export CP_RESOURCE_PREFIX (Required, if you are using crossplane to create AWS resources)"
  exit 0
}

# RDS db instance is a special case since it takes significant time for deletion
function check_rds_db_instance_deletion() {
  _db_name="${1}"
  aws rds wait db-instance-deleted --db-instance-identifier ${_db_name}
  _deleted=$?
  if [ ${_deleted} -eq 0 ]; then
    echo "RDS db instance ${_db_name} deleted successfully"
    return 0
  else
    echo "### ERROR: Failed to delete RDS db instance ${_db_name} after maximum 30 minutes (30 seconds, 60 checks)"
    echo "Error code ${_deleted}"
    echo "Waiting additional 5 minutes to delete RDS db instance"
    for n in {1..5};
    do
      _status=$(aws rds describe-db-instances --db-instance-identifier ${_db_name} --query DBInstances[0].DBInstanceStatus --output text)
      _ret=$?
      if [ ${_ret} -eq 0 -o "${_status}" -eq "deleting" ]; then
        # sleep for a minute
        echo "RDS db instance ${_db_name} is in ${_status} state; Waiting for 1 more minute to check status"
        sleep 60
      elif [ ${_ret} -eq 254 -o "${_status}" -eq "" ]; then
        # return code 254 indicates that db instance is not found i.e. deleted
        return 0
      else
        echo "### ERROR: deleting ${_db_name} did not finish correctly; Exiting!"
        echo "### Please check AWS Console and re-run the script when ${_db_name} is deleted"
        return ${_ret}
      fi
    done
  fi
}

# RDS aurora db cluster is a special case since it takes significant time for deletion
function check_rds_db_cluster_deletion() {
  _db_cluster_name="${1}"
  aws rds wait db-cluster-deleted --db-cluster-identifier ${_db_cluster_name}
  _deleted=$?
  if [ ${_deleted} -eq 0 ]; then
    echo "RDS aurora db cluster ${_db_cluster_name} deleted successfully"
    return 0
  else
    echo "### ERROR: Failed to delete RDS aurora db cluster ${_db_cluster_name} after maximum 30 minutes (30 seconds, 60 checks)"
    echo "Error code ${_deleted}"
    echo "Waiting additional 10 minutes to delete RDS aurora db cluster"
    for n in {1..5};
    do
      _status=$(aws rds describe-db-clusters --db-cluster-identifier ${_db_cluster_name} --query DBClusters[0].Status --output text)
      _ret=$?
      if [ ${_ret} -eq 0 -o "${_status}" -eq "deleting" ]; then
        # sleep for a minute
        echo "RDS aurora db cluster ${_db_cluster_name} is in ${_status} state; Waiting for 1 more minute to check status"
        sleep 120
      elif [ ${_ret} -eq 254 -o "${_status}" -eq "" ]; then
        # return code 254 indicates that aurora db cluster is not found i.e. deleted
        return 0
      else
        echo "### ERROR: deleting ${_db_cluster_name} did not finish correctly; Exiting!"
        echo "### Please check AWS Console and re-run the script when ${_db_cluster_name} is deleted"
        return ${_ret}
      fi
    done
  fi
}

# Provision to delete AWS RDS resources separately
function delete_aws_rds_associated_resources() {
  _resource_type=${1}
  shift
  _resource_id=${1}
  case ${_resource_type} in
    "--subnet-group")
      aws rds delete-db-subnet-group --db-subnet-group-name ${_resource_id}
    ;;
    "--db-parameter-group")
      aws rds delete-db-parameter-group --db-parameter-group-name ${_resource_id}
    ;;
    "--db-cluster-parameter-group")
      aws rds delete-db-cluster-parameter-group --db-cluster-parameter-group-name ${_resource_id}
    ;;
    "--security-group")
      aws ec2 delete-security-group --group-id ${_resource_id}
    ;;
  esac
}

echo "Exporting Global variables"
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"${CLUSTER_NAME}"}
export TP_CLUSTER_REGION=${TP_CLUSTER_REGION:-"${CLUSTER_REGION}"}
export TP_STORAGE_CLASS_EFS=${TP_STORAGE_CLASS_EFS:-"efs-sc"}
export TP_CROSSPLANE_ENABLED=${TP_CROSSPLANE_ENABLED:-"${CROSSPLANE_ENABLED}"}
export TP_DELETE_CLUSTER=${TP_DELETE_CLUSTER:-"true"}
_role_name="${TP_CLUSTER_NAME}-crossplane-${TP_CLUSTER_REGION}"
export TP_CROSSPLANE_ROLE="${CROSSPLANE_ROLE:-${_role_name}}"
export TP_DELETE_TIBCO_RESOURCE_SET=${DELETE_TIBCO_RESOURCE_SET:-"true"}
export CP_RESOURCE_PREFIX=${CP_RESOURCE_PREFIX}

[ -n "${TP_CLUSTER_NAME}" ] || { printf "Missing value for TP_CLUSTER_NAME\n\n"; usage; }
[ -n "${TP_CLUSTER_REGION}" ] || { printf "Missing value for TP_CLUSTER_REGION\n\n"; usage; } 
[ -n "${TP_CROSSPLANE_ENABLED}" ] || { printf "Missing value for TP_CROSSPLANE_ENABLED\n\n"; usage; }
[ -n "${TP_DELETE_CLUSTER}" ] || { printf "Missing value for TP_DELETE_CLUSTER\n\n"; usage; }

# need to output empty string otherwise will output null
_efs_id=$(kubectl get sc ${TP_STORAGE_CLASS_EFS} -oyaml --ignore-not-found=true | yq eval '.parameters.fileSystemId // ""')
[ "${_efs_id}" != "" ] || { echo "Storage class ${TP_STORAGE_CLASS_EFS} not found, continuing with deletion of other objects"; }

if [ "${TP_DELETE_TIBCO_RESOURCE_SET}" == "true" ]; then
  _namespaces=$(kubectl get tibcoresourceset -A --no-headers -o custom-columns=":metadata.namespace" | sort | uniq | tr '\n' ' ')
  for _namespace in ${_namespaces}; do
    echo "Namespace ${_namespace}: removing TibcoResourceSetCRs..."
    kubectl delete tibcoresourceset -n ${_namespace} --all
  done
  sleep 120
fi

if [ "${TP_CROSSPLANE_ENABLED}" == "true" ]; then
  [ -n "${CP_RESOURCE_PREFIX}" ] || { printf "Missing value for CP_RESOURCE_PREFIX\n\n"; usage; }
  # we are using RDS aurora db cluster using crossplane, the cluster, subnet group, parameter group and security group identifiers can be found using CP_RESOURCE_PREFIX
  _db_cluster_name=$(kubectl get DBCluster.rds.aws.crossplane.io --no-headers -o custom-columns=":metadata.name" 2> /dev/null | grep "${CP_RESOURCE_PREFIX}-aurora-cluster")
  _db_cluster_parameter_group=$(kubectl get DBClusterParameterGroup.rds.aws.crossplane.io --no-headers -o custom-columns=":metadata.name" 2> /dev/null | grep "${CP_RESOURCE_PREFIX}-aurora-cluster")
  _db_subnet_group=$(kubectl get DBSubnetGroup.database.aws.crossplane.io --no-headers -o custom-columns=":metadata.name" 2> /dev/null | grep "${CP_RESOURCE_PREFIX}-aurora-cluster")
  _db_security_group_name=$(kubectl get SecurityGroup.ec2.aws.crossplane.io --no-headers -o custom-columns=":metadata.name" 2> /dev/null | grep "${CP_RESOURCE_PREFIX}-aurora-cluster")
  [ -n "${_db_security_group_name}" ] && _db_security_group_id=$(kubectl get SecurityGroup.ec2.aws.crossplane.io ${_db_security_group_name} -o=jsonpath='{@.status.atProvider.securityGroupID}' 2> /dev/null)
fi

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

# Special waiting for RDS aurora db cluster deletion, since it takes around 20+ minutes
if [ "${TP_CROSSPLANE_ENABLED}" == "true" ] && [ -n "${_db_cluster_name}" ]; then
  echo "Waiting to delete RDS aurora db cluster"
  check_rds_db_cluster_deletion "${_db_cluster_name}"
  _ret=$?
  [ ${_ret} -eq 0 ] || { printf "### ERROR: Failed to delete RDS aurora db cluster ${_db_cluster_name} even after sufficient waiting\n"; printf "Please delete AWS RDS aurora db cluster and related resources manually and then re-run the script again"; exit ${_ret}; }
fi


if [ "${TP_CROSSPLANE_ENABLED}" == "false" ]; then
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

    _efs_sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Resource,Values=${TP_CLUSTER_NAME}-efs --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
    if [ "${_efs_sg_id}" != "" ]; then
      echo "Detected EFS_SG_ID: ${_efs_sg_id} now deleting EFS_SG_ID"
      delete_aws_rds_associated_resources --security-group ${_efs_sg_id}
    fi
    rm -rf mount_targets.json
  fi

  echo "Deleting RDS db instance"
  aws rds delete-db-instance --db-instance-identifier ${TP_CLUSTER_NAME}-db --skip-final-snapshot --no-paginate

  # echo "Deleting Redis"
  # aws elasticache delete-replication-group --replication-group-id ${TP_CLUSTER_NAME}-redis --no-retain-primary-cluster --no-paginate

  echo "Waiting to delete RDS db instance"
  check_rds_db_instance_deletion "${TP_CLUSTER_NAME}-db"
  _ret=$?
  [ ${_ret} -eq 0 ] || { printf "### ERROR: Failed to delete RDS db instance ${TP_CLUSTER_NAME}-db even after sufficient waiting\n"; printf "Please try the deletion manually and re-run the scripts"; exit ${_ret}; }

  # echo "Waiting to delete Redis"
  # aws elasticache wait replication-group-deleted --replication-group-id ${TP_CLUSTER_NAME}-redis
  # _deleted=$?
  # [ ${_deleted} -eq 0 ] || { echo "### ERROR: Failed to delete Redis replication group ${TP_CLUSTER_NAME}-redis after 10 minutes (15 seconds, 40 checks)"; echo "Error code ${_deleted}"; }
  # if [ ${_deleted} -ne 0 ]; then
  #   echo "Waiting additional 5 minutes to delete Redis replication group"
  #   for n in {1..5};
  #   do
  #     _status=$(aws elasticache describe-replication-groups --replication-group-id ${TP_CLUSTER_NAME}-redis --query ReplicationGroups[0].Status --output text)
  #     _ret=$?
  #     if [ ${_ret} -eq 0 -o "${_status}" -eq "deleting" ]; then
  #       # sleep for a minute
  #       echo "Redis replication group ${TP_CLUSTER_NAME}-redis is in ${_status} state; Waiting for 1 more minute to check status"
  #       sleep 60
  #     elif [ ${_ret} -eq 254 -o "${_status}" -eq "" ]; then
  #       # return code 254 indicates that db instance is not found
  #       break
  #     else
  #       echo "### ERROR: deleting ${TP_CLUSTER_NAME}-redis operation did not finish correctly; Exiting!"
  #       echo "### ### Please check AWS Console and re-run the script when ${TP_CLUSTER_NAME}-redis is deleted"
  #       exit ${_ret}
  #     fi
  #   done
  # fi

  _db_subnet_group="${TP_CLUSTER_NAME}-subnet-group"

  # echo "Deleting Cache subnet group"
  # aws elasticache delete-cache-subnet-group --cache-subnet-group-name ${TP_CLUSTER_NAME}-cache-subnet-group --no-paginate

  _db_security_group_id=$(aws ec2 describe-security-groups --filters Name=tag:Resource,Values=${TP_CLUSTER_NAME}-rds --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')

  # echo "Deleting Redis security group"
  # _redis_sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Resource,Values=${TP_CLUSTER_NAME}-redis --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}" | yq eval '.[].ID  // ""')
  # if [ "${_redis_sg_id}" != "" ]; then
  #   echo "Detected Redis security group id: ${_redis_sg_id}; Now deleting"
  #   aws ec2 delete-security-group --group-id ${_redis_sg_id}
  # fi
fi

# Even if RDS aurora db cluster/instance is removed, the associated resources may linger; deleting those
[ -n "${_db_parameter_group}" ] && { echo "Deleting RDS db instance parameter group"; delete_aws_rds_associated_resources --db-parameter-group "${_db_parameter_group}"; }
[ -n "${_db_cluster_parameter_group}" ] && { echo "Deleting RDS db cluster parameter group"; delete_aws_rds_associated_resources --db-cluster-parameter-group "${_db_cluster_parameter_group}"; }
[ -n "${_db_subnet_group}" ] && { echo "Deleting RDS db subnet group"; delete_aws_rds_associated_resources --subnet-group "${_db_subnet_group}"; }
[ -n "${_db_security_group_id}" ] && { echo "Deleting RDS db security group"; delete_aws_rds_associated_resources --security-group "${_db_security_group_id}"; }


if [ "${TP_CROSSPLANE_ENABLED}" == "true" ]; then
  echo "Detaching role policy to IAM role ${TP_CROSSPLANE_ROLE}"
  aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --role-name ${TP_CROSSPLANE_ROLE}
  _ret=$?
  [ ${_ret} -eq 0 ] || { echo "### ERROR: failed to detach policy to IAM role for crossplane. Please re-run the script"; exit ${_ret}; }

  echo "Deleting crossplane role"
  aws iam delete-role --role-name ${TP_CROSSPLANE_ROLE}
  _ret=$?
  [ ${_ret} -eq 0 ] || { echo "### ERROR: failed to delete IAM role for crossplane. Please re-run the script"; exit ${_ret}; }
fi

if [ "${TP_DELETE_CLUSTER}" == "true" ]; then
  echo "Deleting cluster"
  eksctl delete cluster --name=${TP_CLUSTER_NAME} --disable-nodegroup-eviction --force
else 
  echo "Not deleting cluster"
fi
