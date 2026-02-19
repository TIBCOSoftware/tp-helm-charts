#!/bin/bash

set +x

echo "Export Global variables"
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"${CLUSTER_NAME}"}
export TP_CLUSTER_REGION=${TP_CLUSTER_REGION:-"${CLUSTER_REGION}"}
export TP_VPC_CIDR=${TP_VPC_CIDR:-"${VPC_CIDR}"}

[ "${TP_CLUSTER_NAME}" != "" ] || { echo "Cluster name is not specified"; exit 1; }
[ "${TP_CLUSTER_REGION}" != "" ] || { echo "Cluster region is not specified"; exit 1; }
[ "${TP_VPC_CIDR}" != "" ] || { echo "VPC CIDR is not specified"; exit 1; }

echo "Get Account details"
# assumption is you are using IAM role from the same AWS account
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Get VPC details"
VPC_ID=$(aws eks describe-cluster --name ${TP_CLUSTER_NAME} --query "cluster.resourcesVpcConfig.vpcId" --output text)
VPC_ID=${VPC_ID}
echo "VPC Id: ${VPC_ID}"

_tag1=tag:alpha.eksctl.io/cluster-name
_tag2=''

# set public subnet tag
_tag2=tag:kubernetes.io/role/elb
echo "Get public subnet details"
_public_subnets=$(aws ec2 describe-subnets --filters "Name=${_tag1},Values=${TP_CLUSTER_NAME}" "Name=${_tag2},Values=1" --query 'Subnets[*].SubnetId' --output json)
PUBLIC_SUBNET_ID_1=$(echo "${_public_subnets}" | jq '.[0]' | tr -d '"')
PUBLIC_SUBNET_ID_2=$(echo "${_public_subnets}" | jq '.[1]' | tr -d '"')
PUBLIC_SUBNET_ID_3=$(echo "${_public_subnets}" | jq '.[2]' | tr -d '"')
echo "Public Subnet Ids: ${PUBLIC_SUBNET_ID_1}, ${PUBLIC_SUBNET_ID_2}, ${PUBLIC_SUBNET_ID_3}"

# set private subnet tag
_tag2=tag:kubernetes.io/role/internal-elb
echo "Get private subnet details"
_private_subnets=$(aws ec2 describe-subnets --filters "Name=${_tag1},Values=${TP_CLUSTER_NAME}" "Name=${_tag2},Values=1" --query 'Subnets[*].SubnetId' --output json)
PRIVATE_SUBNET_ID_1=$(echo "${_private_subnets}" | jq '.[0]' | tr -d '"')
PRIVATE_SUBNET_ID_2=$(echo "${_private_subnets}" | jq '.[1]' | tr -d '"')
PRIVATE_SUBNET_ID_3=$(echo "${_private_subnets}" | jq '.[2]' | tr -d '"')
echo "Private Subnet Ids: ${PRIVATE_SUBNET_ID_1}, ${PRIVATE_SUBNET_ID_2}, ${PRIVATE_SUBNET_ID_3}"

# Get route table details for public subnets (handles both shared and separate route tables)
echo "Get public route table details"
PUBLIC_ROUTE_TABLE_ID_1=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PUBLIC_SUBNET_ID_1}" --query 'RouteTables[0].RouteTableId' --output text)
PUBLIC_ROUTE_TABLE_ID_2=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PUBLIC_SUBNET_ID_2}" --query 'RouteTables[0].RouteTableId' --output text)
PUBLIC_ROUTE_TABLE_ID_3=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PUBLIC_SUBNET_ID_3}" --query 'RouteTables[0].RouteTableId' --output text)
echo "Public Route Table Ids: ${PUBLIC_ROUTE_TABLE_ID_1}, ${PUBLIC_ROUTE_TABLE_ID_2}, ${PUBLIC_ROUTE_TABLE_ID_3}"

