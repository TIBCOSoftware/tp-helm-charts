#!/usr/bin/env bash
#
# Copyright (c) 2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
#
#
# phase2-user-management.sh
#
# Sample script for TIBCO Control Plane Phase 2 public APIs:
#   User management:      invite, update permissions, delete
#   Teams CRUD:           create, list, get, update, delete, get permissions
#   Permission management: groups, teams
#
# Prerequisites:
#   - A provisioned Control Plane subscription with an OAuth2 client configured
#   - A valid CP OAuth2 access token (obtained via client credentials flow)
#
# Usage:
#   ./phase2-user-management.sh --cp-url <URL> --cp-token <TOKEN> [--op <operation>] [OPTIONS]
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
    ${SCRIPT_NAME} - Sample script for TIBCO Control Plane Phase 2 APIs: user management, teams, and permissions


${BOLD}SYNOPSIS${RESET}
    ${SCRIPT_NAME} --cp-url <URL> --cp-token <TOKEN> [--op <operation>] [OPTIONS]


${BOLD}REQUIRED${RESET}
    --cp-url <URL>              CP subscription base URL (e.g., https://acme.cp1-my.example.com)
                                (env: CP_SUB_URL)
    --cp-token <TOKEN>          CP OAuth2 access token
                                (env: CP_ACCESS_TOKEN)

${BOLD}OPERATION${RESET}
    --op <operation>            Operation to perform (default: invite)
                                See OPERATIONS section below.

${BOLD}USER MANAGEMENT OPTIONS${RESET}  (--op invite | delete | update-user-perms)
    --invite-email <EMAIL>      Email of the user to invite or look up
                                (env: CP_INVITE_EMAIL)
    --user-id <ID>              User entity ID — skip invite, use directly for update or delete
                                (env: CP_USER_ID)
    --permissions <JSON>        JSON array of permission objects for the invited user
                                (env: CP_PERMISSIONS, default: [{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}])
    --update-permissions <JSON> JSON array of permission objects for the update step
                                (env: CP_UPDATE_PERMISSIONS, default: same as --permissions)
    --skip-update               Skip permission update step. Only invite the user.
    --delete                    Shorthand for --op delete

${BOLD}TEAMS OPTIONS${RESET}  (--op teams-list | teams-create | teams-get | teams-update | teams-delete | teams-get-perms)
    --team-id <ID>              Team entity ID
                                (env: CP_TEAM_ID)
    --team-data <JSON>          Team JSON body for create/update (e.g. '{"name":"My Team","description":"..."}')
                                (env: CP_TEAM_DATA)

${BOLD}PERMISSIONS OPTIONS${RESET}  (--op groups-get-perms | groups-update-perms | teams-update-perms)
    --group-filter <FILTER>     Group filter for groups-get-perms: <groupAttributeName>:<groupAttributeValue>
                                Use '*' as value to match all: e.g. 'manager:*'
                                Repeat the flag to filter on multiple groups.
                                (env: CP_GROUP_FILTER)
    --permissions-data <JSON>   Permissions JSON body for group/team permissions update
                                (env: CP_PERMISSIONS_DATA)

${BOLD}COMMON OPTIONS${RESET}
    --curl-timeout <SECONDS>    Curl timeout (env: CP_CURL_TIMEOUT, default: 30)
    --verbose                   Enable debug output
    --help                      Show this help message


${BOLD}OPERATIONS${RESET}
    User Management:
      invite               (default) Invite user + update permissions + verify
      delete               Remove user from subscription
      update-user-perms    Update user permissions only (no invite)

    Teams CRUD:
      teams-list           List all teams
      teams-create         Create a new team (requires --team-data)
      teams-get            Get a team by ID (requires --team-id)
      teams-update         Update a team (requires --team-id, --team-data)
      teams-delete         Delete a team (requires --team-id)
      teams-get-perms      Get permissions assigned to a team (requires --team-id)

    Permissions:
      groups-get-perms     Get groups permissions
      groups-update-perms  Update groups permissions (requires --permissions-data)
      teams-update-perms   Update teams permissions (requires --permissions-data)


${BOLD}EXAMPLES${RESET}
    # Invite user with default CAPABILITY_ADMIN role
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --invite-email newuser@example.com

    # Invite user and assign Owner + CAPABILITY_ADMIN permissions
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --invite-email newuser@example.com \\
        --permissions '[{"roleId":"OWNER"},{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]'

    # Update permissions for an existing user (skip invite; userEntityId from GET /users)
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --user-id c6nxhabx3cdzo2ovdwiyybaldeij6oxk \\
        --update-permissions '[{"roleId":"OWNER"},{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]'

    # Delete a user by entity ID
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --user-id c6nxhabx3cdzo2ovdwiyybaldeij6oxk \\
        --delete

    # Delete a user by email (looks up ID first)
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --invite-email newuser@example.com \\
        --delete

    # List all teams
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-list

    # Create a team
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-create \\
        --team-data '{"name":"Platform Engineering","description":"Platform ops team"}'

    # Get a team by ID
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-get \\
        --team-id <teamId>

    # Update a team
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-update \\
        --team-id <teamId> \\
        --team-data '{"name":"Updated Name","description":"Updated description"}'

    # Delete a team
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-delete \\
        --team-id <teamId>

    # Get team permissions
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-get-perms \\
        --team-id <teamId>

    # Get groups permissions for a specific group attribute
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op groups-get-perms \\
        --group-filter 'manager:alice'

    # Get groups permissions for all values of an attribute (wildcard)
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op groups-get-perms \\
        --group-filter 'manager:*'

    # Update groups permissions
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op groups-update-perms \\
        --permissions-data '{"groups":[{"<groupAttributeName>":"<groupAttributeValue>"}],"permissions":[{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]}'

    # Update teams permissions
    ${SCRIPT_NAME} \\
        --cp-url https://acme.cp1-my.example.com \\
        --cp-token 'eyJ...' \\
        --op teams-update-perms \\
        --permissions-data '{"teamIds":[<teamId>],"permissions":[{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]}'

    # Using environment variables
    export CP_SUB_URL=https://acme.cp1-my.example.com
    export CP_ACCESS_TOKEN='eyJ...'
    export CP_INVITE_EMAIL=newuser@example.com
    ${SCRIPT_NAME}


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
        { echo "$DIVIDER"; echo "Response Body:"; echo "$body" | jq . 2>/dev/null || echo "$body"; echo "$DIVIDER"; } >&2
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
# Check the last chunk of a streaming response (PUT /members, DELETE /users).
# These endpoints always return HTTP 2xx; the actual outcome is in the body.
# Exits with error if the last chunk has "status": "error".
# ---------------------------------------------------------------------------
check_streaming_response() {
    local label="$1"
    local json="$2"
    local last_status last_message
    last_status=$(echo "$json" | jq -r 'last.status // empty' 2>/dev/null)
    last_message=$(echo "$json" | jq -r 'last.message // empty' 2>/dev/null)
    if [[ "$last_status" == "error" ]]; then
        log_error "$label failed: $last_message"
        exit 1
    fi
}


# ---------------------------------------------------------------------------
# Argument parsing (CLI flags override env vars)
# ---------------------------------------------------------------------------
parse_args() {
    # Defaults from environment variables
    CP_URL="${CP_SUB_URL:-}"
    CP_TOKEN="${CP_ACCESS_TOKEN:-}"
    OP="${CP_OP:-invite}"
    INVITE_EMAIL="${CP_INVITE_EMAIL:-}"
    USER_ID="${CP_USER_ID:-}"
    local _default_perms='[{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]'
    PERMISSIONS="${CP_PERMISSIONS:-$_default_perms}"
    UPDATE_PERMISSIONS="${CP_UPDATE_PERMISSIONS:-}"
    SKIP_UPDATE=false
    TEAM_ID="${CP_TEAM_ID:-}"
    TEAM_DATA="${CP_TEAM_DATA:-}"
    GROUP_FILTERS=()
    [[ -n "${CP_GROUP_FILTER:-}" ]] && GROUP_FILTERS+=("${CP_GROUP_FILTER}")
    PERMISSIONS_DATA="${CP_PERMISSIONS_DATA:-}"
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
            --cp-url)              require_arg $# "$1"; CP_URL="$2"; shift 2 ;;
            --cp-token)            require_arg $# "$1"; CP_TOKEN="$2"; shift 2 ;;
            --op)                  require_arg $# "$1"; OP="$2"; shift 2 ;;
            --invite-email)        require_arg $# "$1"; INVITE_EMAIL="$2"; shift 2 ;;
            --user-id)             require_arg $# "$1"; USER_ID="$2"; shift 2 ;;
            --permissions)         require_arg $# "$1"; PERMISSIONS="$2"; shift 2 ;;
            --update-permissions)  require_arg $# "$1"; UPDATE_PERMISSIONS="$2"; shift 2 ;;
            --skip-update)         SKIP_UPDATE=true; shift ;;
            --delete)              OP=delete; shift ;;
            --team-id)             require_arg $# "$1"; TEAM_ID="$2"; shift 2 ;;
            --team-data)           require_arg $# "$1"; TEAM_DATA="$2"; shift 2 ;;
            --group-filter)        require_arg $# "$1"; GROUP_FILTERS+=("$2"); shift 2 ;;
            --permissions-data)    require_arg $# "$1"; PERMISSIONS_DATA="$2"; shift 2 ;;
            --curl-timeout)        require_arg $# "$1"; CURL_TIMEOUT="$2"; shift 2 ;;
            --verbose)             VERBOSE=true; shift ;;
            --help|-h)             usage 0 ;;
            *)
                log_error "Unknown option: $1"
                usage 1
                ;;
        esac
    done


    # Common validation
    local errors=()
    [[ -z "$CP_URL" ]]   && errors+=("--cp-url (or CP_SUB_URL) is required")
    [[ -z "$CP_TOKEN" ]] && errors+=("--cp-token (or CP_ACCESS_TOKEN) is required")

    # Per-operation validation
    case "$OP" in
        invite|delete)
            [[ -z "$INVITE_EMAIL" && -z "$USER_ID" ]] && \
                errors+=("--invite-email or --user-id is required for --op $OP")
            ;;
        update-user-perms)
            [[ -z "$USER_ID" && -z "$INVITE_EMAIL" ]] && \
                errors+=("--user-id or --invite-email is required for --op update-user-perms")
            ;;
        teams-create)
            [[ -z "$TEAM_DATA" ]] && errors+=("--team-data is required for --op teams-create")
            ;;
        teams-get|teams-delete|teams-get-perms)
            [[ -z "$TEAM_ID" ]] && errors+=("--team-id is required for --op $OP")
            ;;
        teams-update)
            [[ -z "$TEAM_ID" ]]   && errors+=("--team-id is required for --op teams-update")
            [[ -z "$TEAM_DATA" ]] && errors+=("--team-data is required for --op teams-update")
            ;;
        groups-update-perms|teams-update-perms)
            [[ -z "$PERMISSIONS_DATA" ]] && errors+=("--permissions-data is required for --op $OP")
            ;;
        teams-list)
            : # no additional required flags
            ;;
        groups-get-perms)
            [[ ${#GROUP_FILTERS[@]} -eq 0 ]] && \
                errors+=("--group-filter is required for --op groups-get-perms (e.g. --group-filter 'manager:alice' or --group-filter 'manager:*')")
            ;;
        *)
            errors+=("Unknown operation: '$OP'. Run --help for valid operations.")
            ;;
    esac


    if [[ ${#errors[@]} -gt 0 ]]; then
        for err in "${errors[@]}"; do
            log_error "$err"
        done
        echo ""
        usage 1
    fi

    # Default update permissions to invite permissions if not specified
    UPDATE_PERMISSIONS="${UPDATE_PERMISSIONS:-$PERMISSIONS}"

    # Strip trailing slash from CP_URL
    CP_URL="${CP_URL%/}"
}


# ===========================================================================
# Shared: Verify CP access token
# ===========================================================================
verify_token() {
    log_step "Step 0: Verifying CP access token via /whoami"
    local whoami_response
    whoami_response=$(do_request "Verify CP Token" GET \
        "$CP_URL/cp/v1/whoami" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "CP /whoami response" "$whoami_response"
}


# ===========================================================================
# Shared: Look up user entity ID by email
# ===========================================================================
lookup_user_id() {
    log_info "Looking up user ID for $INVITE_EMAIL..."
    local user_list_response
    user_list_response=$(do_request "Get Users" GET \
        "$CP_URL/cp/api/v1/users" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN")

    USER_ID=$(echo "$user_list_response" | jq -r --arg email "$INVITE_EMAIL" \
        '.users[] | select(.email == $email) | .userEntityId // empty' 2>/dev/null)

    if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
        log_error "Could not find user ID for $INVITE_EMAIL"
        log_error "Verify the email address. Users appear immediately after invite — acceptance is not required."
        print_response "User lookup response" "$user_list_response"
        exit 1
    fi
    log_info "Found user ID: $USER_ID"
}


# ===========================================================================
# User Management Operations
# ===========================================================================

cmd_invite_user() {
    # Step 1: Invite user (skip if --user-id provided)
    if [[ -n "$USER_ID" ]]; then
        log_step "Step 1/3: Invite user"
        log_warn "Skipped — --user-id provided, using existing user $USER_ID"
    else
        log_step "Step 1/3: Inviting user to CP subscription"
        log_info "Inviting: $INVITE_EMAIL"

        local invite_body
        invite_body=$(jq -n \
            --arg email "$INVITE_EMAIL" \
            --argjson permissions "$PERMISSIONS" \
            '{
                action: "invite",
                emails: [$email],
                permissions: $permissions
            }')

        log_debug "Invite request body: $invite_body"

        local invite_response
        invite_response=$(do_request "Invite User" PUT \
            "$CP_URL/cp/api/v1/members" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $CP_TOKEN" \
            -d "$invite_body")
        print_response "Invite user response" "$invite_response"
        # Error codes: ATMOSPHERE-11001 (invalid roleId per PCP-19052), ATMOSPHERE-11004 (user already active per PCP-19062)
        check_streaming_response "Invite user" "$invite_response"
        log_info "User $INVITE_EMAIL invited successfully"
    fi

    # Step 2: Update user permissions (full-replace)
    if [[ "$SKIP_UPDATE" == "true" ]]; then
        log_step "Step 2/3: Update user permissions"
        log_warn "Skipped — --skip-update flag was provided"
    else
        log_step "Step 2/3: Updating user permissions (full-replace)"

        if [[ -z "$USER_ID" ]]; then
            lookup_user_id
        fi

        local update_body
        update_body=$(jq -n \
            --arg uid "$USER_ID" \
            --argjson permissions "$UPDATE_PERMISSIONS" \
            '{
                userEntityIds: [$uid],
                permissions: $permissions
            }')

        log_debug "Update permissions request body: $update_body"

        local update_response
        update_response=$(do_request "Update User Permissions" POST \
            "$CP_URL/cp/api/v1/users/permissions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $CP_TOKEN" \
            -d "$update_body")
        print_response "Update permissions response" "$update_response"
        log_info "Permissions updated for user ${INVITE_EMAIL:-$USER_ID} ($USER_ID)"
    fi

    # Step 3: Verify user permissions
    log_step "Step 3/3: Verifying user permissions"

    local verify_response
    verify_response=$(do_request "Get User Permissions" GET \
        "$CP_URL/cp/api/v1/users/$USER_ID/permissions" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "User permissions" "$verify_response"

    echo ""
    echo "$DIVIDER"
    echo -e "${GREEN}${BOLD}USER MANAGEMENT COMPLETE${RESET}"
    echo "$DIVIDER"
    echo ""
    echo -e "${BOLD}User Details${RESET}"
    [[ -n "${INVITE_EMAIL:-}" ]] && echo "  EMAIL         : $INVITE_EMAIL"
    [[ -n "$USER_ID" ]]          && echo "  USER_ID       : $USER_ID"
    echo "  PERMISSIONS   : $UPDATE_PERMISSIONS"
    echo ""
    echo -e "${BOLD}Useful Commands${RESET}"
    echo ""
    echo "  # List users"
    echo "  curl -s '$CP_URL/cp/api/v1/users' \\"
    echo "       -H 'Authorization: Bearer <CP_ACCESS_TOKEN>' | jq ."
    echo ""
    if [[ -n "$USER_ID" ]]; then
        echo "  # Get user permissions"
        echo "  curl -s '$CP_URL/cp/api/v1/users/$USER_ID/permissions' \\"
        echo "       -H 'Authorization: Bearer <CP_ACCESS_TOKEN>' | jq ."
        echo ""
        echo "  # Update user permissions"
        echo "  curl -s -X POST '$CP_URL/cp/api/v1/users/permissions' \\"
        echo "       -H 'Content-Type: application/json' \\"
        echo "       -H 'Authorization: Bearer <CP_ACCESS_TOKEN>' \\"
        echo "       -d '{\"userEntityIds\": [\"$USER_ID\"], \"permissions\": [{\"roleId\": \"OWNER\"}, {\"roleId\": \"CAPABILITY_ADMIN\", \"dataplaneId\": \"*\", \"instanceId\": \"*\"}]}'"
        echo ""
        echo "  # Delete user"
        echo "  curl -s -X DELETE '$CP_URL/cp/api/v1/users/$USER_ID' \\"
        echo "       -H 'Authorization: Bearer <CP_ACCESS_TOKEN>'"
        echo ""
    fi
    echo "$DIVIDER"
}

cmd_delete_user() {
    log_step "DELETE: Removing user from CP subscription"

    if [[ -z "$USER_ID" ]]; then
        lookup_user_id
    fi

    local delete_response
    delete_response=$(do_request "Delete User" DELETE \
        "$CP_URL/cp/api/v1/users/$USER_ID" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "Delete user response" "$delete_response"
    # Error codes: ATMOSPHERE-11006 (self-deletion attempt per PCP-19058, or last-owner guard)
    check_streaming_response "Delete user" "$delete_response"
    log_info "User ${INVITE_EMAIL:-$USER_ID} ($USER_ID) removed from subscription"

    echo ""
    echo "$DIVIDER"
    echo -e "${GREEN}${BOLD}USER DELETED SUCCESSFULLY${RESET}"
    echo "$DIVIDER"
    echo "  USER_ID : $USER_ID"
    [[ -n "$INVITE_EMAIL" ]] && echo "  EMAIL   : $INVITE_EMAIL"
    echo "$DIVIDER"
}

cmd_update_user_perms() {
    log_step "Updating user permissions (full-replace)"

    if [[ -z "$USER_ID" ]]; then
        lookup_user_id
    fi

    local update_body
    update_body=$(jq -n \
        --arg uid "$USER_ID" \
        --argjson permissions "$UPDATE_PERMISSIONS" \
        '{
            userEntityIds: [$uid],
            permissions: $permissions
        }')

    log_debug "Update permissions request body: $update_body"

    local update_response
    update_response=$(do_request "Update User Permissions" POST \
        "$CP_URL/cp/api/v1/users/permissions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN" \
        -d "$update_body")
    print_response "Update permissions response" "$update_response"
    log_info "Permissions updated for user ${INVITE_EMAIL:-$USER_ID} ($USER_ID)"

    echo ""
    echo "$DIVIDER"
    echo -e "${GREEN}${BOLD}PERMISSIONS UPDATED${RESET}"
    echo "$DIVIDER"
    echo "  USER_ID     : $USER_ID"
    echo "  PERMISSIONS : $UPDATE_PERMISSIONS"
    echo "$DIVIDER"
}


# ===========================================================================
# Teams CRUD Operations
# ===========================================================================

cmd_teams_list() {
    log_step "Listing teams"
    local response
    response=$(do_request "List Teams" GET \
        "$CP_URL/cp/api/v1/teams" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "Teams" "$response"
}

cmd_teams_create() {
    log_step "Creating team"
    log_debug "Team data: $TEAM_DATA"
    local response
    response=$(do_request "Create Team" POST \
        "$CP_URL/cp/api/v1/teams" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN" \
        -d "$TEAM_DATA")
    print_response "Created team" "$response"

    local team_id
    team_id=$(echo "$response" | jq -r '.teamId // .id // empty' 2>/dev/null || true)
    if [[ -n "$team_id" ]]; then
        echo ""
        echo -e "${GREEN}${BOLD}TEAM CREATED${RESET}"
        echo "  TEAM_ID : $team_id"
        echo "$DIVIDER"
    fi
}

cmd_teams_get() {
    log_step "Getting team: $TEAM_ID"
    local response
    response=$(do_request "Get Team" GET \
        "$CP_URL/cp/api/v1/teams/$TEAM_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "Team details" "$response"
}

cmd_teams_update() {
    log_step "Updating team: $TEAM_ID"
    log_debug "Team data: $TEAM_DATA"
    local response
    response=$(do_request "Update Team" PUT \
        "$CP_URL/cp/api/v1/teams/$TEAM_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN" \
        -d "$TEAM_DATA")
    print_response "Updated team" "$response"
}

cmd_teams_delete() {
    log_step "Deleting team: $TEAM_ID"
    local response
    response=$(do_request "Delete Team" DELETE \
        "$CP_URL/cp/api/v1/teams/$TEAM_ID" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "Delete team response" "$response"
    log_info "Team $TEAM_ID deleted"
}

cmd_teams_get_perms() {
    log_step "Getting permissions for team: $TEAM_ID"
    local response
    response=$(do_request "Get Team Permissions" GET \
        "$CP_URL/cp/api/v1/teams/$TEAM_ID/permissions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "Team permissions" "$response"
}


# ===========================================================================
# Groups Permissions Operations
# ===========================================================================

cmd_groups_get_perms() {
    log_step "Getting groups permissions"
    # Build ?groups=<filter> query string (one param per --group-filter)
    local qs="" sep="?"
    for f in "${GROUP_FILTERS[@]}"; do
        qs+="${sep}groups=${f}"
        sep="&"
    done
    local response
    response=$(do_request "Get Groups Permissions" GET \
        "$CP_URL/cp/api/v1/groups/permissions${qs}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN")
    print_response "Groups permissions" "$response"
}

cmd_groups_update_perms() {
    log_step "Updating groups permissions"
    log_debug "Permissions data: $PERMISSIONS_DATA"
    local response
    response=$(do_request "Update Groups Permissions" POST \
        "$CP_URL/cp/api/v1/groups/permissions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN" \
        -d "$PERMISSIONS_DATA")
    print_response "Update groups permissions response" "$response"
}


# ===========================================================================
# Teams Permissions Operations
# ===========================================================================

cmd_teams_update_perms() {
    log_step "Updating teams permissions"
    log_debug "Permissions data: $PERMISSIONS_DATA"
    local response
    response=$(do_request "Update Teams Permissions" POST \
        "$CP_URL/cp/api/v1/teams/permissions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CP_TOKEN" \
        -d "$PERMISSIONS_DATA")
    print_response "Update teams permissions response" "$response"
}


# ===========================================================================
# Main — dispatch based on --op
# ===========================================================================
main() {
    parse_args "$@"
    check_dependencies

    RESPONSE_FILE=$(mktemp)
    log_debug "Temporary response file: $RESPONSE_FILE"

    local op_label
    op_label=$(echo "$OP" | tr '-' ' ' | tr '[:lower:]' '[:upper:]')

    echo ""
    echo "$DIVIDER"
    echo -e "${CYAN}${BOLD}TIBCO Control Plane Phase 2 API: $op_label${RESET}"
    echo "$DIVIDER"
    echo ""

    verify_token

    case "$OP" in
        invite)               cmd_invite_user ;;
        delete)               cmd_delete_user ;;
        update-user-perms)    cmd_update_user_perms ;;
        teams-list)           cmd_teams_list ;;
        teams-create)         cmd_teams_create ;;
        teams-get)            cmd_teams_get ;;
        teams-update)         cmd_teams_update ;;
        teams-delete)         cmd_teams_delete ;;
        teams-get-perms)      cmd_teams_get_perms ;;
        groups-get-perms)     cmd_groups_get_perms ;;
        groups-update-perms)  cmd_groups_update_perms ;;
        teams-update-perms)   cmd_teams_update_perms ;;
        *)
            log_error "Unknown operation: $OP"
            usage 1
            ;;
    esac
}


main "$@"
