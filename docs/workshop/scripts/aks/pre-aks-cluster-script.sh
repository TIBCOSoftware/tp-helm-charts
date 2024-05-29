#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

echo "Export Global variables"
export DP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export DP_AZURE_REGION=${DP_AZURE_REGION:-"westus2"}
export DP_RESOURCE_GROUP=${DP_RESOURCE_GROUP:-"dp-resource-group"}
export DP_CLUSTER_NAME=${DP_CLUSTER_NAME:-"dp-aks-cluster"}
export DP_USER_ASSIGNED_IDENTITY_NAME="${DP_CLUSTER_NAME}-identity"
export DP_DNS_RESOURCE_GROUP=${DP_DNS_RESOURCE_GROUP:-"cic-dns"}
export DP_VNET_NAME=${DP_VNET_NAME:-"${DP_CLUSTER_NAME}-vnet"}
export DP_VNET_CIDR=${DP_VNET_CIDR:-"10.4.0.0/16"}
export DP_AKS_SUBNET_NAME=${DP_AKS_SUBNET_NAME:-"${DP_CLUSTER_NAME}-aks-subnet"}
export DP_AKS_SUBNET_CIDR=${DP_AKS_SUBNET_CIDR:-"10.4.0.0/20"}
export DP_APPLICATION_GW_SUBNET_NAME=${DP_APPLICATION_GW_SUBNET_NAME:-"${DP_CLUSTER_NAME}-application-gw-subnet"}
export DP_APPLICATION_GW_SUBNET_CIDR=${DP_APPLICATION_GW_SUBNET_CIDR:-"10.4.17.0/24"}
export DP_PUBLIC_IP_NAME=${DP_PUBLIC_IP_NAME:-"${DP_CLUSTER_NAME}-public-ip"}
export DP_NAT_GW_NAME=${DP_NAT_GW_NAME:-"${DP_CLUSTER_NAME}-nat-gw"}
export DP_NAT_GW_SUBNET_NAME=${DP_NAT_GW_SUBNET_NAME:-"${DP_CLUSTER_NAME}-nat-gw-subnet"}
export DP_NAT_GW_SUBNET_CIDR=${DP_NAT_GW_SUBNET_CIDR:-"10.4.18.0/27"}
export DP_APISERVER_SUBNET_NAME=${DP_APISERVER_SUBNET_NAME:-"${DP_CLUSTER_NAME}-api-server-subnet"}
export DP_APISERVER_SUBNET_CIDR=${DP_APISERVER_SUBNET_CIDR:-"10.4.19.0/28"}

# create resource group
az group create --location "${DP_AZURE_REGION}" --name "${DP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "resource_group"

# create dns resource group
az group create --location "${DP_AZURE_REGION}" --name "${DP_DNS_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "resource_group"

# create user-assigned identity
az identity create --name "${DP_USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${DP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "identity"
export DP_USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --resource-group "${DP_RESOURCE_GROUP}" --name "${DP_USER_ASSIGNED_IDENTITY_NAME}" --query 'principalId' -otsv)"

# add contributor privileged role
# required to create resources
az role assignment create \
  --role "Contributor" \
  --assignee-object-id "${DP_USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope /subscriptions/${DP_SUBSCRIPTION_ID} \
  --description "Allow Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# add network contributor permission
# required to join app gateway subnet
az role assignment create \
  --role "Network Contributor" \
  --assignee-object-id "${DP_USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope "/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}" \
  --description "Allow Network Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# add dns zone contributor permission
# required to create new record sets in dns zone
az role assignment create \
  --role "DNS Zone Contributor" \
  --assignee-object-id "${DP_USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope "/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_DNS_RESOURCE_GROUP}" \
  --description "Allow Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# create public ip
az network public-ip create -g "${DP_RESOURCE_GROUP}" -n ${DP_PUBLIC_IP_NAME} --sku "Standard" --allocation-method "Static"
_ret=$?
verify_error "${_ret}" "public_ip"
export DP_PUBLIC_IP_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/${DP_PUBLIC_IP_NAME}"

# create nat gateway
az network nat gateway create --resource-group "${DP_RESOURCE_GROUP}" --name "${DP_NAT_GW_NAME}" --public-ip-addresses "${DP_PUBLIC_IP_ID}"
_ret=$?
verify_error "${_ret}" "nat_gateway"
export DP_NAT_GW_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/natGateways/${DP_NAT_GW_NAME}"

# create virtual network
az network vnet create -g "${DP_RESOURCE_GROUP}" -n "${DP_VNET_NAME}" --address-prefix "${DP_VNET_CIDR}"
_ret=$?
verify_error "${_ret}" "VNet"

# create application gateway subnets
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${DP_VNET_NAME}" -n "${DP_APPLICATION_GW_SUBNET_NAME}" --address-prefixes "${DP_APPLICATION_GW_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "application_gateway_subnet"

# create aks subnet
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${DP_VNET_NAME}" -n "${DP_AKS_SUBNET_NAME}" --address-prefixes "${DP_AKS_SUBNET_CIDR}" --nat-gateway "${DP_NAT_GW_ID}"
_ret=$?
verify_error "${_ret}" "aks_subnet"

# create aks subnet
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${DP_VNET_NAME}" -n "${DP_APISERVER_SUBNET_NAME}" --address-prefixes "${DP_APISERVER_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "api_server_subnet"

# create nat gateway subnet
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${DP_VNET_NAME}" -n "${DP_NAT_GW_SUBNET_NAME}" --address-prefixes "${DP_NAT_GW_SUBNET_CIDR}" --nat-gateway "${DP_NAT_GW_ID}"
_ret=$?
verify_error "${_ret}" "nat_gateway_subnet"
export DP_NAT_GW_VNET_SUBNET_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${DP_VNET_NAME}/subnets/${DP_NAT_GW_SUBNET_NAME}"

echo "Finished creating pre-requisites for AKS cluster"