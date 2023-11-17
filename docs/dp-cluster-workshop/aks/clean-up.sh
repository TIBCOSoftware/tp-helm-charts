#!/bin/bash
set +x

# delete the tmp file if it already exists
if [ -f tmp_pvc_list.txt ]; then
  echo "removing the existing tmp file"
  rm -rf tmp_pvc_list.txt
fi

# list the persistent volumes in a file
kubectl get pv -o jsonpath='{range .items[?(@.spec.csi.driver=="file.csi.azure.com")]}{.metadata.name}{"\n"}{end}' >> tmp_pvc_list.txt

echo "deleting all ingress objects"
kubectl delete ingress -A --all

echo "sleep 2 minutes"
sleep 120

echo "deleting all installed charts with no layer labels"
helm ls --selector '!layer' -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r line; do
  release=$(echo ${line} | awk '{print $1}')
  namespace=$(echo ${line} | awk '{print $2}')
  helm uninstall -n "${namespace}" "${release}"
done

for (( _chart_layer=2 ; _chart_layer>=0 ; _chart_layer-- ));
do
  echo "deleting all installed charts with layer ${_chart_layer} labels"
  helm ls --selector "layer=${_chart_layer}" -a -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read -r line; do
    release=$(echo ${line} | awk '{print $1}')
    namespace=$(echo ${line} | awk '{print $2}')
    helm uninstall -n "${namespace}" "${release}"
  done
done

echo "deleting resource group"
az group delete -n ${DP_RESOURCE_GROUP} -y

echo "deleting file shares"
while read -r line
  do
    echo "deleting ${line} in storage account ${STORAGE_ACCOUNT_NAME}"
    az storage share delete --name ${line} --delete-snapshots "include" --account-name ${STORAGE_ACCOUNT_NAME}
  done < tmp_pvc_list.txt

# remove tmp file
rm -rf tmp_pvc_list.txt