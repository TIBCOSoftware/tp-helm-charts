#!/bin/bash

set +x

echo "Export Global variables"
export CP_CLUSTER_NAME=${CP_CLUSTER_NAME:-"cp-cluster-infra"}
export CP_RDS_AVAILABILITY=${CP_RDS_AVAILABILITY:-"public"}
export CP_RDS_PORT=${CP_RDS_PORT:-"5432"}
export CP_RDS_INSTANCE_CLASS=${CP_RDS_INSTANCE_CLASS:-"db.t3.medium"}
export CP_RDS_USERNAME=${CP_RDS_USERNAME:-"cp_rdsadmin"}
export CP_RDS_MASTER_PASSWORD=${CP_RDS_MASTER_PASSWORD:-"cp_DBAdminPassword"}
export CP_RDS_ENGINE_VERSION=${CP_RDS_ENGINE_VERSION:-"14.11"}
export WAIT_FOR_RESOURCE_AVAILABLE"="${WAIT_FOR_RESOURCE_AVAILABLE:-"false"}

_ret=''
_created=''
_status=''

echo "Get VPC details"
_vpc_id=$(aws eks describe-cluster --name ${CP_CLUSTER_NAME} --query "cluster.resourcesVpcConfig.vpcId" --output text)
_cidr_block=$(aws ec2 describe-vpcs --vpc-ids ${_vpc_id} --query "Vpcs[].CidrBlock" --output text)
_flag_publicly_accessible=''

_tag1=tag:alpha.eksctl.io/cluster-name
if [ "${CP_RDS_AVAILABILITY}" == "public" ]; then
  _tag2=tag:kubernetes.io/role/elb
  _flag_publicly_accessible=" --publicly-accessible"
elif [ "${CP_RDS_AVAILABILITY}" == "private" ]; then
  _tag2=tag:kubernetes.io/role/internal-elb
  _flag_publicly_accessible=" --no-publicly-accessible"
else
  echo "### ERROR: unsupported value of CP_RDS_AVAILABILITY: ${CP_RDS_AVAILABILITY}. Allowed values are public, private"
  exit 1
fi

echo "Get subnet details"
_subnet_json=$(aws ec2 describe-subnets --filters "Name=${_tag1},Values=${CP_CLUSTER_NAME}" "Name=${_tag2},Values=1" --query 'Subnets[*].SubnetId')

echo "Create RDS security group"
_rds_group_name="rds-security-group"
_rds_group_description="RDS access from EKS worker nodes"
_rds_group_id=$(aws ec2 create-security-group --group-name ${_rds_group_name} --description "${_rds_group_description}" --vpc-id ${_vpc_id} | jq --raw-output '.GroupId')
aws ec2 create-tags --resources ${_rds_group_id} --tags Key=Cluster,Value=${CP_CLUSTER_NAME} Key=Resource,Value=${CP_CLUSTER_NAME}-rds
aws ec2 authorize-security-group-ingress --group-id ${_rds_group_id} --protocol tcp --port ${CP_RDS_PORT} --cidr ${_cidr_block}

echo "Create database subnet group"
aws rds create-db-subnet-group \
    --db-subnet-group-name ${CP_CLUSTER_NAME}-subnet-group \
    --db-subnet-group-description "CP database subnet group" \
    --subnet-ids "${_subnet_json}"

echo "Create database instance"
aws rds create-db-instance \
  --db-name postgres \
  --db-instance-identifier ${CP_CLUSTER_NAME}-db \
  --db-instance-class ${CP_RDS_INSTANCE_CLASS} \
  --engine postgres \
  --port ${CP_RDS_PORT} \
  --master-username ${CP_RDS_USERNAME} \
  --master-user-password ${CP_RDS_MASTER_PASSWORD} \
  --db-subnet-group-name ${CP_CLUSTER_NAME}-subnet-group${_flag_publicly_accessible} \
  --allocated-storage 20 \
  --no-multi-az \
  --engine-version ${CP_RDS_ENGINE_VERSION} \
  --vpc-security-group-ids ${_rds_group_id} \
  --no-paginate

if [ "${WAIT_FOR_RESOURCE_AVAILABLE}" == "true" ]; then
  echo "Waiting for RDS db instance to be available"
  aws rds wait db-instance-available --db-instance-identifier ${CP_CLUSTER_NAME}-db
  _created=$?
  [ ${_created} -eq 0 ] || { echo "### WARNING: DB instance availability check failed after maximum 30 minutes (30 seconds, 60 checks)"; echo "Response code ${_created}"; }
  if [ ${_created} -ne 0 ]; then
    echo "Waiting additional 5 minutes for RDS db instance to be available"
    for n in {1..5};
    do
      _status=$(aws rds describe-db-instances --db-instance-identifier ${CP_CLUSTER_NAME}-db --query DBInstances[0].DBInstanceStatus --output text)
      _ret=$?
      if [ ${_ret} -eq 0 -a "${_status}" -ne "available" ]; then
        # sleep for a minute
        echo "RDS db instance ${CP_CLUSTER_NAME}-db is in ${_status} state; Waiting for 1 more minute to check status"
        sleep 60
      elif [ ${_ret} -eq 0 -a "${_status}" -eq "available" ]; then
        echo "RDS db instance ${CP_CLUSTER_NAME}-db is in available state"
        break
      else
        echo "### ERROR: creating ${CP_CLUSTER_NAME}-db did not finish correctly; Exiting!"
        echo "### Please check AWS Console"
        exit ${_ret}
      fi
    done
  fi
fi