#!/bin/bash

export MSYS_NO_PATHCONV=1

inputCommand=$1
echo "Generate self signed certs for: ${inputCommand}..."
echo "============================================================================="
EXIST="exists"
DOES_NOT_EXIST="does not exist"

# Use legacy secret names and keys
IDM_SP_KEYSTORE_SECRET_NAME="identity-management-sp-key-store-password"
IDM_CLIENT_ID_SECRET_KEY_SECRET_NAME="identity-management-client-id-secret-key"
IDP_KEYSTORE_SECRET_NAME="identity-provider-key-store-password"
IDP_SECRET_KEY="IDENTITY_PROVIDER_KEY_STORE_PASSWORD"
IDM_JWT_KEYSTORE_URL_SECRET_NAME="identity-management-jwt-keystore-url"
IDM_JWT_KEYSTORE_SECRET_NAME="identity-management-jwt-key-store-password"
IDM_JWT_KEYSTORE_URL_KEY="IDENTITY_MANAGEMENT_JWT_KEYSTORE_URL"
IDM_JWT_KEYSTORE_PASSWORD_KEY="IDENTITY_MANAGEMENT_JWT_KEY_STORE_PASSWORD"

CREATE_CERTS="false"

if [ -z "$POD_NAMESPACE" ]; then
    echo "POD_NAMESPACE is not set"
    exit 1
fi

# TSC_CONFIG_LOCATION is optional, if not set we continue without it by creating new certs
# We are adding it to the security-certs job as an env variable for now
if [ -z "$TSC_CONFIG_LOCATION" ]; then
    echo "TSC_CONFIG_LOCATION is not set, continuing without it"
fi

# Check if /tmp directory exists and is writable before starting execution
if [ ! -d "/tmp" ] || [ ! -w "/tmp" ]; then
    echo "/tmp directory does not exist or is not writable. Exiting."
    exit 1
fi

# Upgrade scenario handling
# Old EFS based certificate paths for upgrade case where certs are already present in the EFS location
OLD_IDM_P12="$TSC_CONFIG_LOCATION/idm/own-keystores/on-prem-idm.p12"
OLD_IDM_PEM="$TSC_CONFIG_LOCATION/default-idp/resources/certs/on-prem-idm.pem"
OLD_IDP_P12="$TSC_CONFIG_LOCATION/default-idp/resources/certs/on-prem-idp.p12"
OLD_IDP_PEM="$TSC_CONFIG_LOCATION/idm/own-keystores/on-prem-idp.pem"
OLD_JWT_P12="$TSC_CONFIG_LOCATION/idm/own-keystores/jwt.p12"

log_time_taken() {
    local start_time=$1
    local task=$2
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "$task completed in ${duration} seconds"
}

