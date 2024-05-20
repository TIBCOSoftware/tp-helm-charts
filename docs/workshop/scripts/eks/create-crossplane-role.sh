#!/bin/bash

set +x

echo "Export Global variables"
export CP_CLUSTER_NAME=${CP_CLUSTER_NAME:-"cp-cluster-infra"}
export CP_CLUSTER_REGION=${CP_CLUSTER_REGION:-"us-west-2"}
_role_name="${CP_CLUSTER_NAME}-crossplane-${CP_CLUSTER_REGION}"
export CP_CROSSPLANE_ROLE="${CP_CROSSPLANE_ROLE:-${_role_name}}"

_ret=''
_created=''
_exists=''

echo "Get Account details"
# assumption is you are using IAM role from the same AWS account
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Get OIDC details"
## OIDC details
OIDC_ISSUER_URL=$(aws eks describe-cluster --name ${CP_CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text)
OIDC_ISSUER_HOSTPATH=$(echo "${OIDC_ISSUER_URL}" | cut -d/ -f3-)
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ISSUER_HOSTPATH}"

cat << EOF > ./trust.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "${OIDC_ISSUER_HOSTPATH}:sub": "system:serviceaccount:crossplane-system:provider-*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
          "AWS": "arn:aws:iam::${ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
EOF

echo "Checking if IAM role exists"
aws iam get-role --role-name ${CP_CROSSPLANE_ROLE}
_exists=$?
if [ ${_exists} -eq 0 ]; then 
  echo "IAM role ${CP_CROSSPLANE_ROLE} already exists"
  echo "continue running attach-role-policy"
else
  echo "IAM role ${CP_CROSSPLANE_ROLE} does not exist"
  echo "creating IAM role"
  aws iam create-role --role-name ${CP_CROSSPLANE_ROLE} --assume-role-policy-document file://trust.json --description "crossplane IAM role for provider-aws"
  _ret=$?
  [ ${_ret} -eq 0 ] || { echo "### ERROR: failed to create IAM role for crossplane. Please re-run the script"; exit ${_ret}; }
fi

echo "Attaching role policy to IAM role ${CP_CROSSPLANE_ROLE}"
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --role-name ${CP_CROSSPLANE_ROLE}
_ret=$?
[ ${_ret} -eq 0 ] || { echo "### ERROR: failed to attach policy to IAM role for crossplane. Please re-run the script"; exit ${_ret}; }

rm -rf trust.json

echo "Waiting for IAM role to be available"
aws iam wait role-exists --role-name ${CP_CROSSPLANE_ROLE}
_created=$?
[ ${_created} -eq 0 ] || { echo "### WARNING: IAM role availability check failed after maximum 30 minutes (30 seconds, 60 checks)"; echo "Response code ${_created}"; }

exit 0