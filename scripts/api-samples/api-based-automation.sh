#!/usr/bin/env bash
#
# Copyright (c) 2026 TIBCO Software Inc.
# All Rights Reserved. Confidential & Proprietary.
#
# api-based-automation.sh
#
# DISCLAIMER:
# THIS SAMPLE IS NOT INTENDED FOR PRODUCTION USE AS-IS.
# Customers are solely responsible for thoroughly reviewing, testing, securing,
# and modifying this code to fit their specific operational environments and requirements
# prior to deployment.
#
# Automates TIBCO Platform provisioning end-to-end with IdP configuration:
#   1. Initialize the Platform Console (ADMIN subscription)
#   2. Register an OAuth2 client for the ADMIN subscription
#   3. Revoke the ADMIN IAT (Initial Access Token)
#   4. Exchange client credentials for an ADMIN access token
#   5. (Manual) Generate a self-signed certificate if needed before providing --idp-config
#   6. Configure external IdP (skipped if --idp-config not provided)
#   7. Create a CP subscription and verify its details
#   8. Register an OAuth2 client for the CP subscription
#   9. Exchange client credentials for a CP access token and verify
#
# Usage:
#   ./api-based-automation.sh --base-url <URL> --admin-email <EMAIL> --admin-initial-password <PASSWORD> [OPTIONS]
#
# See --help for full usage details.
#


set -euo pipefail


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly DIVIDER="================================================================"


# ---------------------------------------------------------------------------
# Color helpers (disabled when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${RESET}  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${RESET} $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
log_step()  { echo -e "\n${CYAN}${BOLD}>> $*${RESET}"; }
log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
    fi
}


# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<USAGE
${BOLD}NAME${RESET}
    ${SCRIPT_NAME} - Automate TIBCO Platform provisioning with IdP configuration


${BOLD}SYNOPSIS${RESET}
    ${SCRIPT_NAME} --base-url <URL> --admin-email <EMAIL> --admin-initial-password <PASSWORD> [OPTIONS]


${BOLD}REQUIRED${RESET}
    --base-url <URL>            Platform Console base URL
                                (env: CP_BASE_URL)
    --admin-email <EMAIL>       Admin email for basic auth
                                (env: CP_ADMIN_EMAIL)
    --admin-initial-password <PASSWORD> Admin initial password for basic auth
                                (env: CP_ADMIN_INITIAL_PASSWORD)


${BOLD}OPTIONS${RESET}
    --admin-first-name <NAME>   Admin first name (env: CP_ADMIN_FIRST_NAME, default: Admin)
    --admin-last-name <NAME>    Admin last name  (env: CP_ADMIN_LAST_NAME, default: User)
    --admin-host-prefix <PREFIX> Admin host prefix (env: CP_ADMIN_HOST_PREFIX, default: admin)
    --cp-email <EMAIL>          CP subscription owner email
                                (env: CP_SUB_EMAIL, default: same as admin-email)
    --cp-initial-password <PASSWORD>    CP subscription owner initial password
                                (env: CP_SUB_INITIAL_PASSWORD, default: changeMe@1)
    --cp-first-name <NAME>      CP owner first name  (env: CP_FIRST_NAME, default: Admin)
    --cp-last-name <NAME>       CP owner last name   (env: CP_LAST_NAME, default: User)
    --cp-company <NAME>         Company name (env: CP_COMPANY, default: acme)
    --cp-host-prefix <PREFIX>   Host prefix  (env: CP_HOST_PREFIX, default: acme)
    --idp-config <JSON>         External IdP configuration body as JSON string
                                (env: CP_IDP_CONFIG). If not provided, IdP steps are skipped
    --curl-timeout <SECONDS>    Curl timeout (env: CP_CURL_TIMEOUT, default: 30)
    --verbose                   Enable debug output
    --help                      Show this help message


${BOLD}EXAMPLES${RESET}
    # Minimal invocation
    ${SCRIPT_NAME} \\
        --base-url https://admin.cp1-my.example.com \\
        --admin-email admin@example.com \\
        --admin-initial-password 's3cret!'


    # Using environment variables
    export CP_BASE_URL=https://admin.cp1-my.example.com
    export CP_ADMIN_EMAIL=admin@example.com
    export CP_ADMIN_INITIAL_PASSWORD='s3cret!'
    ${SCRIPT_NAME}


    # Full customization
    ${SCRIPT_NAME} \\
        --base-url https://admin.cp1-my.example.com \\
        --admin-email admin@example.com \\
        --admin-initial-password 's3cret!' \\
        --cp-email owner@example.com \\
        --cp-initial-password 'Own3rP@ss' \\
        --cp-first-name Jane \\
        --cp-last-name Doe \\
        --cp-company Acme \\
        --cp-host-prefix acme \\
        --verbose