# Get unique public route table IDs
PUBLIC_ROUTE_TABLES_UNIQUE=($(printf "%s\n" "${PUBLIC_ROUTE_TABLE_ID_1}" "${PUBLIC_ROUTE_TABLE_ID_2}" "${PUBLIC_ROUTE_TABLE_ID_3}" | sort -u | grep -v '^$'))
echo "Unique Public Route Table Ids: ${PUBLIC_ROUTE_TABLES_UNIQUE[@]}"

# Get route table details for private subnets (each has its own route table)
echo "Get private route table details"
PRIVATE_ROUTE_TABLE_ID_1=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PRIVATE_SUBNET_ID_1}" --query 'RouteTables[0].RouteTableId' --output text)
PRIVATE_ROUTE_TABLE_ID_2=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PRIVATE_SUBNET_ID_2}" --query 'RouteTables[0].RouteTableId' --output text)
PRIVATE_ROUTE_TABLE_ID_3=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PRIVATE_SUBNET_ID_3}" --query 'RouteTables[0].RouteTableId' --output text)
echo "Private Route Table Ids: ${PRIVATE_ROUTE_TABLE_ID_1}, ${PRIVATE_ROUTE_TABLE_ID_2}, ${PRIVATE_ROUTE_TABLE_ID_3}"

## OIDC details
OIDC_ISSUER_URL=$(aws eks describe-cluster --name ${TP_CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text)
OIDC_ISSUER_HOSTPATH=$(echo "${OIDC_ISSUER_URL}" | cut -d/ -f3-)
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ISSUER_HOSTPATH}"

cat << EOF > ./tibco-platform-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tibco-platform-infra
  namespace: kube-system
  labels:
    app.kubernetes.io/name: tibco-platform
    app.kubernetes.io/component: env
    app.kubernetes.io/part-of: tibco-platform
data:
  ### Cloud data
  CLOUD_ACCOUNT_ID: "${ACCOUNT_ID}"
  CLOUD_REGION: "${TP_CLUSTER_REGION}"
  ### OIDC data
  OIDC_ISSUER_URL: "${OIDC_ISSUER_URL}"
  OIDC_ISSUER_HOSTPATH: "${OIDC_ISSUER_HOSTPATH}"
  OIDC_PROVIDER_ARN: "${OIDC_PROVIDER_ARN}"
  ### Kubernetes data
  KUBERNETES_CLUSTER_NAME: "${TP_CLUSTER_NAME}"
  ### Networking
  NET_VPC_IDENTIFIER: "${VPC_ID}"
  NET_NODE_CIDR: "${TP_VPC_CIDR}"
  NET_PUBLIC_SUBNETS: |
    - "${PUBLIC_SUBNET_ID_1}"
    - "${PUBLIC_SUBNET_ID_2}"
    - "${PUBLIC_SUBNET_ID_3}"
  NET_PRIVATE_SUBNETS: |
    - "${PRIVATE_SUBNET_ID_1}"
    - "${PRIVATE_SUBNET_ID_2}"
    - "${PRIVATE_SUBNET_ID_3}"
  NET_PUBLIC_ROUTE_TABLES: |
$(printf '    - "%s"\n' "${PUBLIC_ROUTE_TABLES_UNIQUE[@]}")
  NET_PRIVATE_ROUTE_TABLES: |
    - "${PRIVATE_ROUTE_TABLE_ID_1}"
    - "${PRIVATE_ROUTE_TABLE_ID_2}"
    - "${PRIVATE_ROUTE_TABLE_ID_3}"
EOF
echo -e "Platform ConfigMap:\n$(cat ./tibco-platform-cm.yaml)"

kubectl apply -f ./tibco-platform-cm.yaml
[ $? -eq 0 ] || { >&2 echo "### ERROR: Unable to apply Platform ConfigMap to Kubernetes cluster ${TP_CLUSTER_NAME}; Exiting!"; exit 1; }
rm -f ./tibco-platform-cm.yaml # deliberately removing this after error check -- we want to keep it around for troubleshooting, if error
