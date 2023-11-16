#!/bin/bash

#
# Copyright (c) 2023 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#

# ./render-chart-template.sh traefik-system dp-config-aws <path to chart>

NAMESPACE=${1}
CHART_NAME=${2}
UPDATE_REPO=${3}

[ -n "${NAMESPACE}" ] || { >&2 echo "ERROR: Please put NAMESPACE."; exit 1; }
[ -n "${CHART_NAME}" ] || { >&2 echo "ERROR: Please put CHART_NAME."; exit 1; }
UPDATE_REPO=${UPDATE_REPO:-false}

pushd ../charts || exit

# sample value
cat <<EOF> values-customize.yaml
traefik:
  enabled: false
global:
  clusterName: "dp1-s01"
  oidc_provider_arn: "arn:aws:iam::<accountId>:oidc-provider/oidc.eks.us-east-2.amazonaws.com/id/6D124EBE627694798BA9BF7D18Exxxxx"
  oidc_issuer_hostpath: "oidc.eks.us-east-2.amazonaws.com/id/6D124EBE627694798BA9BF7D18Exxxxx"
  where: aws
  env:
    accountId: ""
    region: "us-east-2"
EOF

if [[ ${UPDATE_REPO} == true ]]; then
  ../dev/get-repo-depency.sh ${CHART_NAME}
fi

echo "Generating template ${CIC_LAYER}"
helm template --debug -n ${NAMESPACE} ${CHART_NAME} ${CHART_NAME} --values values-customize.yaml > template.yaml
if [ $? -ne 0 ]; then
  echo "helm template error"
  exit
fi

echo "helm lint"
helm lint -n ${NAMESPACE} ${CHART_NAME} --values values-customize.yaml

popd
