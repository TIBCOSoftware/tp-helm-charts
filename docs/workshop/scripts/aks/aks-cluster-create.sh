#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

echo "Export Global variables"
export DP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export DP_CLUSTER_NAME=${DP_CLUSTER_NAME:-"dp-aks-cluster"}
export DP_RESOURCE_GROUP=${DP_RESOURCE_GROUP:-"dp-resource-group"}
export DP_USER_ASSIGNED_IDENTITY_NAME="${DP_CLUSTER_NAME}-identity"
export DP_NETWORK_POLICY=${DP_NETWORK_POLICY:-"azure"}
export DP_NODE_VM_SIZE_PARAMETER=${DP_NODE_VM_SIZE_PARAMETER:-"Standard_D4s_v3"}
export DP_VNET_NAME=${DP_VNET_NAME:-"${DP_CLUSTER_NAME}-vnet"}
export DP_APPLICATION_GW_SUBNET_NAME=${DP_APPLICATION_GW_SUBNET_NAME:-"${DP_CLUSTER_NAME}-application-gw-subnet"}
export DP_PUBLIC_IP_NAME=${DP_PUBLIC_IP_NAME:-"${DP_CLUSTER_NAME}-public-ip"}
export DP_AKS_SUBNET_NAME=${DP_AKS_SUBNET_NAME:-"${DP_CLUSTER_NAME}-aks-subnet"}
export DP_APISERVER_SUBNET_NAME=${DP_APISERVER_SUBNET_NAME:-"${DP_CLUSTER_NAME}-api-server-subnet"}

# add your public ip
DP_MY_PUBLIC_IP=$(curl https://ipinfo.io/ip)
if [ -n "${DP_AUTHORIZED_IP}" ]; then
  export DP_AUTHORIZED_IP="${DP_AUTHORIZED_IP},${DP_MY_PUBLIC_IP}"
else
  export DP_AUTHORIZED_IP="${DP_MY_PUBLIC_IP}"
fi

# network policy
if [ -n "${DP_NETWORK_POLICY}" ]; then
  export DP_NETWORK_POLICY_PARAMETER=" --network-policy ${DP_NETWORK_POLICY}"
fi

# node vm size
if [ -n "${DP_NODE_VM_SIZE}" ]; then
  export DP_NODE_VM_SIZE_PARAMETER=" --node-vm-size ${DP_NODE_VM_SIZE}"
fi

# append nat gateway public ip
export DP_NAT_GW_PUBLIC_IP=$(az network public-ip show -g ${DP_RESOURCE_GROUP} -n ${DP_PUBLIC_IP_NAME}  --query 'ipAddress' -otsv)
export DP_AUTHORIZED_IP="${DP_AUTHORIZED_IP},${DP_NAT_GW_PUBLIC_IP}"

# set aks identity details
export DP_USER_ASSIGNED_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourcegroups/${DP_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${DP_USER_ASSIGNED_IDENTITY_NAME}"

# set aks vnet details
export DP_AKS_VNET_SUBNET_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${DP_VNET_NAME}/subnets/${DP_AKS_SUBNET_NAME}"

# set application gateway subnet details
export DP_APPLICATION_GW_SUBNET_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${DP_VNET_NAME}/subnets/${DP_APPLICATION_GW_SUBNET_NAME}"

# set api server subnet details
export DP_APISERVER_SUBNET_ID="/subscriptions/${DP_SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${DP_VNET_NAME}/subnets/${DP_APISERVER_SUBNET_NAME}"

# create aks cluster
echo "Start to create AKS: ${DP_RESOURCE_GROUP}/${DP_CLUSTER_NAME}"
az aks create -g "${DP_RESOURCE_GROUP}" -n "${DP_CLUSTER_NAME}" \
  --node-count 3${DP_NODE_VM_SIZE_PARAMETER} \
  --enable-addons ingress-appgw \
  --enable-msi-auth-for-monitoring false \
  --generate-ssh-keys \
  --api-server-authorized-ip-ranges "${DP_AUTHORIZED_IP}" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --network-plugin azure${DP_NETWORK_POLICY_PARAMETER} \
  --kubernetes-version "1.27.7" \
  --outbound-type userAssignedNATGateway \
  --appgw-name gateway \
  --vnet-subnet-id "${DP_AKS_VNET_SUBNET_ID}" \
  --appgw-subnet-id "${DP_APPLICATION_GW_SUBNET_ID}" \
  --enable-apiserver-vnet-integration \
  --apiserver-subnet-id "${DP_APISERVER_SUBNET_ID}" \
  --assign-identity "${DP_USER_ASSIGNED_ID}" \
  --assign-kubelet-identity "${DP_USER_ASSIGNED_ID}"
_ret=$?
verify_error "${_ret}" "cluster"

echo "Finished creating AKS cluster"