#!/bin/bash
#
# © 2024 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

if [ -z "${GCP_PROJECT_ID}" ]; then
  echo "Please set GCP_PROJECT_ID environment variable"
  exit 1
fi

if [ -z "${TP_CLUSTER_NAME}" ]; then
  echo "Please set TP_CLUSTER_NAME environment variable"
  exit 1
fi

echo "delete GKE cluster ${TP_CLUSTER_NAME}"
gcloud beta container \
  --project "${GCP_PROJECT_ID}" \
  clusters delete --quiet "${TP_CLUSTER_NAME}" \
  --region "${GCP_REGION}"

# check if the cluster has been deleted
while true; do
  # Attempt to get cluster information
  CLUSTER_STATUS=$(gcloud beta container clusters list --project "${GCP_PROJECT_ID}" --region "${GCP_REGION}" --filter="name=${TP_CLUSTER_NAME}" --format="value(status)")

  # If no status is returned, the cluster has been deleted
  if [ -z "$CLUSTER_STATUS" ]; then
    echo "Cluster ${TP_CLUSTER_NAME} has been successfully deleted."
    break
  else
    echo "Cluster ${TP_CLUSTER_NAME} is still deleting... Current status: ${CLUSTER_STATUS}"
  fi

  # Wait 30 seconds before checking again
  sleep 30
done

# Delete Filestore instances inside the VPC
FILSTORE_INSTANCES=$(gcloud beta filestore instances list --project="${GCP_PROJECT_ID}" --location="${GCP_REGION}"-a --filter="networks.network=${TP_CLUSTER_NAME}" --format="value(name)")

# Check if there are any Filestore instances to delete
if [ -z "$FILSTORE_INSTANCES" ]; then
  echo "No Filestore instances found for cluster ${TP_CLUSTER_NAME}."
else
  # Loop through each instance and delete it
  for INSTANCE in $FILSTORE_INSTANCES; do
    echo "Deleting Filestore instance: ${INSTANCE}"
    gcloud beta filestore instances delete "${INSTANCE}" --project="${GCP_PROJECT_ID}" --location="${GCP_REGION}"-a --quiet
    echo "Filestore instance ${INSTANCE} deleted."
  done
fi

echo "delete vpc firewall rule"
gcloud compute firewall-rules delete "${TP_CLUSTER_NAME}" --project="${GCP_PROJECT_ID}" --quiet

# List all subnets associated with the VPC network
SUBNETS=$(gcloud compute networks subnets list --project="${GCP_PROJECT_ID}" --filter="network:${TP_CLUSTER_NAME}" --format="value(name,region)")

# Check if there are any subnets to delete
if [ -z "$SUBNETS" ]; then
  echo "No subnets found for VPC network ${TP_CLUSTER_NAME}."
else
  # Loop through each subnet and delete it
  echo "Deleting subnets associated with VPC network ${TP_CLUSTER_NAME}..."
  while IFS= read -r subnet_info; do
    SUBNET_NAME=$(echo "$subnet_info" | awk '{print $1}')
    SUBNET_REGION=$(echo "$subnet_info" | awk '{print $2}')
    echo "Deleting subnet: ${SUBNET_NAME} in region: ${SUBNET_REGION}"
    gcloud compute networks subnets delete "${SUBNET_NAME}" --project="${GCP_PROJECT_ID}" --region="${SUBNET_REGION}" --quiet
    echo "Subnet ${SUBNET_NAME} deleted."
  done <<< "$SUBNETS"
fi

echo "delete vpc"
gcloud compute networks delete "${TP_CLUSTER_NAME}" --project="${GCP_PROJECT_ID}" --quiet
