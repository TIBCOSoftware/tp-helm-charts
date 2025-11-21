#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

echo "Export Global variables"
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TP_AZURE_REGION=${TP_AZURE_REGION:-"eastus"}
export TP_RESOURCE_GROUP=${TP_RESOURCE_GROUP:-"dp-resource-group"}
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"dp-aks-cluster"}
export TP_USER_ASSIGNED_IDENTITY_NAME="${TP_CLUSTER_NAME}-identity"
export TP_DNS_RESOURCE_GROUP=${TP_DNS_RESOURCE_GROUP:-"cic-dns"}
export TP_VNET_NAME=${TP_VNET_NAME:-"${TP_CLUSTER_NAME}-vnet"}
export TP_VNET_CIDR=${TP_VNET_CIDR:-"10.4.0.0/16"}
export TP_AKS_SUBNET_NAME=${TP_AKS_SUBNET_NAME:-"${TP_CLUSTER_NAME}-aks-subnet"}
export TP_AKS_SUBNET_CIDR=${TP_AKS_SUBNET_CIDR:-"10.4.0.0/20"}
export TP_ADDON_ENABLE_APPLICATION_GW=${TP_ADDON_ENABLE_APPLICATION_GW:-"false"}
export TP_APPLICATION_GW_SUBNET_NAME=${TP_APPLICATION_GW_SUBNET_NAME:-"${TP_CLUSTER_NAME}-application-gw-subnet"}
export TP_APPLICATION_GW_SUBNET_CIDR=${TP_APPLICATION_GW_SUBNET_CIDR:-"10.4.17.0/24"}
export TP_PUBLIC_IP_NAME=${TP_PUBLIC_IP_NAME:-"${TP_CLUSTER_NAME}-public-ip"}
export TP_NAT_GW_NAME=${TP_NAT_GW_NAME:-"${TP_CLUSTER_NAME}-nat-gw"}
export TP_NAT_GW_SUBNET_NAME=${TP_NAT_GW_SUBNET_NAME:-"${TP_CLUSTER_NAME}-nat-gw-subnet"}
export TP_NAT_GW_SUBNET_CIDR=${TP_NAT_GW_SUBNET_CIDR:-"10.4.18.0/27"}
export TP_APISERVER_SUBNET_NAME=${TP_APISERVER_SUBNET_NAME:-"${TP_CLUSTER_NAME}-api-server-subnet"}
export TP_APISERVER_SUBNET_CIDR=${TP_APISERVER_SUBNET_CIDR:-"10.4.19.0/28"}

# create resource group
az group create --location "${TP_AZURE_REGION}" --name "${TP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "resource_group"

# create dns resource group
az group create --location "${TP_AZURE_REGION}" --name "${TP_DNS_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "resource_group"

# create user-assigned identity
az identity create --name "${TP_USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${TP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "identity"
export TP_USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_USER_ASSIGNED_IDENTITY_NAME}" --query 'principalId' -otsv)"

# add contributor privileged role
# required to create resources
az role assignment create \
  --role "Contributor" \
  --assignee-object-id "${TP_USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope /subscriptions/${TP_SUBSCRIPTION_ID} \
  --description "Allow Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# add network contributor permission
# required to join app gateway subnet
az role assignment create \
  --role "Network Contributor" \
  --assignee-object-id "${TP_USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope "/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}" \
  --description "Allow Network Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# add dns zone contributor permission
# required to create new record sets in dns zone
az role assignment create \
  --role "DNS Zone Contributor" \
  --assignee-object-id "${TP_USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope "/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_DNS_RESOURCE_GROUP}" \
  --description "Allow Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# create public ip
az network public-ip create -g "${TP_RESOURCE_GROUP}" -n ${TP_PUBLIC_IP_NAME} --sku "Standard" --allocation-method "Static"
_ret=$?
verify_error "${_ret}" "public_ip"
export TP_PUBLIC_IP_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/${TP_PUBLIC_IP_NAME}"

# create nat gateway
az network nat gateway create --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_NAT_GW_NAME}" --public-ip-addresses "${TP_PUBLIC_IP_ID}"
_ret=$?
verify_error "${_ret}" "nat_gateway"
export TP_NAT_GW_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/natGateways/${TP_NAT_GW_NAME}"

# create virtual network
az network vnet create -g "${TP_RESOURCE_GROUP}" -n "${TP_VNET_NAME}" --address-prefix "${TP_VNET_CIDR}"
_ret=$?
verify_error "${_ret}" "VNet"

# create application gateway subnets
if [ "${TP_ADDON_ENABLE_APPLICATION_GW}" == "true" ]; then
  az network vnet subnet create -g "${TP_RESOURCE_GROUP}" --vnet-name "${TP_VNET_NAME}" -n "${TP_APPLICATION_GW_SUBNET_NAME}" --address-prefixes "${TP_APPLICATION_GW_SUBNET_CIDR}"
  _ret=$?
  verify_error "${_ret}" "application_gateway_subnet"
fi

# create aks subnet
az network vnet subnet create -g ${TP_RESOURCE_GROUP} --vnet-name "${TP_VNET_NAME}" -n "${TP_AKS_SUBNET_NAME}" --address-prefixes "${TP_AKS_SUBNET_CIDR}" --nat-gateway "${TP_NAT_GW_ID}"
_ret=$?
verify_error "${_ret}" "aks_subnet"

# create api server subnet
az network vnet subnet create -g ${TP_RESOURCE_GROUP} --vnet-name "${TP_VNET_NAME}" -n "${TP_APISERVER_SUBNET_NAME}" --address-prefixes "${TP_APISERVER_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "api_server_subnet"

# create nat gateway subnet
az network vnet subnet create -g ${TP_RESOURCE_GROUP} --vnet-name "${TP_VNET_NAME}" -n "${TP_NAT_GW_SUBNET_NAME}" --address-prefixes "${TP_NAT_GW_SUBNET_CIDR}" --nat-gateway "${TP_NAT_GW_ID}"
_ret=$?
verify_error "${_ret}" "nat_gateway_subnet"
export TP_NAT_GW_VNET_SUBNET_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${TP_VNET_NAME}/subnets/${TP_NAT_GW_SUBNET_NAME}"

echo "Finished creating pre-requisites for AKS cluster"