USAGE
    exit "${1:-0}"
}


# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
    local missing=()
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Install them before running this script."
        exit 1
    fi
}


# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
RESPONSE_FILE=""
cleanup() {
    if [[ -n "$RESPONSE_FILE" && -f "$RESPONSE_FILE" ]]; then
        rm -f "$RESPONSE_FILE"
        log_debug "Cleaned up temporary file: $RESPONSE_FILE"
    fi
}
trap cleanup EXIT INT TERM


# ---------------------------------------------------------------------------
# HTTP helper — performs a curl request, checks status, returns body
#   do_request <step_label> <method> <url> [curl_args...]
# ---------------------------------------------------------------------------
do_request() {
    local step_label="$1"; shift
    local method="$1"; shift
    local url="$1"; shift


    log_debug "curl -X $method $url [additional arguments redacted]"


    local http_status
    http_status=$(curl -sS -w "%{http_code}" -o "$RESPONSE_FILE" \
        --max-time "${CURL_TIMEOUT}" \
        -X "$method" "$url" "$@")


    local body
    body=$(<"$RESPONSE_FILE")


    if [[ ! "$http_status" =~ ^2[0-9]{2}$ ]]; then
        log_error "$step_label failed (HTTP $http_status)"
        echo "$DIVIDER"
        echo "Response Body:"
        echo "$body" | jq . 2>/dev/null || echo "$body"
        echo "$DIVIDER"
        exit 1
    fi


    log_debug "$step_label succeeded (HTTP $http_status)"
    echo "$body"
}


# ---------------------------------------------------------------------------
# Pretty-print a JSON response to the console
# ---------------------------------------------------------------------------
print_response() {
    local label="$1"
    local json="$2"
    echo "$DIVIDER"
    log_info "$label"
    echo "$json" | jq . 2>/dev/null || echo "$json"
    echo "$DIVIDER"
}


# ---------------------------------------------------------------------------
# Extract a field from JSON, abort if missing/null
# ---------------------------------------------------------------------------
extract_field() {
    local json="$1"
    local field="$2"
    local label="${3:-$field}"


    local value
    value=$(echo "$json" | jq -r "$field")


    if [[ -z "$value" || "$value" == "null" ]]; then
        log_error "Failed to extract '$label' from response"
        log_debug "Response was: $json"
        exit 1
    fi
    echo "$value"
}


