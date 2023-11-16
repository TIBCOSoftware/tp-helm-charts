#!/bin/bash

echo "get basic info"
VPC_ID=$(aws eks describe-cluster --name ${DP_CLUSTER_NAME} --query "cluster.resourcesVpcConfig.vpcId" --output text)
CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --query "Vpcs[].CidrBlock" --output text)

echo "setup security group for EFS"
MOUNT_TARGET_GROUP_NAME="eks-efs-group"
MOUNT_TARGET_GROUP_DESC="NFS access to EFS from EKS worker nodes"
MOUNT_TARGET_GROUP_ID=$(aws ec2 create-security-group --group-name $MOUNT_TARGET_GROUP_NAME --description "$MOUNT_TARGET_GROUP_DESC" --vpc-id $VPC_ID | jq --raw-output '.GroupId')
aws ec2 create-tags --resources ${MOUNT_TARGET_GROUP_ID} --tags Key=Cluster,Value=${DP_CLUSTER_NAME}
aws ec2 authorize-security-group-ingress --group-id $MOUNT_TARGET_GROUP_ID --protocol tcp --port 2049 --cidr $CIDR_BLOCK

echo "create EFS"
FILE_SYSTEM_ID=$(aws efs create-file-system | jq --raw-output '.FileSystemId')

aws efs describe-file-systems --file-system-id $FILE_SYSTEM_ID
aws efs create-tags --file-system-id ${FILE_SYSTEM_ID} --tags Key=Cluster,Value=${DP_CLUSTER_NAME}

echo "creating mount target"
TAG1=tag:alpha.eksctl.io/cluster-name
TAG2=tag:kubernetes.io/role/elb
subnets=($(aws ec2 describe-subnets --filters "Name=$TAG1,Values=${DP_CLUSTER_NAME}" "Name=$TAG2,Values=1" | jq --raw-output '.Subnets[].SubnetId'))
for subnet in ${subnets[@]}
do
  echo "creating mount target in " $subnet
  aws efs create-mount-target --file-system-id $FILE_SYSTEM_ID --subnet-id $subnet --security-groups $MOUNT_TARGET_GROUP_ID
done

aws efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID | jq --raw-output '.MountTargets[].LifeCycleState'

echo "use the following EFS id"
echo ${FILE_SYSTEM_ID}
