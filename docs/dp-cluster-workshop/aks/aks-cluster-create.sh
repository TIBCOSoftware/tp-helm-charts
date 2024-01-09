#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

# add your public ip
MY_PUBLIC_IP=$(curl https://ipinfo.io/ip)
if [ -n "${AUTHORIZED_IP}" ]; then
  export AUTHORIZED_IP="${AUTHORIZED_IP},${MY_PUBLIC_IP}"
else
  export AUTHORIZED_IP="${MY_PUBLIC_IP}"
fi

if [ -n "${DP_NETWORK_POLICY}" ]; then
  export NETWORK_POLICY_PARAMETER=" --network-policy ${DP_NETWORK_POLICY}"
fi

# append nat gateway public ip
export NAT_GW_PUBLIC_IP=$(az network public-ip show -g ${DP_RESOURCE_GROUP} -n ${PUBLIC_IP_NAME}  --query 'ipAddress' -otsv)
export AUTHORIZED_IP="${AUTHORIZED_IP},${NAT_GW_PUBLIC_IP}"

# set aks identity details
export USER_ASSIGNED_ID="/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${DP_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${USER_ASSIGNED_IDENTITY_NAME}"

# set aks vnet details
export AKS_VNET_SUBNET_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${AKS_SUBNET_NAME}"

# set application gateway subnet details
export APPLICATION_GW_SUBNET_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${APPLICATION_GW_SUBNET_NAME}"

# set api server subnet details
export APISERVER_SUBNET_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${DP_RESOURCE_GROUP}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${APISERVER_SUBNET_NAME}"

# create aks cluster
echo "start to create AKS: ${DP_RESOURCE_GROUP}/${DP_CLUSTER_NAME}"
az aks create -g "${DP_RESOURCE_GROUP}" -n "${DP_CLUSTER_NAME}" \
  --node-count 3 \
  --enable-addons ingress-appgw \
  --enable-msi-auth-for-monitoring false \
  --generate-ssh-keys \
  --api-server-authorized-ip-ranges "${AUTHORIZED_IP}" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --network-plugin azure${NETWORK_POLICY_PARAMETER} \
  --kubernetes-version "1.27.7" \
  --outbound-type userAssignedNATGateway \
  --appgw-name gateway \
  --vnet-subnet-id "${AKS_VNET_SUBNET_ID}" \
  --appgw-subnet-id "${APPLICATION_GW_SUBNET_ID}" \
  --enable-apiserver-vnet-integration \
  --apiserver-subnet-id "${APISERVER_SUBNET_ID}" \
  --assign-identity "${USER_ASSIGNED_ID}" \
  --assign-kubelet-identity "${USER_ASSIGNED_ID}"
_ret=$?
verify_error "${_ret}" "cluster"

echo "finished creating AKS cluster"