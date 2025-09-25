#!/bin/bash
set +x

# delete the tmp file if it already exists
if [ -f tmp_pvc_list.txt ]; then
  echo "removing the existing tmp file"
  rm -rf tmp_pvc_list.txt
fi

echo "Export Global variables"
export TP_AZURE_REGION=${TP_AZURE_REGION:-"eastus"}
export TP_RESOURCE_GROUP=${TP_RESOURCE_GROUP:-"openshift-azure"}
export TP_STORAGE_ACCOUNT_RESOURCE_GROUP="${TP_STORAGE_ACCOUNT_RESOURCE_GROUP}"
export TP_STORAGE_ACCOUNT_NAME=${TP_STORAGE_ACCOUNT_NAME}

# list the persistent volumes in a file
oc get pv -o jsonpath='{range .items[?(@.spec.csi.driver=="file.csi.azure.com")]}{.metadata.name}{"\n"}{end}' >> tmp_pvc_list.txt

echo "deleting resource group"
az group delete -n ${TP_RESOURCE_GROUP} -y

# explicit fileshares deletion is require if it is NOT same as AKS resource group
# otherwise fileshares will be deleted as part of the resource group deletion
if [ -n "${TP_STORAGE_ACCOUNT_RESOURCE_GROUP}" ] && [ "${TP_STORAGE_ACCOUNT_RESOURCE_GROUP}" != "${TP_RESOURCE_GROUP}" ]; then
  echo "deleting file shares"
  while read -r line
    do
      echo "deleting ${line} in storage account ${TP_STORAGE_ACCOUNT_NAME}"
      az storage share delete --name ${line} --delete-snapshots "include" --account-name ${TP_STORAGE_ACCOUNT_NAME}
    done < tmp_pvc_list.txt
fi  

# remove tmp file
rm -rf tmp_pvc_list.txt 