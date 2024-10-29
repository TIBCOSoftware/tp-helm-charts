#!/bin/bash
#
# © 2024 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

#######################################
# prepare-gke-sa - create pre-requisites for GKE cluster
# Globals:
#   GCP_PROJECT_ID: gcp project id
# Arguments:
#   None
# Returns:
#   0 if thing was deleted, non-zero on error
# Notes:
#   None
# Samples:
#   None
#######################################

if [ -z "${GCP_PROJECT_ID}" ]; then
  echo "Please set GCP_PROJECT_ID environment variable"
  exit 1
fi

############################# Part 1 enable APIs #############################
# Enable Kubernetes Engine API
echo "Enabling Kubernetes Engine API..."
gcloud services enable container.googleapis.com --project="${GCP_PROJECT_ID}"
echo "Kubernetes Engine API enabled."

# Enable Cloud Filestore API
echo "Enabling Cloud Filestore API..."
gcloud services enable file.googleapis.com --project="${GCP_PROJECT_ID}"
echo "Cloud Filestore API enabled."

############################# Part 2 setup IAM #############################

# Check if the service account exists
function check_service_account() {
  _gcp_sa_name=$1
  gcloud iam service-accounts list --filter="email=${_gcp_sa_name}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --format="value(email)"
}

# Create Service Account
# create-gcp-k8s-sa <project_id> <sa_name> <sa_namespace_name> <sa_role>
function create-gcp-k8s-sa() {
  _gcp_project_id=$1
  _gcp_sa_name=$2
  _gcp_sa_namespace_name=$3
  _gcp_sa_role=$4
  gcloud iam service-accounts create "${_gcp_sa_name}" \
    --display-name "${_gcp_sa_name}"
  if [ $? -ne 0 ]; then
    echo "Failed to create service account ${_gcp_sa_name}"
    return 1
  fi

  gcloud projects add-iam-policy-binding "${_gcp_project_id}" \
     --member "serviceAccount:${_gcp_sa_name}@${_gcp_project_id}.iam.gserviceaccount.com" \
     --role "${_gcp_sa_role}"
  if [ $? -ne 0 ]; then
    echo "Failed to add role to service account ${_gcp_sa_name}"
    return 1
  fi

  gcloud iam service-accounts add-iam-policy-binding \
      --role roles/iam.workloadIdentityUser \
      --member "serviceAccount:${_gcp_project_id}.svc.id.goog[${_gcp_sa_namespace_name}]" \
      "${_gcp_sa_name}@${_gcp_project_id}.iam.gserviceaccount.com"
  if [ $? -ne 0 ]; then
    echo "Failed to add role to service account ${_gcp_sa_name}"
    return 1
  fi
}

echo "Prepare GKE Service Accounts for project ${GCP_PROJECT_ID}"

## Create Service Account for Cert Manager
export GCP_SA_CERT_MANAGER_NAME="tp-cert-manager-sa"

# Check if the service account exists
EXISTING_SA=$(check_service_account "${GCP_SA_CERT_MANAGER_NAME}")
if [ -z "$EXISTING_SA" ]; then
  ## Service Account for Cert Manager
  create-gcp-k8s-sa "${GCP_PROJECT_ID}" "${GCP_SA_CERT_MANAGER_NAME}" "cert-manager/cert-manager" "roles/dns.admin"
  if [ $? -ne 0 ]; then
    echo "Failed to create service account ${GCP_SA_CERT_MANAGER_NAME}"
    exit 1
  fi
else
  echo "Service account ${GCP_SA_CERT_MANAGER_NAME} already exists."
fi


## Create Service Account for Cert Manager
export GCP_SA_EXTERNAL_DNS_NAME="tp-external-dns-sa"

EXISTING_SA=$(check_service_account "${GCP_SA_EXTERNAL_DNS_NAME}")
if [ -z "$EXISTING_SA" ]; then
  ## Service Account for External DNS
  create-gcp-k8s-sa "${GCP_PROJECT_ID}" "${GCP_SA_EXTERNAL_DNS_NAME}" "external-dns-system/external-dns" "roles/dns.admin"
  if [ $? -ne 0 ]; then
    echo "Failed to create service account ${GCP_SA_EXTERNAL_DNS_NAME}"
    exit 1
  fi
else
  echo "Service account ${GCP_SA_EXTERNAL_DNS_NAME} already exists."
fi
