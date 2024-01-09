#!/bin/bash

set +x

if [ -n "${1}" ]; then
  _cluster_name="${1}"
  echo "Using cluster: ${_cluster_name}"
else
  echo "### ERROR: Expected 1 argument with cluster name"
  exit 1
fi

echo "Get basic info"
_vpc_id=$(aws eks describe-cluster --name ${_cluster_name} --query "cluster.resourcesVpcConfig.vpcId" --output text)
_cidr_block=$(aws ec2 describe-vpcs --vpc-ids ${_vpc_id} --query "Vpcs[].CidrBlock" --output text)

echo "Setup security group for EFS"
_mount_target_group_name="eks-efs-group"
_mount_target_group_description="NFS access to EFS from EKS worker nodes"
_mount_target_group_id=$(aws ec2 create-security-group --group-name ${_mount_target_group_name} --description "${_mount_target_group_description}" --vpc-id ${_vpc_id} | jq --raw-output '.GroupId')
aws ec2 create-tags --resources ${_mount_target_group_id} --tags Key=Cluster,Value=${_cluster_name} Key=Resource,Value=${_cluster_name}-efs
aws ec2 authorize-security-group-ingress --group-id ${_mount_target_group_id} --protocol tcp --port 2049 --cidr ${_cidr_block}

echo "Create EFS"
_file_system_id=$(aws efs create-file-system | jq --raw-output '.FileSystemId')

aws efs describe-file-systems --file-system-id ${_file_system_id}
aws efs create-tags --file-system-id ${_file_system_id} --tags Key=Cluster,Value=${_cluster_name}

echo "Create mount target"
_tag1=tag:alpha.eksctl.io/cluster-name
_tag2=tag:kubernetes.io/role/elb
_subnet_array=($(aws ec2 describe-subnets --filters "Name=${_tag1},Values=${_cluster_name}" "Name=${_tag2},Values=1" | jq --raw-output '.Subnets[].SubnetId'))
for _subnet in ${_subnet_array[@]}
do
  echo "Creating mount target in " ${_subnet}
  aws efs create-mount-target --file-system-id ${_file_system_id} --subnet-id ${_subnet} --security-groups ${_mount_target_group_id}
done

aws efs describe-mount-targets --file-system-id ${_file_system_id} | jq --raw-output '.MountTargets[].LifeCycleState'

echo "Use the following EFS id"
echo ${_file_system_id}