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

# default values
export GCP_REGION=${TP_CLUSTER_REGION:-us-west1}
export TP_CLUSTER_VPC_CIDR=${TP_CLUSTER_VPC_CIDR:-"10.0.0.0/20"}
# must be less than /21 otherwise: Cluster CIDR range is greater than maximum (24 > 21)
export TP_CLUSTER_CIDR=${TP_CLUSTER_CIDR:-"10.1.0.0/16"}
export TP_CLUSTER_SERVICE_CIDR=${TP_CLUSTER_SERVICE_CIDR:-"10.2.0.0/20"}
export TP_CLUSTER_VERSION=${TP_CLUSTER_VERSION:-"1.30.3-gke.1969001"}
export TP_CLUSTER_INSTANCE_TYPE=${TP_CLUSTER_INSTANCE_TYPE:-"e2-standard-4"}
export TP_CLUSTER_DESIRED_CAPACITY=${TP_CLUSTER_DESIRED_CAPACITY:-"2"}
if [[ "$TP_ENABLE_NETWORK_POLICY" = "true" ]]
then
  export ENABLE_NETWORK_POLICY="--enable-network-policy"
else
  export ENABLE_NETWORK_POLICY=""
fi

# add your public ip
TP_MY_PUBLIC_IP=$(curl https://ipinfo.io/ip)
if [ -n "${TP_AUTHORIZED_IP}" ]; then
  export AUTHORIZED_IP="${TP_AUTHORIZED_IP},${TP_MY_PUBLIC_IP}/32"
else
  export AUTHORIZED_IP="${TP_MY_PUBLIC_IP}/32"
fi

echo "create vpc"
gcloud compute networks create "${TP_CLUSTER_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --description=TIBCO\ Platform\ VPC \
  --subnet-mode=custom \
  --mtu=1460 \
  --bgp-routing-mode=regional
if [ $? -ne 0 ]; then
  echo "create vpc failed"
  exit 1
fi

echo "create subnet"
gcloud compute networks subnets create "${TP_CLUSTER_NAME}" \
  --network "${TP_CLUSTER_NAME}" \
  --region "${GCP_REGION}" \
  --range "${TP_CLUSTER_VPC_CIDR}"
if [ $? -ne 0 ]; then
  echo "create vpc failed"
  exit 1
fi

echo "create firewall rule"
gcloud compute firewall-rules create "${TP_CLUSTER_NAME}" \
  --project="${GCP_PROJECT_ID}" \
  --network=projects/"${GCP_PROJECT_ID}"/global/networks/"${TP_CLUSTER_NAME}" \
  --description=Allows\ connection\ from\ any\ source\ to\ any\ instance\ on\ the\ network\ using\ custom\ protocols. \
  --direction=INGRESS \
  --priority=65534 \
  --source-ranges="${AUTHORIZED_IP}" \
  --action=ALLOW \
  --rules=all
if [ $? -ne 0 ]; then
  echo "create firewall rule failed"
  exit 1
fi

echo "create GKE"
gcloud beta container \
  --project "${GCP_PROJECT_ID}" \
  clusters create "${TP_CLUSTER_NAME}" \
  --region "${GCP_REGION}" \
  --no-enable-basic-auth \
  --cluster-version "${TP_CLUSTER_VERSION}" \
  --release-channel "regular" \
  --machine-type "${TP_CLUSTER_INSTANCE_TYPE}" \
  --image-type "COS_CONTAINERD" \
  --disk-type "pd-balanced" \
  --disk-size "50" \
  --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
  --num-nodes "${TP_CLUSTER_DESIRED_CAPACITY}" \
  --monitoring=SYSTEM \
  --enable-ip-alias \
  --network "${TP_CLUSTER_NAME}" \
  --subnetwork "${TP_CLUSTER_NAME}" \
  --cluster-ipv4-cidr "${TP_CLUSTER_CIDR}" \
  --services-ipv4-cidr "${TP_CLUSTER_SERVICE_CIDR}" \
  --no-enable-intra-node-visibility \
  --default-max-pods-per-node "110" \
  --enable-autoscaling \
  --total-min-nodes "0" \
  --total-max-nodes "10" \
  --location-policy "BALANCED" \
  --security-posture=standard \
  --workload-vulnerability-scanning=disabled \
  --enable-master-authorized-networks \
  --master-authorized-networks "${AUTHORIZED_IP}" \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver,GcpFilestoreCsiDriver \
  --enable-autoupgrade \
  --enable-autorepair \
  --max-surge-upgrade 1 \
  --max-unavailable-upgrade 0 \
  --binauthz-evaluation-mode=DISABLED \
  --no-enable-managed-prometheus \
  --workload-pool "${GCP_PROJECT_ID}.svc.id.goog" \
  --enable-shielded-nodes \
  ${ENABLE_NETWORK_POLICY} \
  --node-locations "${GCP_REGION}-a"