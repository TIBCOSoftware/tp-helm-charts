#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

# create resource group
az group create --location "${AZURE_REGION}" --name "${DP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "resource_group"

# create user-assigned identity
az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${DP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "identity"
export USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --resource-group "${DP_RESOURCE_GROUP}" --name "${USER_ASSIGNED_IDENTITY_NAME}" --query 'principalId' -otsv)"

# add contributor privileged role
# required to create resources
az role assignment create \
  --role "Contributor" \
  --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope /subscriptions/${SUBSCRIPTION_ID} \
  --description "Allow Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# add network contributor permission
# required to join app gateway subnet
az role assignment create \
  --role "Network Contributor" \
  --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}" \
  --description "Allow Network Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# add dns zone contributor permission
# required to create new record sets in dns zone
az role assignment create \
  --role "DNS Zone Contributor" \
  --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
  --assignee-principal-type "ServicePrincipal" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_DNS_RESOURCE_GROUP}" \
  --description "Allow Contributor access to AKS Managed Identity"
_ret=$?
verify_error "${_ret}" "role_assignment"

# create public ip
az network public-ip create -g "${DP_RESOURCE_GROUP}" -n ${PUBLIC_IP_NAME} --sku "Standard" --allocation-method "Static"
_ret=$?
verify_error "${_ret}" "public_ip"
export PUBLIC_IP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/${PUBLIC_IP_NAME}"

# create nat gateway
az network nat gateway create --resource-group "${DP_RESOURCE_GROUP}" --name "${NAT_GW_NAME}" --public-ip-addresses "${PUBLIC_IP_ID}"
_ret=$?
verify_error "${_ret}" "nat_gateway"
export NAT_GW_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/natGateways/${NAT_GW_NAME}"

# create virtual network
az network vnet create -g "${DP_RESOURCE_GROUP}" -n "${VNET_NAME}" --address-prefix "${VNET_CIDR}" 
_ret=$?
verify_error "${_ret}" "VNet"

# create application gateway subnets
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${VNET_NAME}" -n "${APPLICATION_GW_SUBNET_NAME}" --address-prefixes "${APPLICATION_GW_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "application_gateway_subnet"

# create aks subnet
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${VNET_NAME}" -n "${AKS_SUBNET_NAME}" --address-prefixes "${AKS_SUBNET_CIDR}" --nat-gateway "${NAT_GW_ID}"
_ret=$?
verify_error "${_ret}" "aks_subnet"

# create aks subnet
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${VNET_NAME}" -n "${APISERVER_SUBNET_NAME}" --address-prefixes "${APISERVER_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "api_server_subnet"

# create nat gateway subnet
az network vnet subnet create -g ${DP_RESOURCE_GROUP} --vnet-name "${VNET_NAME}" -n "${NAT_GW_SUBNET_NAME}" --address-prefixes "${NAT_GW_SUBNET_CIDR}" --nat-gateway "${NAT_GW_ID}"
_ret=$?
verify_error "${_ret}" "nat_gateway_subnet"
export NAT_GW_VNET_SUBNET_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${NAT_GW_SUBNET_NAME}"

echo "finished creating pre-requisites for AKS cluster"