# ---------------------------------------------------------------------------
# Argument parsing (CLI flags override env vars)
# ---------------------------------------------------------------------------
parse_args() {
    # Defaults from environment variables
    BASE_URL="${CP_BASE_URL:-}"
    ADMIN_EMAIL="${CP_ADMIN_EMAIL:-}"
    ADMIN_PASSWORD="${CP_ADMIN_INITIAL_PASSWORD:-}"
    ADMIN_FIRST_NAME="${CP_ADMIN_FIRST_NAME:-Admin}"
    ADMIN_LAST_NAME="${CP_ADMIN_LAST_NAME:-User}"
    ADMIN_HOST_PREFIX="${CP_ADMIN_HOST_PREFIX:-admin}"
    SUB_EMAIL="${CP_SUB_EMAIL:-}"
    SUB_PASSWORD="${CP_SUB_INITIAL_PASSWORD:-changeMe@1}"
    FIRST_NAME="${CP_FIRST_NAME:-Admin}"
    LAST_NAME="${CP_LAST_NAME:-User}"
    COMPANY="${CP_COMPANY:-acme}"
    HOST_PREFIX="${CP_HOST_PREFIX:-acme}"
    IDP_CONFIG="${CP_IDP_CONFIG:-}"
    CURL_TIMEOUT="${CP_CURL_TIMEOUT:-30}"
    VERBOSE="${VERBOSE:-false}"


    require_arg() {
        if [[ "$1" -lt 2 ]]; then
            log_error "Option $2 requires an argument"
            usage 1
        fi
    }


    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-url)          require_arg $# "$1"; BASE_URL="$2"; shift 2 ;;
            --admin-email)       require_arg $# "$1"; ADMIN_EMAIL="$2"; shift 2 ;;
            --admin-initial-password)    require_arg $# "$1"; ADMIN_PASSWORD="$2"; shift 2 ;;
            --admin-first-name)  require_arg $# "$1"; ADMIN_FIRST_NAME="$2"; shift 2 ;;
            --admin-last-name)   require_arg $# "$1"; ADMIN_LAST_NAME="$2"; shift 2 ;;
            --admin-host-prefix) require_arg $# "$1"; ADMIN_HOST_PREFIX="$2"; shift 2 ;;
            --cp-email)          require_arg $# "$1"; SUB_EMAIL="$2"; shift 2 ;;
            --cp-initial-password)       require_arg $# "$1"; SUB_PASSWORD="$2"; shift 2 ;;
            --cp-first-name)     require_arg $# "$1"; FIRST_NAME="$2"; shift 2 ;;
            --cp-last-name)      require_arg $# "$1"; LAST_NAME="$2"; shift 2 ;;
            --cp-company)        require_arg $# "$1"; COMPANY="$2"; shift 2 ;;
            --cp-host-prefix)    require_arg $# "$1"; HOST_PREFIX="$2"; shift 2 ;;
            --idp-config)        require_arg $# "$1"; IDP_CONFIG="$2"; shift 2 ;;
            --curl-timeout)      require_arg $# "$1"; CURL_TIMEOUT="$2"; shift 2 ;;
            --verbose)           VERBOSE=true; shift ;;
            --help|-h)           usage 0 ;;
            *)
                log_error "Unknown option: $1"
                usage 1
                ;;
        esac
    done


    # Validation
    local errors=()
    [[ -z "$BASE_URL" ]]       && errors+=("--base-url (or CP_BASE_URL) is required")
    [[ -z "$ADMIN_EMAIL" ]]    && errors+=("--admin-email (or CP_ADMIN_EMAIL) is required")
    [[ -z "$ADMIN_PASSWORD" ]] && errors+=("--admin-initial-password (or CP_ADMIN_INITIAL_PASSWORD) is required")


    if [[ ${#errors[@]} -gt 0 ]]; then
        for err in "${errors[@]}"; do
            log_error "$err"
        done
        echo ""
        usage 1
    fi


    # Default subscription email to admin email
    SUB_EMAIL="${SUB_EMAIL:-$ADMIN_EMAIL}"


    # Strip trailing slash from BASE_URL
    BASE_URL="${BASE_URL%/}"
}


# ===========================================================================
# Main workflow
# ===========================================================================
main() {
    parse_args "$@"
    check_dependencies


    RESPONSE_FILE=$(mktemp)
    log_debug "Temporary response file: $RESPONSE_FILE"


    # ------------------------------------------------------------------
    # Step 1: Initialize Platform Console
    # ------------------------------------------------------------------
    log_step "Step 1/9: Initializing Platform Console"


    local init_body
    init_body=$(jq -n \
        --arg email "$ADMIN_EMAIL" \
        --arg firstName "$ADMIN_FIRST_NAME" \
        --arg lastName "$ADMIN_LAST_NAME" \
        --arg hostPrefix "$ADMIN_HOST_PREFIX" \
        '{
            externalAccountId: "admin",
            externalSubscriptionId: "admin-sub",
            firstName: $firstName,
            lastName: $lastName,
            email: $email,
            organizationName: "TSC Admin Subscription",
            hostPrefix: $hostPrefix,
            prefixId: "tibc",
            generateIAT: true,
            tenantSubscriptionDetails: [
                {
                    eula: true,
                    region: "global",
                    expiryInMonths: -1,
                    planId: "TIB_CLD_ADMIN_TIB_CLOUDOPS",
                    tenantId: "ADMIN",
                    seats: {
                        ADMIN: { ENGR: -1, PM: -1, SUPT: -1, OPS: -1, PROV: -1, TSUPT: -1 }
                    }
                }
            ],
            skipEmail: false
        }')


    local init_response
    init_response=$(do_request "Init Platform Console" POST \
        "$BASE_URL/platform-console/api/v1/init" \
        -H "Content-Type: application/json" \
        -u "$ADMIN_EMAIL:$ADMIN_PASSWORD" \
        -d "$init_body")


    local admin_iat account_id
    admin_iat=$(extract_field "$init_response" '.iat.accessToken' "Admin IAT")
    account_id=$(extract_field "$init_response" '.accountId' "Account ID")
    log_info "Platform Console initialized (accountId: $account_id)"


    # ------------------------------------------------------------------
    # Step 2: Register OAuth2 client for ADMIN subscription
    # ------------------------------------------------------------------
    log_step "Step 2/9: Registering OAuth2 client for ADMIN subscription"


    local admin_client_response
    admin_client_response=$(do_request "Register Admin OAuth2 Client" POST \
        "$BASE_URL/idm/v1/oauth2/clients" \
        -H "Authorization: Bearer $admin_iat" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_name=admin-client&scope=ADMIN&token_endpoint_auth_method=client_secret_basic")


    local admin_client_id admin_client_secret
    admin_client_id=$(extract_field "$admin_client_response" '.client_id' "Admin Client ID")
    admin_client_secret=$(extract_field "$admin_client_response" '.client_secret' "Admin Client Secret")
    log_info "Admin OAuth2 client registered (client_id: $admin_client_id)"


    # ------------------------------------------------------------------
    # Step 3: Revoke ADMIN IAT
    # ------------------------------------------------------------------
    log_step "Step 3/9: Revoking ADMIN IAT"


    local revoke_admin_response
    revoke_admin_response=$(do_request "Revoke Admin IAT" DELETE \
        "$BASE_URL/idm/v1/oauth2/clients/initial-token" \
        -H "Authorization: Bearer $admin_iat")
    print_response "Admin IAT revoke response" "$revoke_admin_response"


    # ------------------------------------------------------------------
    # Step 4: Get ADMIN access token via client credentials
    # ------------------------------------------------------------------
    log_step "Step 4/9: Obtaining ADMIN access token"


    local admin_token_response
    admin_token_response=$(do_request "Admin Token Exchange" POST \
        "$BASE_URL/idm/v1/oauth2/token" \
        -u "$admin_client_id:$admin_client_secret" \
        -d "grant_type=client_credentials&scope=ADMIN")


    local admin_access_token
    admin_access_token=$(extract_field "$admin_token_response" '.access_token' "Admin Access Token")
    log_info "ADMIN access token obtained"


    # Verify via /whoami
    log_info "Verifying ADMIN access token via /whoami..."
    local admin_whoami_response
    admin_whoami_response=$(do_request "Verify ADMIN Token" GET \
        "$BASE_URL/admin/v1/whoami" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $admin_access_token")
    print_response "ADMIN /whoami response" "$admin_whoami_response"


    # ------------------------------------------------------------------
    # Step 5: Generate self-signed certificate
    # Step 6: Configure external IdP
    # (Both steps require --idp-config; skipped if not provided)
    # ------------------------------------------------------------------
    if [[ -n "$IDP_CONFIG" ]]; then
        log_step "Step 5/9: Generate self-signed certificate"
        log_warn "Skipped — use the generate SP certificate API separately if needed"


        log_step "Step 6/9: Configuring external IdP"


        local idp_response
        idp_response=$(do_request "Configure External IdP" POST \
            "$BASE_URL/platform-console/api/v1/idps/$ADMIN_HOST_PREFIX" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $admin_access_token" \
            -d "$IDP_CONFIG")
        print_response "IdP configuration response" "$idp_response"


        # Verify subscription details
        log_info "Fetching ADMIN subscription details..."
        local admin_sub_response
        admin_sub_response=$(do_request "Get ADMIN Subscription Details" GET \
            "$BASE_URL/platform-console/api/v1/subscriptions?hostPrefix=$ADMIN_HOST_PREFIX" \
            -H "Authorization: Bearer $admin_access_token" \
            -H "Content-Type: application/json")
        print_response "ADMIN subscription details" "$admin_sub_response"


        # Verify IdP details
        log_info "Fetching ADMIN IdP details..."
        local admin_idp_response
        admin_idp_response=$(do_request "Get ADMIN IdP Details" GET \
            "$BASE_URL/platform-console/api/v1/idps/$ADMIN_HOST_PREFIX" \
            -H "Authorization: Bearer $admin_access_token" \
            -H "Content-Type: application/json")
        print_response "ADMIN IdP details" "$admin_idp_response"
    else
        log_step "Step 5/9: Generate self-signed certificate"
        log_warn "Skipped — no --idp-config provided, IdP configuration is skipped"


        log_step "Step 6/9: Configure external IdP"
        log_warn "Skipped — no --idp-config provided, pass --idp-config '<JSON>' to configure IdP"
    fi


    # ------------------------------------------------------------------
    # Step 7: Create CP subscription
    # ------------------------------------------------------------------
    log_step "Step 7/9: Creating CP subscription"


    local copy_idp=false
    if [[ -n "$IDP_CONFIG" ]]; then
        copy_idp=true
    fi


    local cp_sub_body
    cp_sub_body=$(jq -n \
        --arg firstName "$FIRST_NAME" \
        --arg lastName "$LAST_NAME" \
        --arg email "$SUB_EMAIL" \
        --arg password "$SUB_PASSWORD" \
        --arg company "$COMPANY" \
        --arg hostPrefix "$HOST_PREFIX" \
        --argjson copyAdminIdP "$copy_idp" \
        '{
            userDetails: {
                firstName: $firstName,
                lastName: $lastName,
                email: $email,
                initialPassword: $password,
                country: "US",
                state: "NC"
            },
            accountDetails: {
                companyName: $company,
                ownerLimit: 10,
                hostPrefix: $hostPrefix,
                comment: "Provisioned via automation"
            },
            generateIAT: true,
            copyAdminIdP: $copyAdminIdP,
            userRoles: ["*"],
            useDefaultIDP: true,
            customContainerRegistry: false
        }')


    local sub_response
    sub_response=$(do_request "Create CP Subscription" POST \
        "$BASE_URL/platform-console/api/v1/subscriptions" \
        -H "Authorization: Bearer $admin_access_token" \
        -H "Content-Type: application/json" \
        -d "$cp_sub_body")


    local cp_base_url cp_iat
    cp_base_url=$(extract_field "$sub_response" '.response.details.provisioningDetails.subscriptionUrl' "CP Subscription URL")
    cp_iat=$(extract_field "$sub_response" '.response.iat.accessToken' "CP IAT")
    log_info "CP subscription created (URL: $cp_base_url)"


    # Verify CP subscription details
    log_info "Fetching CP subscription details..."
    local cp_sub_details
    cp_sub_details=$(do_request "Get CP Subscription Details" GET \
        "$BASE_URL/platform-console/api/v1/subscriptions?hostPrefix=$HOST_PREFIX" \
        -H "Authorization: Bearer $admin_access_token" \
        -H "Content-Type: application/json")
    print_response "CP subscription details" "$cp_sub_details"


    # Verify CP IdP details (only if IdP was configured)
    if [[ -n "$IDP_CONFIG" ]]; then
        log_info "Fetching CP IdP details..."
        local cp_idp_details
        cp_idp_details=$(do_request "Get CP IdP Details" GET \
            "$BASE_URL/platform-console/api/v1/idps/$HOST_PREFIX" \
            -H "Authorization: Bearer $admin_access_token" \
            -H "Content-Type: application/json")
        print_response "CP IdP details" "$cp_idp_details"
    else
        log_info "Skipping CP IdP verification — no IdP was configured"
    fi


    # ------------------------------------------------------------------
    # Step 8: Register OAuth2 client for CP subscription
    # ------------------------------------------------------------------
    log_step "Step 8/9: Registering OAuth2 client for CP subscription"


    local cp_client_response
    cp_client_response=$(do_request "Register CP OAuth2 Client" POST \
        "https://$cp_base_url/idm/v1/oauth2/clients" \
        -H "Authorization: Bearer $cp_iat" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_name=cp-client&scope=TSC&token_endpoint_auth_method=client_secret_basic")


    local cp_client_id cp_client_secret
    cp_client_id=$(extract_field "$cp_client_response" '.client_id' "CP Client ID")
    cp_client_secret=$(extract_field "$cp_client_response" '.client_secret' "CP Client Secret")
    log_info "CP OAuth2 client registered (client_id: $cp_client_id)"


    # Revoke CP IAT
    log_info "Revoking CP IAT..."
    local revoke_cp_response
    revoke_cp_response=$(do_request "Revoke CP IAT" DELETE \
        "https://$cp_base_url/idm/v1/oauth2/clients/initial-token" \
        -H "Authorization: Bearer $cp_iat")
    print_response "CP IAT revoke response" "$revoke_cp_response"


    # ------------------------------------------------------------------
    # Step 9: Get CP access token and verify
    # ------------------------------------------------------------------
    log_step "Step 9/9: Obtaining and verifying CP access token"


    local cp_token_response
    cp_token_response=$(do_request "CP Token Exchange" POST \
        "https://$cp_base_url/idm/v1/oauth2/token" \
        -u "$cp_client_id:$cp_client_secret" \
        -d "grant_type=client_credentials&scope=TSC")


    local cp_access_token
    cp_access_token=$(extract_field "$cp_token_response" '.access_token' "CP Access Token")
    log_info "CP access token obtained"


    # Verify via /whoami
    log_info "Verifying CP access token via /whoami..."
    local cp_whoami_response
    cp_whoami_response=$(do_request "Verify CP Token" GET \
        "https://$cp_base_url/cp/v1/whoami" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $cp_access_token")
    print_response "CP /whoami response" "$cp_whoami_response"


    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    echo ""
    echo "$DIVIDER"
    echo -e "${GREEN}${BOLD}PROVISIONING COMPLETE${RESET}"
    echo "$DIVIDER"
    echo ""
    echo -e "${BOLD}ADMIN Subscription${RESET}"
    echo "  BASE_URL      : $BASE_URL"
    echo "  CLIENT_ID     : $admin_client_id"
    echo "  CLIENT_SECRET : $admin_client_secret"
    echo "  ACCESS_TOKEN  : $admin_access_token"
    echo ""
    echo "  Token expires in 8 hours. Regenerate with:"
    echo ""
    echo "    curl -s -X POST '$BASE_URL/idm/v1/oauth2/token' \\"
    echo "         -u '$admin_client_id:$admin_client_secret' \\"
    echo "         -d 'grant_type=client_credentials&scope=ADMIN'"
    echo ""
    echo "$DIVIDER"
    echo ""
    echo -e "${BOLD}CP Subscription${RESET}"
    echo "  BASE_URL      : https://$cp_base_url"
    echo "  CLIENT_ID     : $cp_client_id"
    echo "  CLIENT_SECRET : $cp_client_secret"
    echo "  ACCESS_TOKEN  : $cp_access_token"
    echo ""
    echo "  Token expires in 8 hours. Regenerate with:"
    echo ""
    echo "    curl -s -X POST 'https://$cp_base_url/idm/v1/oauth2/token' \\"
    echo "         -u '$cp_client_id:$cp_client_secret' \\"
    echo "         -d 'grant_type=client_credentials&scope=TSC'"
    echo ""
    echo "$DIVIDER"
    echo ""
    echo -e "${BOLD}External IdP Configuration${RESET}"
    echo ""
    echo "  1. Generate a self-signed SP certificate:"
    echo ""
    echo "    curl -s -X POST '$BASE_URL/platform-console/api/v1/idps/sp-certs/generate' \\"
    echo "         -H 'Content-Type: application/json' \\"
    echo "         -H 'Authorization: Bearer <ADMIN_ACCESS_TOKEN>' \\"
    echo "         -d '{\"expiryTime\": <EPOCH>, \"hostPrefix\": \"$ADMIN_HOST_PREFIX\"}'"
    echo ""
    echo "  2. Configure external IdP (pass as --idp-config or call directly):"
    echo ""
    echo "    curl -s -X POST '$BASE_URL/platform-console/api/v1/idps/$ADMIN_HOST_PREFIX' \\"
    echo "         -H 'Content-Type: application/json' \\"
    echo "         -H 'Authorization: Bearer <ADMIN_ACCESS_TOKEN>' \\"
    echo "         -d '<IDP_CONFIG_JSON>'"
    echo ""
    echo "  Sample --idp-config JSON:"
    echo ""
    cat <<'IDP_SAMPLE'
    {
      "type": "SAML",
      "accountId": "<accountId>",
      "status": "CONFIGURED",
      "metadataURL": "",
      "metadataDetails": "",
      "knownGroups": ["<group-name>"],
      "comment": "<comment>",
      "metadata": {
        "isSAMLRequestSigned": true,
        "isSAMLAssertionEncrypted": false,
        "signatureAlgorithmToUse": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
        "spId": "<saml-sp-entity-id>",
        "idpId": "<saml-idp-id>",
        "loginUrl": "<saml-sso-url>",
        "loginBinding": "POST",
        "logoutUrl": "",
        "logoutBinding": "",
        "trustedCertsPem": ["<base64-encoded-idp-certificate>"],
        "serviceProviderCerts": [{"alias": "<cert-alias>", "active": true}],
        "attributeMappings": {
          "email": "email",
          "firstName": "firstName",
          "lastName": "lastName",
          "subject": "subject"
        }
      }
    }
IDP_SAMPLE
    echo ""
    echo "$DIVIDER"
}


main "$@"
