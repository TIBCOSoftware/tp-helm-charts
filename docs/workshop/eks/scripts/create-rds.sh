#!/bin/bash

set +x

echo "Export Global variables"
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"${CLUSTER_NAME}"}
export TP_RDS_AVAILABILITY=${TP_RDS_AVAILABILITY:-"public"}
export TP_RDS_PORT=${TP_RDS_PORT:-"5432"}
export TP_RDS_INSTANCE_CLASS=${TP_RDS_INSTANCE_CLASS:-"db.t3.medium"}
export TP_RDS_USERNAME=${TP_RDS_USERNAME:-"TP_rdsadmin"}
export TP_RDS_MASTER_PASSWORD=${TP_RDS_MASTER_PASSWORD:-"TP_DBAdminPassword"}
export TP_RDS_ENGINE_VERSION=${TP_RDS_ENGINE_VERSION:-"14.11"}
export TP_WAIT_FOR_RESOURCE_AVAILABLE"="${TP_WAIT_FOR_RESOURCE_AVAILABLE:-"false"}

[ "${TP_CLUSTER_NAME}" != "" ] || { echo "Cluster name is not specified"; exit 1; }

_ret=''
_created=''
_status=''

echo "Get VPC details"
_vpc_id=$(aws eks describe-cluster --name ${TP_CLUSTER_NAME} --query "cluster.resourcesVpcConfig.vpcId" --output text)
_cidr_block=$(aws ec2 describe-vpcs --vpc-ids ${_vpc_id} --query "Vpcs[].CidrBlock" --output text)
_flag_publicly_accessible=''

_tag1=tag:alpha.eksctl.io/cluster-name
if [ "${TP_RDS_AVAILABILITY}" == "public" ]; then
  _tag2=tag:kubernetes.io/role/elb
  _flag_publicly_accessible=" --publicly-accessible"
elif [ "${TP_RDS_AVAILABILITY}" == "private" ]; then
  _tag2=tag:kubernetes.io/role/internal-elb
  _flag_publicly_accessible=" --no-publicly-accessible"
else
  echo "### ERROR: unsupported value of TP_RDS_AVAILABILITY: ${TP_RDS_AVAILABILITY}. Allowed values are public, private"
  exit 1
fi

echo "Get subnet details"
_subnet_json=$(aws ec2 describe-subnets --filters "Name=${_tag1},Values=${TP_CLUSTER_NAME}" "Name=${_tag2},Values=1" --query 'Subnets[*].SubnetId')

echo "Create RDS security group"
_rds_group_name="rds-security-group"
_rds_group_description="RDS access from EKS worker nodes"
_rds_group_id=$(aws ec2 create-security-group --group-name ${_rds_group_name} --description "${_rds_group_description}" --vpc-id ${_vpc_id} | jq --raw-output '.GroupId')
aws ec2 create-tags --resources ${_rds_group_id} --tags Key=Cluster,Value=${TP_CLUSTER_NAME} Key=Resource,Value=${TP_CLUSTER_NAME}-rds
aws ec2 authorize-security-group-ingress --group-id ${_rds_group_id} --protocol tcp --port ${TP_RDS_PORT} --cidr ${_cidr_block}

echo "Create database subnet group"
aws rds create-db-subnet-group \
    --db-subnet-group-name ${TP_CLUSTER_NAME}-subnet-group \
    --db-subnet-group-description "CP database subnet group" \
    --subnet-ids "${_subnet_json}"

echo "Create database instance"
aws rds create-db-instance \
  --db-name postgres \
  --db-instance-identifier ${TP_CLUSTER_NAME}-db \
  --db-instance-class ${TP_RDS_INSTANCE_CLASS} \
  --engine postgres \
  --port ${TP_RDS_PORT} \
  --master-username ${TP_RDS_USERNAME} \
  --master-user-password ${TP_RDS_MASTER_PASSWORD} \
  --db-subnet-group-name ${TP_CLUSTER_NAME}-subnet-group${_flag_publicly_accessible} \
  --allocated-storage 20 \
  --no-multi-az \
  --engine-version ${TP_RDS_ENGINE_VERSION} \
  --vpc-security-group-ids ${_rds_group_id} \
  --no-paginate

if [ "${TP_WAIT_FOR_RESOURCE_AVAILABLE}" == "true" ]; then
  echo "Waiting for RDS db instance to be available"
  aws rds wait db-instance-available --db-instance-identifier ${TP_CLUSTER_NAME}-db
  _created=$?
  [ ${_created} -eq 0 ] || { echo "### WARNING: DB instance availability check failed after maximum 30 minutes (30 seconds, 60 checks)"; echo "Response code ${_created}"; }
  if [ ${_created} -ne 0 ]; then
    echo "Waiting additional 5 minutes for RDS db instance to be available"
    for n in {1..5};
    do
      _status=$(aws rds describe-db-instances --db-instance-identifier ${TP_CLUSTER_NAME}-db --query DBInstances[0].DBInstanceStatus --output text)
      _ret=$?
      if [ ${_ret} -eq 0 -a "${_status}" -ne "available" ]; then
        # sleep for a minute
        echo "RDS db instance ${TP_CLUSTER_NAME}-db is in ${_status} state; Waiting for 1 more minute to check status"
        sleep 60
      elif [ ${_ret} -eq 0 -a "${_status}" -eq "available" ]; then
        echo "RDS db instance ${TP_CLUSTER_NAME}-db is in available state"
        break
      else
        echo "### ERROR: creating ${TP_CLUSTER_NAME}-db did not finish correctly; Exiting!"
        echo "### Please check AWS Console"
        exit ${_ret}
      fi
    done
  fi
fi