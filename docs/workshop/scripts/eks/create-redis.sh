#!/bin/bash

set +x

echo "Export Global variables"
export CP_CLUSTER_NAME=${CP_CLUSTER_NAME:-"cp-cluster"}
export CP_REDIS_PORT=${CP_REDIS_PORT:-"6379"}
export CP_REDIS_CACHE_NODE_TYPE=${CP_REDIS_CACHE_NODE_TYPE:-"cache.t4g.medium"}
export WAIT_FOR_RESOURCE_AVAILABLE=${WAIT_FOR_RESOURCE_AVAILABLE:-"false"}

_ret=''
_created=''
_status=''

echo "Get VPC details"
_vpc_id=$(aws eks describe-cluster --name ${CP_CLUSTER_NAME} --query "cluster.resourcesVpcConfig.vpcId" --output text)
_cidr_block=$(aws ec2 describe-vpcs --vpc-ids ${_vpc_id} --query "Vpcs[].CidrBlock" --output text)

_tag1=tag:alpha.eksctl.io/cluster-name
_tag2=tag:kubernetes.io/role/internal-elb

echo "Get subnet details"
_subnet_json=$(aws ec2 describe-subnets --filters "Name=${_tag1},Values=${CP_CLUSTER_NAME}" "Name=${_tag2},Values=1" --query 'Subnets[*].SubnetId')

echo "Create Redis security group"
_redis_group_name="redis-security-group"
_redis_group_description="Redis access from EKS worker nodes"
_redis_group_id=$(aws ec2 create-security-group --group-name ${_redis_group_name} --description "${_redis_group_description}" --vpc-id ${_vpc_id} | jq --raw-output '.GroupId')
aws ec2 create-tags --resources ${_redis_group_id} --tags Key=Cluster,Value=${CP_CLUSTER_NAME} Key=Resource,Value=${CP_CLUSTER_NAME}-redis
aws ec2 authorize-security-group-ingress --group-id ${_redis_group_id} --protocol tcp --port ${CP_REDIS_PORT} --cidr ${_cidr_block}

echo "Create cache subnet group"
aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name ${CP_CLUSTER_NAME}-cache-subnet-group \
    --cache-subnet-group-description "CP cache subnet group" \
    --subnet-ids "${_subnet_json}"

echo "Create Redis replication group"
aws elasticache create-replication-group \
    --replication-group-id ${CP_CLUSTER_NAME}-redis \
    --replication-group-description "CP Redis replica group" \
    --engine "redis" \
    --cache-node-type "${CP_REDIS_CACHE_NODE_TYPE}" \
    --cache-parameter-group-name "default.redis6.x" \
    --cache-subnet-group-name ${CP_CLUSTER_NAME}-cache-subnet-group \
    --engine-version "6.x" \
    --port "${CP_REDIS_PORT}" \
    --replicas-per-node-group 0 \
    --num-node-groups 1 \
    --security-group-ids ${_redis_group_id} \
    --no-transit-encryption-enabled \
    --no-at-rest-encryption-enabled \
    --no-paginate

if [ "${WAIT_FOR_RESOURCE_AVAILABLE}" == "true" ]; then
  echo "Waiting for Redis replication group to be available"
  aws elasticache wait replication-group-available --replication-group-id ${CP_CLUSTER_NAME}-redis
  _created=$?
  [ ${_created} -eq 0 ] || { echo "### WARNING: Redis replication group availability check failed after maximum 10 minutes (15 seconds, 40 checks)"; echo "Response code ${_created}"; }
  if [ ${_created} -ne 0 ]; then
    echo "Waiting additional 5 minutes for Redis replication group to be available"
    for n in {1..5};
    do
      _status=$(aws elasticache describe-replication-groups --replication-group-id ${CP_CLUSTER_NAME}-redis --query ReplicationGroups[0].Status --output text)
      _ret=$?
      if [ ${_ret} -eq 0 -a "${_status}" -ne "available" ]; then
        # sleep for a minute
        echo "Redis replication group ${CP_CLUSTER_NAME}-redis is in ${_status} state; Waiting for 1 more minute to check status"
        sleep 60
      elif [ ${_ret} -eq 0 -a "${_status}" -eq "available" ]; then
        echo "Redis replication group ${CP_CLUSTER_NAME}-redis is in available state"
        break
      else
        echo "### ERROR: creating ${CP_CLUSTER_NAME}-redis did not finish correctly; Exiting!"
        echo "### Please check AWS Console"
        exit ${_ret}
      fi
    done
  fi
fi