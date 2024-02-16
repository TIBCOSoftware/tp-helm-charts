#!/bin/bash
set +x

echo "Export Global variables"
export DP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export DP_TENANT_ID=$(az account show --query tenantId -o tsv)
export DP_AZURE_REGION=${DP_AZURE_REGION:-"westus2"}
export DP_RESOURCE_GROUP=${DP_RESOURCE_GROUP:-"dp-resource-group"}
export DP_CLUSTER_NAME=${DP_CLUSTER_NAME:-"dp-aks-cluster"}
export DP_USER_ASSIGNED_IDENTITY_NAME="${DP_CLUSTER_NAME}-identity"
export DP_DNS_RESOURCE_GROUP=${DP_DNS_RESOURCE_GROUP:-"cic-dns"}

export DP_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az aks show --resource-group "${DP_RESOURCE_GROUP}" --name "${DP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)

# get oidc issuer
export DP_AKS_OIDC_ISSUER="$(az aks show -n ${DP_CLUSTER_NAME} -g "${DP_RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -otsv)"

# workload identity federation for cert manager
echo "Create federated workload identity federation for ${DP_USER_ASSIGNED_IDENTITY_NAME} in cert-manager/cert-manager"
az identity federated-credential create --name "cert-manager-cert-manager-federated" \
  --resource-group "${DP_RESOURCE_GROUP}" \
  --identity-name "${DP_USER_ASSIGNED_IDENTITY_NAME}" \
  --issuer "${DP_AKS_OIDC_ISSUER}" \
  --subject system:serviceaccount:cert-manager:cert-manager \
  --audience api://AzureADTokenExchange

# workload identity federation for external dns system
echo "Ceate federated workload identity federation for ${DP_USER_ASSIGNED_IDENTITY_NAME} in external-dns-system/external-dns"
az identity federated-credential create --name "external-dns-system-external-dns-federated" \
  --resource-group "${DP_RESOURCE_GROUP}" \
  --identity-name "${DP_USER_ASSIGNED_IDENTITY_NAME}" \
  --issuer "${DP_AKS_OIDC_ISSUER}" \
  --subject system:serviceaccount:external-dns-system:external-dns \
  --audience api://AzureADTokenExchange

# external dns configuration
DP_AZURE_EXTERNAL_DNS_JSON_FILE=azure.json

cat <<-EOF > ${DP_AZURE_EXTERNAL_DNS_JSON_FILE}
{
  "tenantId": "${DP_TENANT_ID}",
  "subscriptionId": "${DP_SUBSCRIPTION_ID}",
  "resourceGroup": "${DP_DNS_RESOURCE_GROUP}",
  "useManagedIdentityExtension": true, 
  "userAssignedIdentityID": "${DP_USER_ASSIGNED_IDENTITY_CLIENT_ID}"
}
EOF

# connect to cluster
az aks get-credentials --name "${DP_CLUSTER_NAME}" --resource-group "${DP_RESOURCE_GROUP}" --file "${KUBECONFIG}" --overwrite-existing

# create namespace and secrets for external-dns-system
kubectl create ns external-dns-system
kubectl delete secret --namespace external-dns-system azure-config-file
kubectl create secret generic azure-config-file --namespace external-dns-system --from-file ./${DP_AZURE_EXTERNAL_DNS_JSON_FILE}

rm -rf ./${DP_AZURE_EXTERNAL_DNS_JSON_FILE}

echo "finished running post-creation scripts of AKS cluster"