get_secret_value() {
    local secretName=$1
    local secretKey=$2
    local value

    value=$(kubectl get secret "$secretName" -n "$POD_NAMESPACE" -o jsonpath="{.data['$secretKey']}" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$value" ]; then
        echo "ERROR: Could not get value for key '$secretKey' in secret '$secretName' in namespace '$POD_NAMESPACE'"
        return 1
    fi

    decoded=$(echo "$value" | tr -d '\n\r' | base64 -d 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to decode base64 value"
        return 1
    fi

    echo "$decoded"
    return 0
}

create_secret_with_files_and_password() {
    local secretName=$1
    local passwordKey=$2
    local passwordValue=$3
    shift 3
    local files=("$@")
    local start_time=$(date +%s)
    local PATCH_DATA=""
    local yaml_path="/tmp/${secretName}.yaml"
    
    echo "Patching secret: $secretName"
    echo "Files: ${files[@]}"
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "ERROR: File $file does not exist!"
            ls -l "$file"
            return 1
        fi
    done

    # Build patch data for each file
    for file in "${files[@]}"; do
        local key=$(basename "$file")
        local value=$(base64 -w 0 "$file")
        PATCH_DATA="${PATCH_DATA}\"${key}\":\"${value}\","
    done
    PATCH_DATA="${PATCH_DATA}\"${passwordKey}\":\"$(echo -n "${passwordValue}" | base64 -w 0)\""

    # Patch the secret (create if not exists)
    kubectl get secret "$secretName" -n "$POD_NAMESPACE" >/dev/null
    if [ $? -eq 0 ]; then
        # Secret exists, patch it
        kubectl patch secret "$secretName" -n "$POD_NAMESPACE" \
            --type merge \
            -p "{\"data\":{${PATCH_DATA}}}"
        errorCode=$?
    else
        # Secret does not exist, create it
        cat <<EOF > "$yaml_path"
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: ${secretName}
  namespace: ${POD_NAMESPACE}
data:
$(for file in "${files[@]}"; do
    key=$(basename "$file")
    value=$(base64 -w 0 "$file")
    echo "  ${key}: ${value}"
done)
  ${passwordKey}: $(echo -n "${passwordValue}" | base64 -w 0)
EOF
        kubectl apply -f "$yaml_path"
        errorCode=$?
        rm -f "$yaml_path"
    fi

    log_time_taken $start_time "Secret patch (files+password) for $secretName"
    if [ $errorCode -ne 0 ]; then
        echo "Failed to patch/create secret ${secretName} in namespace '$POD_NAMESPACE'"
        return 1
    fi
}

create_secret_with_only_files() {
    local secretName=$1
    shift
    local files=("$@")
    local start_time=$(date +%s)
    local PATCH_DATA=""
    local namespace="${POD_NAMESPACE}"
    local yaml_path="/tmp/${secretName}.yaml"

    echo "Patching secret: $secretName"
    echo "Files: ${files[@]}"
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "ERROR: File $file does not exist!"
            ls -l "$file"
            return 1
        fi
    done

    # Build patch data for each file
    for file in "${files[@]}"; do
        local key=$(basename "$file")
        local value=$(base64 -w 0 "$file")
        PATCH_DATA="${PATCH_DATA}\"${key}\":\"${value}\","
    done

    # Remove trailing comma
    PATCH_DATA="${PATCH_DATA%,}"

    # Patch the secret (create if not exists)
    kubectl get secret "$secretName" -n "$namespace" >/dev/null
    if [ $? -eq 0 ]; then
        # Secret exists, patch it
        kubectl patch secret "$secretName" -n "$namespace" \
            --type merge \
            -p "{\"data\":{${PATCH_DATA}}}"
        errorCode=$?
    else
        # Secret does not exist, create it
        cat <<EOF > "$yaml_path"
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: ${secretName}
  namespace: ${namespace}
data:
$(for file in "${files[@]}"; do
    key=$(basename "$file")
    value=$(base64 -w 0 "$file")
    echo "  ${key}: ${value}"
done)
EOF
        kubectl apply -f "$yaml_path"
        errorCode=$?
        rm -f "$yaml_path"
    fi

    log_time_taken $start_time "Secret patch (files only) for $secretName"
    if [ $errorCode -ne 0 ]; then
        echo "Failed to patch/create secret ${secretName} in namespace '$POD_NAMESPACE'"
        return 1
    fi
}

# add docs 
check_if_file_exists_and_delete() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "$file exists, deleting it..."
        rm -f "$file"
    else
        echo "$file does not exist"
    fi
}

randomPassword() {
    echo "pwd.$(openssl rand -base64 33 | tr '/+' '_-')"
}

create_idm_certs() {
    local randPasswd=$1
    local location="/tmp/idm"
    local start_time=$(date +%s)
    mkdir -p "$location"
    cd "$location"
    check_if_file_exists_and_delete "idm.p12"
    openssl genrsa -out server.key 2048 || { echo "openssl genrsa failed"; exit 1; }
    openssl req -new -text -subj "/CN=identity-management" -key server.key -out server.csr || { echo "openssl req failed"; exit 1; }
    openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 3652 -sha256 || { echo "openssl x509 failed"; exit 1; }
    openssl x509 -in server.crt -out server.pem -outform PEM || { echo "openssl x509 PEM failed"; exit 1; }
    openssl pkcs12 -export -in server.crt -inkey server.key -out idm.p12 -name cic_cloud -passout pass:$randPasswd || { echo "openssl pkcs12 failed"; exit 1; }
    if [ ! -f idm.p12 ]; then
        echo "idm.p12 was not created!"
        exit 1
    fi

    cp server.pem idm.pem || { echo "cp server.pem failed"; exit 1; }

    rm server.key server.csr server.crt server.pem
    cd ..
    log_time_taken $start_time "IdM certificate generation"
}

create_idp_certs() {
    local randPasswd=$1
    local location="/tmp/idp"
    local start_time=$(date +%s)
    mkdir -p "$location"
    cd "$location"
    check_if_file_exists_and_delete "idp.p12"
    openssl genrsa -out server.key 2048
    openssl req -new -text -subj "/CN=identity-provider" -key server.key -out server.csr
    openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 3652 -sha256
    openssl x509 -in server.crt -out server.pem -outform PEM
    openssl pkcs12 -export -in server.crt -inkey server.key -out idp.p12 -name cic_cloud -passout pass:$randPasswd
    cp server.pem idp.pem
    rm server.key server.csr server.crt server.pem
    cd ..
    log_time_taken $start_time "IdP certificate generation"
}

create_jwt_cert() {
    local randPasswd=$1
    local location="/tmp/jwt"
    local start_time=$(date +%s)
    mkdir -p "$location"
    cd "$location"
    check_if_file_exists_and_delete "jwt.p12"
    openssl ecparam -genkey -name prime256v1 -out server.key
    openssl req -new -key server.key -out server.csr -subj "/CN=jwt"
    openssl req -x509 -sha256 -nodes -days 3652 -key server.key -in server.csr -out server.crt
    openssl pkcs12 -export -in server.crt -inkey server.key -out jwt.p12 -name jwt -passout pass:$randPasswd
    rm server.key server.csr server.crt
    cd ..
    log_time_taken $start_time "JWT certificate generation"
}

# Check if certificate(s) exist in secret
check_certs_in_secret() {
    local secretName=$1
    shift
    local certKeys=("$@")

    echo "Checking secret '$secretName' for keys: ${certKeys[@]}"

    # First check if secret exists
    if ! kubectl get secret "$secretName" -n "$POD_NAMESPACE" >/dev/null; then
        echo "Secret '$secretName' does not exist in namespace '$POD_NAMESPACE'"
        return 1
    fi

    for certKey in "${certKeys[@]}"; do
        # Escape dots in the key name for JSONPath
        local escapedKey="${certKey//\./\\.}"

        local cert_value=$(kubectl get secret "$secretName" -n "$POD_NAMESPACE" -o jsonpath="{.data['$escapedKey']}" 2>/dev/null)
        local kubectl_exit_code=$?
        
        if [ $kubectl_exit_code -ne 0 ] || [ -z "$cert_value" ]; then
            echo "Key '$certKey' not found or empty in secret '$secretName' in namespace '$POD_NAMESPACE'"
            return 1
        fi
    done

    echo "All keys found with valid data in secret '$secretName' in namespace '$POD_NAMESPACE'"
    return 0
}

ensure_jwt_secret() {
    local KEYSTORE_PASS=$1
    local jwtfile="$OLD_JWT_P12"
    local urlSecretName=$IDM_JWT_KEYSTORE_URL_SECRET_NAME
    local passSecretName=$IDM_JWT_KEYSTORE_SECRET_NAME

    # First check if JWT cert already exists in secret
    echo "Checking if JWT certificate exists in secret $urlSecretName"
    if check_certs_in_secret "$urlSecretName" "jwt.p12"; then
        echo "JWT certificate already exists in secret $urlSecretName, skipping generation"
        return 0
    else
        echo "JWT certificate not found in secret, checking EFS or generating new certificate"
        
    # Upgrade scenario handling
    # If old JWT keystore exists, use it and password from secret
        if [ -f "$jwtfile" ]; then
            echo "JWT keystore found in EFS, checking if keystore password exists in secret"
            jwt_keystore_pass=$(get_secret_value "$passSecretName" "$IDM_JWT_KEYSTORE_PASSWORD_KEY")
            jwt_return=$?
            if [ $jwt_return -ne 0 ] || [ -z "$jwt_keystore_pass" ]; then
                echo "Keystore password not found in secret, generating new cert and secret."
                create_jwt_cert "$KEYSTORE_PASS"
                local tmpfile="/tmp/jwt/jwt.p12"
                create_secret_with_only_files "$urlSecretName" "$tmpfile"
                jwt_keystore_secret_code=$?
                if [ $jwt_keystore_secret_code -ne 0 ]; then
                    echo "Error creating $urlSecretName secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
                create_secret_with_files_and_password "$passSecretName" "$IDM_JWT_KEYSTORE_PASSWORD_KEY" "$KEYSTORE_PASS"
                jwt_password_secret_code=$?
                if [ $jwt_password_secret_code -ne 0 ]; then
                    echo "Error creating $passSecretName secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
            else
                echo "Keystore password found in secret, cert file already present. No need to recreate secret with password."
                cp "$jwtfile" "jwt.p12"
                create_secret_with_only_files "$urlSecretName" "jwt.p12"
                jwt_keystore_secret_code=$?
                if [ $jwt_keystore_secret_code -ne 0 ]; then
                    echo "Error creating $urlSecretName secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
            fi
        else
            echo "JWT keystore not found, generating new cert and secret."
            create_jwt_cert "$KEYSTORE_PASS"
            local tmpfile="/tmp/jwt/jwt.p12"
            create_secret_with_only_files "$urlSecretName" "$tmpfile"
            jwt_keystore_secret_code=$?
            if [ $jwt_keystore_secret_code -ne 0 ]; then
                echo "Error creating $urlSecretName secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
            create_secret_with_files_and_password "$passSecretName" "$IDM_JWT_KEYSTORE_PASSWORD_KEY" "$KEYSTORE_PASS"
            jwt_password_secret_code=$?
            if [ $jwt_password_secret_code -ne 0 ]; then
                echo "Error creating $passSecretName secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
        fi
    fi
}

ensure_idm_secret() {
    local KEYSTORE_PASS=$1
    local idm_p12="$OLD_IDM_P12"
    local idp_pem="$OLD_IDP_PEM"
    local sp_secret_name=$IDM_SP_KEYSTORE_SECRET_NAME
    local idpSecretName=$IDP_KEYSTORE_SECRET_NAME
    local sp_password_key="IDENTITY_MANAGEMENT_SP_KEY_STORE_PASSWORD"
    local client_id_secret_name=$IDM_CLIENT_ID_SECRET_KEY_SECRET_NAME
    local client_id_password_key="IDENTITY_MANAGEMENT_CLIENT_ID_SECRET_KEY"
    local urlSecretName=$IDM_JWT_KEYSTORE_URL_SECRET_NAME

    # First check if IdM certs already exist in secrets
    echo "Checking if IdM certificates exist in secret $sp_secret_name"
    if check_certs_in_secret "$sp_secret_name" "idm.p12" "idp.pem"; then
        # Check if JWT cert also exists
        if check_certs_in_secret "$urlSecretName" "jwt.p12"; then
            echo "IdM and JWT certificates already exist in secrets, skipping generation"
            return 0
        else
            echo "IdM certificates exist but JWT missing, ensuring JWT secret"
            ensure_jwt_secret "$KEYSTORE_PASS"
            return 0
        fi
    else
        echo "IdM certificates not found in secrets, checking EFS or generating new certificates"

        if [ -f "$idm_p12" ] && [ -f "$idp_pem" ]; then
            echo "IdM keystore and PEM found in EFS, checking if keystore passwords exist in secrets"
            sp_keystore_pass=$(get_secret_value "$sp_secret_name" "$sp_password_key")
            sp_keystore_pass_return=$?
            client_id_pass=$(get_secret_value "$client_id_secret_name" "$client_id_password_key")
            client_id_pass_return=$?
            if [ $sp_keystore_pass_return -ne 0 ] || [ -z "$sp_keystore_pass" ] || [ $client_id_pass_return -ne 0 ] || [ -z "$client_id_pass" ]; then
                echo "One or both keystore passwords not found in secrets, generating new certs and secrets."
                create_idm_certs "$KEYSTORE_PASS"
                local tmp_p12="/tmp/idm/idm.p12"
                local tmp_pem="/tmp/idm/idm.pem"
                create_secret_with_files_and_password "$sp_secret_name" "$sp_password_key" "$KEYSTORE_PASS" "$tmp_p12"
                sp_secret_code=$?
                if [ $sp_secret_code -ne 0 ]; then
                    echo "Error creating $sp_secret_name secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
                create_secret_with_only_files "$idpSecretName" "$tmp_pem"
                idp_secret_code=$?
                if [ $idp_secret_code -ne 0 ]; then
                    echo "Error updating $idpSecretName secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
                create_secret_with_files_and_password "$client_id_secret_name" "$client_id_password_key" "$KEYSTORE_PASS"
                client_id_secret_code=$?
                if [ $client_id_secret_code -ne 0 ]; then
                    echo "Error creating $client_id_secret_name secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
            else
                echo "Both keystore passwords found in secrets, cert files already present in EFS, create secrets and store them"
                cp "$idm_p12" "idm.p12"
                cp "$idp_pem" "idp.pem"
                create_secret_with_files_and_password "$sp_secret_name" "$sp_password_key" "$sp_keystore_pass" "idm.p12" "idp.pem" # gitleaks:allow
                sp_secret_code=$?
                if [ $sp_secret_code -ne 0 ]; then
                    echo "Error creating $sp_secret_name secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
                create_secret_with_files_and_password "$client_id_secret_name" "$client_id_password_key" "$client_id_pass"
                client_id_secret_code=$?
                if [ $client_id_secret_code -ne 0 ]; then
                    echo "Error creating $client_id_secret_name secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
            fi
            ensure_jwt_secret "$KEYSTORE_PASS"
        else
            echo "IdM keystore/PEM not found, generating new certs and secrets."
            create_idm_certs "$KEYSTORE_PASS"
            local tmp_p12="/tmp/idm/idm.p12"
            local tmp_pem="/tmp/idm/idm.pem"
            create_secret_with_files_and_password "$sp_secret_name" "$sp_password_key" "$KEYSTORE_PASS" "$tmp_p12"
            sp_secret_code=$?
            if [ $sp_secret_code -ne 0 ]; then
                echo "Error creating $sp_secret_name secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
            create_secret_with_only_files "$idpSecretName" "$tmp_pem"
            idp_secret_code=$?
            if [ $idp_secret_code -ne 0 ]; then
                echo "Error updating $idpSecretName secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
            create_secret_with_files_and_password "$client_id_secret_name" "$client_id_password_key" "$KEYSTORE_PASS"
            client_id_secret_code=$?
            if [ $client_id_secret_code -ne 0 ]; then
                echo "Error creating $client_id_secret_name secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
            ensure_jwt_secret "$KEYSTORE_PASS"
        fi
    fi
}

ensure_idp_secret() {
    local KEYSTORE_PASS=$1
    local idp_p12="$OLD_IDP_P12"
    local idm_pem="$OLD_IDM_PEM"
    local idpSecretName=$IDP_KEYSTORE_SECRET_NAME
    local idpPasswordKey=$IDP_SECRET_KEY
    local sp_secret_name=$IDM_SP_KEYSTORE_SECRET_NAME

    # First check if IdP certs already exist in secrets
    echo "Checking if IdP certificates exist in secret $idpSecretName"
    if check_certs_in_secret "$idpSecretName" "idp.p12" "idm.pem"; then
        echo "IdP certificates already exist in secrets, skipping generation"
        return 0
    else
        echo "IdP certificates not found in secrets, checking EFS or generating new certificates"
        
        if [ -f "$idp_p12" ] && [ -f "$idm_pem" ]; then
            echo "IdP keystore and PEM found in EFS, checking if keystore password exists in secret"
            idp_keystore_pass=$(get_secret_value "$idpSecretName" "$idpPasswordKey")
            idp_keystore_pass_return=$?
            if [ $idp_keystore_pass_return -ne 0 ] || [ -z "$idp_keystore_pass" ]; then
                echo "Keystore password not found in secret, generating new certs and secret."
                create_idp_certs "$KEYSTORE_PASS"
                local tmp_p12="/tmp/idp/idp.p12"
                local tmp_pem="/tmp/idp/idp.pem"
                create_secret_with_files_and_password "$idpSecretName" "$idpPasswordKey" "$KEYSTORE_PASS" "$tmp_p12"
                idp_secret_code=$?
                if [ $idp_secret_code -ne 0 ]; then
                    echo "Error creating $idpSecretName secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
                create_secret_with_only_files "$sp_secret_name" "$tmp_pem"
                sp_secret_code=$?
                if [ $sp_secret_code -ne 0 ]; then
                    echo "Error updating $sp_secret_name secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
            else
                echo "Keystore password found in secret, cert files already present. No need to recreate secret with password."
                cp "$idp_p12" "idp.p12"
                cp "$idm_pem" "idm.pem"
                create_secret_with_files_and_password "$idpSecretName" "$idpPasswordKey" "$idp_keystore_pass" "idp.p12" "idm.pem" # gitleaks:allow
                idp_secret_code=$?
                if [ $idp_secret_code -ne 0 ]; then
                    echo "Error creating $idpSecretName secret in namespace '$POD_NAMESPACE'"
                    exit 1
                fi
            fi
        else
            echo "IdP keystore/PEM not found, generating new certs and secrets."
            create_idp_certs "$KEYSTORE_PASS"
            local tmp_p12="/tmp/idp/idp.p12"
            local tmp_pem="/tmp/idp/idp.pem"
            create_secret_with_files_and_password "$idpSecretName" "$idpPasswordKey" "$KEYSTORE_PASS" "$tmp_p12"
            idp_secret_code=$?
            if [ $idp_secret_code -ne 0 ]; then
                echo "Error creating $idpSecretName secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
            create_secret_with_only_files "$sp_secret_name" "$tmp_pem"
            sp_secret_code=$?
            if [ $sp_secret_code -ne 0 ]; then
                echo "Error updating $sp_secret_name secret in namespace '$POD_NAMESPACE'"
                exit 1
            fi
        fi
    fi
}

script_start_time=$(date +%s)

case $inputCommand in
    idm)
        echo ""
        echo "=== Starting IdM Certificate Processing ==="
        randPasswd=$(randomPassword)
        ensure_idm_secret "$randPasswd"
        echo "=== IdM Certificate Processing Complete ==="
        echo ""
        ;;
    idp)
        echo ""
        echo "=== Starting IdP Certificate Processing ==="
        randPasswd=$(randomPassword)
        ensure_idp_secret "$randPasswd"
        echo "=== IdP Certificate Processing Complete ==="
        echo ""
        ;;
    *)
        echo "$inputCommand is not a valid command"
        echo "Usage: ./generate-self-signed-cert.sh idp|idm"
        exit 1
        ;;
esac

# Cleanup cert directories and log time taken
start_cleanup=$(date +%s)
echo "Cleaning up temporary directories and files..."
[ -d /tmp/idm ] && rm -rf /tmp/idm
[ -d /tmp/idp ] && rm -rf /tmp/idp
[ -d /tmp/jwt ] && rm -rf /tmp/jwt
# delete copied over files in current directory
[ -f idp.p12 ] && rm -f idp.p12
[ -f idp.pem ] && rm -f idp.pem
[ -f idm.p12 ] && rm -f idm.p12
[ -f idm.pem ] && rm -f idm.pem
[ -f jwt.p12 ] && rm -f jwt.p12
log_time_taken $start_cleanup "Cleanup of temporary directories and files"

log_time_taken $script_start_time "Total script execution time"
echo "============================================================================="