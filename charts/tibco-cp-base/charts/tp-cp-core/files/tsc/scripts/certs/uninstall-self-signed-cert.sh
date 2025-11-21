#!/bin/bash

EXIST="exists"
DOES_NOT_EXIST="does not exist"

if [ -z "$POD_NAMESPACE" ]; then
    echo "POD_NAMESPACE is not set"
    exit 1
fi

IDP_KEYSTORE_SECRET_NAME="identity-provider-key-store-password"
IDM_JWT_KEYSTORE_URL_SECRET_NAME="identity-management-jwt-keystore-url"
IDM_JWT_KEYSTORE_PASSWORD_SECRET_NAME="identity-management-jwt-key-store-password"
IDM_CLIENT_ID_SECRET_KEY_SECRET_NAME="identity-management-client-id-secret-key"
IDM_SP_KEYSTORE_SECRET_NAME="identity-management-sp-key-store-password"

# Define an array of secret names
secrets=(
    "$IDP_KEYSTORE_SECRET_NAME"
    "$IDM_JWT_KEYSTORE_URL_SECRET_NAME"
    "$IDM_JWT_KEYSTORE_PASSWORD_SECRET_NAME"
    "$IDM_CLIENT_ID_SECRET_KEY_SECRET_NAME"
    "$IDM_SP_KEYSTORE_SECRET_NAME"
)

check_if_secret_exists() {
    local secretName=$1
    local namespace=$2

    secretValue=$(kubectl get secret -n $namespace $secretName 2>&1)
    errorCode=$?
    if [ $errorCode -ne 0 ]; then
        echo "Failed to get secret $secretName in namespace $namespace"
        return 1
    fi
    if [ -n "$secretValue" ]; then
        echo $EXIST
    else
        echo $DOES_NOT_EXIST
    fi
}

delete_secret() {
    local secretName=$1
    local namespace=$2
    kubectl delete secret $secretName -n $namespace
    if [ $? -ne 0 ]; then
        echo "Failed to delete secret $secretName in namespace $namespace"
        return 1
    fi
}

echo "Attempting to delete IdM and IdP secrets..."

# Loop through the secrets array and delete each secret
for secret in "${secrets[@]}"; do
    doesexists=$(check_if_secret_exists ${secret} ${POD_NAMESPACE})
    if [ "$doesexists" == "$EXIST" ]; then
        echo "Deleting secret $secret in namespace $POD_NAMESPACE"
        if ! delete_secret ${secret} ${POD_NAMESPACE}; then
            echo "Failed to delete secret $secret in namespace $POD_NAMESPACE, exiting..."
            exit 1
        fi
    else
        echo "Secret $secret does not exist in namespace $POD_NAMESPACE"
        echo "Skipping deletion of secret $secret"
    fi
done
echo "IdM and IdP's secrets deleted successfully"
echo "done"