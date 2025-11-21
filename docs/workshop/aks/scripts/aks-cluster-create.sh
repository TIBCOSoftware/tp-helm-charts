#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

echo "Export Global variables"
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"dp-aks-cluster"}
export TP_RESOURCE_GROUP=${TP_RESOURCE_GROUP:-"dp-resource-group"}
export TP_USER_ASSIGNED_IDENTITY_NAME="${TP_CLUSTER_NAME}-identity"
export TP_NETWORK_PLUGIN=${TP_NETWORK_PLUGIN:-"azure"}
export TP_NETWORK_POLICY=${TP_NETWORK_POLICY:-"azure"}
export TP_NODE_VM_SIZE=${TP_NODE_VM_SIZE:-"Standard_D4s_v3"}
export TP_NODE_VM_SIZE_PARAMETER=${TP_NODE_VM_SIZE_PARAMETER:-"Standard_D4s_v3"}
export TP_VNET_NAME=${TP_VNET_NAME:-"${TP_CLUSTER_NAME}-vnet"}
export TP_SERVICE_CIDR=${TP_SERVICE_CIDR:-"10.0.0.0/16"}
export TP_SERVICE_DNS_IP=${TP_SERVICE_DNS_IP:-"10.0.0.10"}
export TP_ADDON_ENABLE_APPLICATION_GW=${TP_ADDON_ENABLE_APPLICATION_GW:-"false"}
export TP_APPLICATION_GW_SUBNET_NAME=${TP_APPLICATION_GW_SUBNET_NAME:-"${TP_CLUSTER_NAME}-application-gw-subnet"}
export TP_PUBLIC_IP_NAME=${TP_PUBLIC_IP_NAME:-"${TP_CLUSTER_NAME}-public-ip"}
export TP_AKS_SUBNET_NAME=${TP_AKS_SUBNET_NAME:-"${TP_CLUSTER_NAME}-aks-subnet"}
export TP_APISERVER_SUBNET_NAME=${TP_APISERVER_SUBNET_NAME:-"${TP_CLUSTER_NAME}-api-server-subnet"}
export TP_KUBERNETES_VERSION=${TP_KUBERNETES_VERSION:-"1.33"}


# add your public ip
TP_MY_PUBLIC_IP=$(curl https://ipinfo.io/ip)
if [ -n "${TP_AUTHORIZED_IP}" ]; then
  export TP_AUTHORIZED_IP="${TP_AUTHORIZED_IP},${TP_MY_PUBLIC_IP}"
else
  export TP_AUTHORIZED_IP="${TP_MY_PUBLIC_IP}"
fi

# node vm size
if [ -n "${TP_NODE_VM_SIZE}" ]; then
  export TP_NODE_VM_SIZE_PARAMETER=" --node-vm-size ${TP_NODE_VM_SIZE}"
fi

# append nat gateway public ip
export TP_NAT_GW_PUBLIC_IP=$(az network public-ip show -g ${TP_RESOURCE_GROUP} -n ${TP_PUBLIC_IP_NAME}  --query 'ipAddress' -otsv)
export TP_AUTHORIZED_IP="${TP_AUTHORIZED_IP},${TP_NAT_GW_PUBLIC_IP}"

# set aks identity details
export TP_USER_ASSIGNED_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourcegroups/${TP_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${TP_USER_ASSIGNED_IDENTITY_NAME}"

# set aks vnet details
export TP_AKS_VNET_SUBNET_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${TP_VNET_NAME}/subnets/${TP_AKS_SUBNET_NAME}"

export TP_APPLICATION_GW_PARAMETER=""
# set application gateway subnet details and other details related to application gateway
if [ "${TP_ADDON_ENABLE_APPLICATION_GW}" == "true" ]; then
  export TP_APPLICATION_GW_SUBNET_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${TP_VNET_NAME}/subnets/${TP_APPLICATION_GW_SUBNET_NAME}"
  export TP_APPLICATION_GW_PARAMETER="--enable-addons ingress-appgw --appgw-name ${TP_CLUSTER_NAME}-app-gw --appgw-subnet-id ${TP_APPLICATION_GW_SUBNET_ID}"
fi

# set api server subnet details
export TP_APISERVER_SUBNET_ID="/subscriptions/${TP_SUBSCRIPTION_ID}/resourceGroups/${TP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${TP_VNET_NAME}/subnets/${TP_APISERVER_SUBNET_NAME}"

# create aks cluster
echo "Start to create AKS: ${TP_RESOURCE_GROUP}/${TP_CLUSTER_NAME}"
az aks create -g "${TP_RESOURCE_GROUP}" -n "${TP_CLUSTER_NAME}" \
  --node-count ${TP_NODE_VM_COUNT} ${TP_NODE_VM_SIZE_PARAMETER} \
  --enable-msi-auth-for-monitoring false \
  --generate-ssh-keys ${TP_APPLICATION_GW_PARAMETER} \
  --api-server-authorized-ip-ranges "${TP_AUTHORIZED_IP}" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --network-plugin ${TP_NETWORK_PLUGIN} \
  --network-policy ${TP_NETWORK_POLICY} \
  --kubernetes-version "${TP_KUBERNETES_VERSION}" \
  --outbound-type userAssignedNATGateway \
  --vnet-subnet-id "${TP_AKS_VNET_SUBNET_ID}" \
  --service-cidr "${TP_SERVICE_CIDR}" \
  --dns-service-ip "${TP_SERVICE_DNS_IP}" \
  --enable-apiserver-vnet-integration \
  --apiserver-subnet-id "${TP_APISERVER_SUBNET_ID}" \
  --assign-identity "${TP_USER_ASSIGNED_ID}" \
  --assign-kubelet-identity "${TP_USER_ASSIGNED_ID}"
_ret=$?
verify_error "${_ret}" "cluster"

echo "Finished creating AKS cluster"