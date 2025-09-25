#!/bin/bash
set +x

function verify_error() {
  _exit_code="${1}"
  _command="${2}"
  [ "${_exit_code}" -eq "0" ] || { echo "Failed to run the az command to create ${_command}"; exit ${_exit_code}; }
}

echo "Export Global variables"

export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TP_TENANT_ID=$(az account show --query tenantId -o tsv)
export TP_AZURE_REGION=${TP_AZURE_REGION:-"eastus"}
export TP_RESOURCE_GROUP=${TP_RESOURCE_GROUP:-"openshift-azure"}
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"aroCluster"}
export TP_WORKER_COUNT=${TP_WORKER_COUNT:-6}
export TP_VNET_NAME=${TP_VNET_NAME:-"openshiftvnet"}
export TP_VNET_CIDR=${TP_VNET_CIDR:-"10.0.0.0/8"}
export TP_MASTER_SUBNET_NAME=${TP_MASTER_SUBNET_NAME:-"masterOpenshiftSubnet"}
export TP_MASTER_SUBNET_CIDR=${TP_MASTER_SUBNET_CIDR:-"10.0.0.0/23"}
export TP_WORKER_SUBNET_NAME=${TP_WORKER_SUBNET_NAME:-"workerOpenshiftSubnet"}
export TP_WORKER_SUBNET_CIDR=${TP_WORKER_SUBNET_CIDR:-"10.0.2.0/23"}

# create resource group
az group create --location "${TP_AZURE_REGION}" --name "${TP_RESOURCE_GROUP}"
_ret=$?
verify_error "${_ret}" "resource_group"

# create virtual network
az network vnet create -g "${TP_RESOURCE_GROUP}" -n "${TP_VNET_NAME}" --address-prefix "${TP_VNET_CIDR}"
_ret=$?
verify_error "${_ret}" "VNet"

# create master nodes subnet
az network vnet subnet create -g "${TP_RESOURCE_GROUP}" --vnet-name "${TP_VNET_NAME}" -n "${TP_MASTER_SUBNET_NAME}" --address-prefixes "${TP_MASTER_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "master_nodes_subnet"

# create worker nodes subnet
az network vnet subnet create -g "${TP_RESOURCE_GROUP}" --vnet-name "${TP_VNET_NAME}" -n "${TP_WORKER_SUBNET_NAME}" --address-prefixes "${TP_WORKER_SUBNET_CIDR}"
_ret=$?
verify_error "${_ret}" "worker_nodes_subnet"

echo "Finished creating pre-requisites for ARO cluster"