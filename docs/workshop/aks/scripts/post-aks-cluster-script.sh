#!/bin/bash
set +x

echo "Export Global variables"
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TP_TENANT_ID=$(az account show --query tenantId -o tsv)
export TP_AZURE_REGION=${TP_AZURE_REGION:-"westus2"}
export TP_RESOURCE_GROUP=${TP_RESOURCE_GROUP:-"dp-resource-group"}
export TP_CLUSTER_NAME=${TP_CLUSTER_NAME:-"dp-aks-cluster"}
export TP_USER_ASSIGNED_IDENTITY_NAME="${TP_CLUSTER_NAME}-identity"
export TP_DNS_RESOURCE_GROUP=${TP_DNS_RESOURCE_GROUP:-"cic-dns"}

export TP_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az aks show --resource-group "${TP_RESOURCE_GROUP}" --name "${TP_CLUSTER_NAME}" --query "identityProfile.kubeletidentity.clientId" --output tsv)

# get oidc issuer
export TP_AKS_OIDC_ISSUER="$(az aks show -n ${TP_CLUSTER_NAME} -g "${TP_RESOURCE_GROUP}" --query "oidcIssuerProfile.issuerUrl" -otsv)"

# workload identity federation for cert manager
echo "Create federated workload identity federation for ${TP_USER_ASSIGNED_IDENTITY_NAME} in cert-manager/cert-manager"
az identity federated-credential create --name "cert-manager-cert-manager-federated" \
  --resource-group "${TP_RESOURCE_GROUP}" \
  --identity-name "${TP_USER_ASSIGNED_IDENTITY_NAME}" \
  --issuer "${TP_AKS_OIDC_ISSUER}" \
  --subject system:serviceaccount:cert-manager:cert-manager \
  --audience api://AzureADTokenExchange

# workload identity federation for external dns system
echo "Ceate federated workload identity federation for ${TP_USER_ASSIGNED_IDENTITY_NAME} in external-dns-system/external-dns"
az identity federated-credential create --name "external-dns-system-external-dns-federated" \
  --resource-group "${TP_RESOURCE_GROUP}" \
  --identity-name "${TP_USER_ASSIGNED_IDENTITY_NAME}" \
  --issuer "${TP_AKS_OIDC_ISSUER}" \
  --subject system:serviceaccount:external-dns-system:external-dns \
  --audience api://AzureADTokenExchange

# external dns configuration
TP_AZURE_EXTERNAL_DNS_JSON_FILE=azure.json

cat <<-EOF > ${TP_AZURE_EXTERNAL_DNS_JSON_FILE}
{
  "tenantId": "${TP_TENANT_ID}",
  "subscriptionId": "${TP_SUBSCRIPTION_ID}",
  "resourceGroup": "${TP_DNS_RESOURCE_GROUP}",
  "useManagedIdentityExtension": true, 
  "userAssignedIdentityID": "${TP_USER_ASSIGNED_IDENTITY_CLIENT_ID}"
}
EOF

# connect to cluster
az aks get-credentials --name "${TP_CLUSTER_NAME}" --resource-group "${TP_RESOURCE_GROUP}" --file "${KUBECONFIG}" --overwrite-existing

# create namespace and secrets for external-dns-system
kubectl create ns external-dns-system
kubectl delete secret --namespace external-dns-system azure-config-file
kubectl create secret generic azure-config-file --namespace external-dns-system --from-file ./${TP_AZURE_EXTERNAL_DNS_JSON_FILE}

rm -rf ./${TP_AZURE_EXTERNAL_DNS_JSON_FILE}

echo "finished running post-creation scripts of AKS cluster"