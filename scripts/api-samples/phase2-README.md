<!-- 
 Copyright (c) 2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

# TIBCO Control Plane: User Management & Automation API — Phase 2


Covers the Phase 2 public Control Plane (CP) APIs for user management, teams, and permission management. These APIs extend the Phase 1 OAuth2 client and provisioning automation. Use these after completing Phase 1 setup (see [API-Based Automation](README.md)).


> **Base URL:** All endpoints use `{CP_URL}` — the base URL of your CP subscription (e.g. `https://acme.cp1-my.example.com`).


## Prerequisites


- Phase 1 completed: a fully provisioned CP subscription with an OAuth2 client configured (see [API-Based Automation](README.md))
- A valid CP OAuth2 access token (obtained via client credentials flow — see [Token Renewal](README.md#token-renewal))


## Table of Contents


- [Workflow Overview](#workflow-overview)
- [API Reference](#api-reference)
  - [User Management](#user-management)
    - [Step 1 — Invite User](#step-1--invite-user)
    - [Step 2 — Update User Permissions (Full-Replace)](#step-2--update-user-permissions-full-replace)
    - [Step 3 — Verify User Permissions](#step-3--verify-user-permissions)
    - [Delete User](#delete-user)
  - [Teams CRUD](#teams-crud)
    - [Create Team](#create-team)
    - [List Teams](#list-teams)
    - [Get Team](#get-team)
    - [Update Team](#update-team)
    - [Delete Team](#delete-team)
    - [Get Team Permissions](#get-team-permissions)
  - [Permission Update — All Subjects](#permission-update--all-subjects)
    - [Groups Permissions](#groups-permissions)
    - [Teams Permissions](#teams-permissions)
- [Permission Roles](#permission-roles)
- [Example Script](#example-script)
  - [Prerequisites](#prerequisites-1)
  - [Quick Start](#quick-start)
  - [Configuration](#configuration)
  - [Script Help](#script-help)
- [Troubleshooting](#troubleshooting)


## Workflow Overview


The sample script (`phase2-user-management.sh`) covers all APIs below via the `--op` flag:


```
Step 0  Verify CP Access Token ──► /cp/v1/whoami  (always runs)

User Management:
  invite             Invite user → update permissions → verify   (default)
  delete             Remove user from subscription
  update-user-perms  Update user permissions only (no invite)

Teams CRUD:
  teams-list         List all teams
  teams-create       Create a new team
  teams-get          Get a team by ID
  teams-update       Update a team
  teams-delete       Delete a team
  teams-get-perms    Get permissions assigned to a team

Permissions:
  groups-get-perms     Get groups permissions (requires --group-filter)
  groups-update-perms  Update groups permissions
  teams-update-perms   Update teams permissions
```


## API Reference


---


### User Management


#### Step 1 — Invite User


Invites a user to the CP subscription by email. The user receives an invitation email and is assigned the specified permissions.


```
PUT {CP_URL}/cp/api/v1/members
```


**Auth:** `Authorization: Bearer <cp-access-token>`


> **Streaming response:** This endpoint always returns `HTTP 200 OK` regardless of outcome. The response body is a JSON array delivered as a stream of chunks. To determine success or failure, inspect the `status` field of the **last** chunk — `"success"` means the operation completed; `"error"` means it failed. On error, the `message` field contains the reason.


**Request Body:**


```json
{
 "action": "invite",
 "emails": ["newuser@example.com"],
 "permissions": [
   {
     "roleId": "CAPABILITY_ADMIN",
     "dataplaneId": "*",
     "instanceId": "*"
   }
 ]
}
```


When an external IdP is configured and you want to restrict the user to IdP-only login, set `allowTibcoAuthentication: false`:


```json
{
 "action": "invite",
 "emails": ["newuser@example.com"],
 "permissions": [
   {
     "roleId": "CAPABILITY_ADMIN",
     "dataplaneId": "*",
     "instanceId": "*"
   }
 ],
 "allowTibcoAuthentication": false
}
```


| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action` | string | Yes | Must be `"invite"` |
| `emails` | string[] | Yes | List of email addresses to invite |
| `permissions` | object[] | Yes | Permissions to assign to the invited users |
| `permissions[].roleId` | string | Yes | Role identifier (see [Permission Roles](#permission-roles)) |
| `permissions[].dataplaneId` | string | No | Data plane ID (`"*"` for all) |
| `permissions[].instanceId` | string | No | Instance ID (`"*"` for all) |
| `allowTibcoAuthentication` | boolean | No | When `false`, restricts user to IdP-only login (requires external IdP configured). Default: `true` |


**Sample Response — Success:**


```json
[
 {"code": "ATMOSPHERE-11055", "status": "updating", "message": "Updating org/tenant members"},
 {"code": "ATMOSPHERE-11093", "status": "success", "message": "Assigned permission(s) successfully"}
]
```


**Sample Response — Error:**


```json
[
 {"code": "ATMOSPHERE-11055", "status": "updating", "message": "Updating org/tenant members"},
 {"code": "ATMOSPHERE-11001", "status": "error",   "message": "action is missing in request"}
]
```


| Error Code | `message` | Cause |
|------------|-----------|-------|
| `ATMOSPHERE-11001` | `action is missing in request` | `action` field not present in the request body |
| `ATMOSPHERE-11001` | `Invalid email address '<email>' in the request` | One or more email addresses are malformed |
| `ATMOSPHERE-11001` | `Invalid roleId '<roleId>' in the request` | One or more `roleId` values are not recognised by PEngine (PCP-19052) |
| `ATMOSPHERE-11004` | `Missing emails in the request` | `emails` field is absent or empty |
| `ATMOSPHERE-11004` | `User <email> has already accepted an invitation` | Email belongs to a user who has already accepted a prior invitation — re-invite not allowed (PCP-19062) |


---


#### Step 2 — Update User Permissions (Full-Replace)


Performs a full replacement of the user's permissions. All existing permissions are removed and replaced with the provided set.

> **Self-targeting behaviour:** When the token owner targets their **own** `userEntityId`, `OWNER` and `TEAM_ADMIN` permissions are protected — they are silently retained even if not included in the payload. If the payload explicitly includes `OWNER` or `TEAM_ADMIN` for the token owner's own user, the API returns `HTTP 403`.


> **Note:** To update permissions, you need the user's entity ID. Use `GET /cp/api/v1/users` to list all users and find the target user by email.


**List Users:**


```
GET {CP_URL}/cp/api/v1/users
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Sample Response:**


```json
{
 "users": [
   {
     "userEntityId": "<userEntityId>",
     "email": "newuser@example.com",
     "status": "invited",
     "roleIds": []
   }
 ]
}
```


> **Notes:**
> - Returns all users in the subscription. Filter by email to find the target user.
> - `firstName` and `lastName` are not returned for users who have not yet accepted their invitation.
> - `roleIds` is empty (`[]`) immediately after invite for data-plane-scoped roles (`CAPABILITY_ADMIN`, `DEV_OPS`, `PLATFORM_OPS`, `CAPABILITY_USER`). These roles are reflected in the user's assigned roles only after `POST /cp/api/v1/users/permissions` is called. Subscription-level roles (`OWNER`, `TEAM_ADMIN`, `IDP_MANAGER`, `BROWSE_ASSIGNMENTS`) appear in `roleIds` immediately.


**Update Permissions:**


```
POST {CP_URL}/cp/api/v1/users/permissions
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Request Body:**


```json
{
 "userEntityIds": ["<userEntityId>"],
 "permissions": [
   {
     "roleId": "OWNER"
   },
   {
     "roleId": "CAPABILITY_ADMIN",
     "dataplaneId": "*",
     "instanceId": "*"
   }
 ]
}
```


If you don't have the user's entity ID, use `emails` instead:


```json
{
 "emails": ["newuser@example.com"],
 "permissions": [
   {
     "roleId": "CAPABILITY_ADMIN",
     "dataplaneId": "*",
     "instanceId": "*"
   }
 ]
}
```


> **Note:** Provide `userEntityIds` or `emails` — if both are provided, `userEntityIds` takes precedence. Returns `HTTP 404` if the email is not found in the subscription.


| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `userEntityIds` | string[] | Yes (or `emails`) | Target user's entity ID. Matches the `userEntityId` field returned by `GET /users`. Takes precedence over `emails` if both provided. |
| `emails` | string[] | Yes (or `userEntityIds`) | Target user's email. Returns `HTTP 404` if not found. |
| `permissions` | object[] | Yes | Full set of permissions to assign (replaces all existing) |
| `permissions[].roleId` | string | Yes | Role identifier (see [Permission Roles](#permission-roles)) |
| `permissions[].dataplaneId` | string | No | Data plane ID (`"*"` for all data planes) |
| `permissions[].instanceId` | string | No | Instance ID (`"*"` for all instances) |


**Sample Response:**


```json
{
 "<userEntityId>": "SUCCESS"
}
```


| Error | Cause |
|-------|-------|
| `HTTP 400` | One or more `roleId` values are not valid — check the error message for the unknown value |
| `HTTP 403` | Token user does not have `OWNER` or `TEAM_ADMIN` role |
| `HTTP 403` | Payload contains `OWNER` or `TEAM_ADMIN` and the target user is the token owner (self-targeting) |
| `HTTP 404` | Email not found in the subscription (when using `emails` field) |


---


#### Step 3 — Verify User Permissions


Verify the user's assigned permissions using the per-user permissions endpoint.


```
GET {CP_URL}/cp/api/v1/users/{userEntityId}/permissions
```


**Auth:** `Authorization: Bearer <cp-access-token>`


> **Note:** Use `GET /cp/api/v1/users` to look up the `userEntityId` by email before calling this endpoint.


**Sample Response:**


```json
[
 {
   "roleId": "OWNER",
   "exclude": false,
   "description": "Owner",
   "appliesTo": ["CP"],
   "instanceDetails": []
 },
 {
   "roleId": "CAPABILITY_ADMIN",
   "exclude": false,
   "description": "Application Manager",
   "appliesTo": ["DP"],
   "instanceDetails": [
     {
       "roleId": "CAPABILITY_ADMIN",
       "dataplaneId": "*",
       "instanceId": "*",
       "exclude": false
     }
   ]
 }
]
```


| Field | Description |
|-------|-------------|
| `roleId` | Role identifier (see [Permission Roles](#permission-roles)) |
| `exclude` | Whether this is an exclusion rule |
| `description` | Human-readable role description |
| `appliesTo` | Scope type: `"CP"` for subscription-level, `"DP"` for data-plane-scoped |
| `instanceDetails` | Per-dataplane/instance breakdown; empty for subscription-level roles |


---


#### Delete User


Removes a user from the CP subscription. The last owner of a subscription cannot be deleted. A user cannot delete themselves — attempting to do so returns `HTTP 403`.


```
DELETE {CP_URL}/cp/api/v1/users/{userEntityId}
```


**Auth:** `Authorization: Bearer <cp-access-token>`


> **Streaming response:** This endpoint always returns `HTTP 202 Accepted` regardless of outcome. The response body is a JSON array delivered as a stream of chunks. To determine success or failure, inspect the `status` field of the **last** chunk — `"success"` means the user was removed; `"error"` means it failed. On error, the `message` field contains the reason.


> **Note:** Use `GET /cp/api/v1/users` first to look up the `userEntityId` by email.


**Sample Response — Success:**


```json
[
 {"code": "ATMOSPHERE-11059", "status": "deleting", "message": "Deleting org/tenant member"},
 {"code": "ATMOSPHERE-11079", "status": "success",  "message": "Deleted org member successfully"}
]
```


**Sample Response — Error:**


```json
[
 {"code": "ATMOSPHERE-11059", "status": "deleting", "message": "Deleting org/tenant member"},
 {"code": "ATMOSPHERE-11006", "status": "error",    "message": "no permission to call this api"}
]
```


| Error Code | `message` | Cause |
|------------|-----------|-------|
| `ATMOSPHERE-11006` | `no permission to call this api` | Token user does not have `OWNER` or `TEAM_ADMIN` role |
| `ATMOSPHERE-11006` | `You cannot remove yourself. Please ask another Owner or Team Admin to remove you from the Organization.` | Requester is attempting to delete their own account (PCP-19058) |
| `ATMOSPHERE-11006` | `Cannot delete the last owner of a subscription` | Target user is the sole `OWNER` of the subscription |


---


### Teams CRUD


Teams group users and can be assigned permissions across data planes and capabilities.


---


#### Create Team


```
POST {CP_URL}/cp/api/v1/teams
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Request Body:**


```json
{
 "name": "Platform Engineering",
 "description": "Platform operations team"
}
```


| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Team display name |
| `description` | string | No | Team description |


**Sample Response:**


```json
{
 "teamId": 42,
 "name": "Platform Engineering",
 "description": "Platform operations team"
}
```


| Error | Cause |
|-------|-------|
| `HTTP 403` | Token user does not have `OWNER` or `TEAM_ADMIN` role |
| `HTTP 409` | A team with this name already exists |


---


#### List Teams


```
GET {CP_URL}/cp/api/v1/teams
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Sample Response:**


```json
{
 "teams": [
   {
     "teamId": 42,
     "name": "Platform Engineering",
     "description": "Platform operations team"
   }
 ]
}
```


---


#### Get Team


```
GET {CP_URL}/cp/api/v1/teams/{teamId}
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Sample Response:**


```json
{
 "teamId": 42,
 "name": "Platform Engineering",
 "description": "Platform operations team"
}
```


| Error | Cause |
|-------|-------|
| `HTTP 404` | Team not found |


---


#### Update Team


```
PUT {CP_URL}/cp/api/v1/teams/{teamId}
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Request Body:**


```json
{
 "name": "Updated Team Name",
 "description": "Updated team description"
}
```


**Sample Response:**


```json
{
 "message": "Team has been updated successfully"
}
```


| Error | Cause |
|-------|-------|
| `HTTP 403` | Insufficient permissions |
| `HTTP 404` | Team not found |


---


#### Delete Team


```
DELETE {CP_URL}/cp/api/v1/teams/{teamId}
```


**Auth:** `Authorization: Bearer <cp-access-token>`


Returns `HTTP 200` on success.


| Error | Cause |
|-------|-------|
| `HTTP 403` | Insufficient permissions |
| `HTTP 404` | Team not found |


---


#### Get Team Permissions


```
GET {CP_URL}/cp/api/v1/teams/{teamId}/permissions
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Sample Response:**

Returns a bare array of permission objects (not wrapped in an object):

```json
[
 {
   "roleId": "CAPABILITY_ADMIN",
   "dataplaneId": "*",
   "instanceId": "*",
   "exclude": false,
   "description": "Application Manager",
   "appliesTo": ["DP"],
   "scope": "*"
 }
]
```

Returns `[]` if no permissions are assigned to the team.

| Field | Description |
|-------|-------------|
| `roleId` | Role identifier |
| `dataplaneId` | Data plane scope (`"*"` for all) |
| `instanceId` | Instance scope (`"*"` for all) |
| `exclude` | Whether this is an exclusion rule |
| `description` | Human-readable role description |
| `appliesTo` | Scope type (e.g. `["DP"]` for data plane) |
| `scope` | Effective scope value |

| Error | Cause |
|-------|-------|
| `HTTP 404` | Team not found |


---


### Permission Update — All Subjects


Permission update APIs are available for groups and teams in addition to the user-level API in [Step 2](#step-2--update-user-permissions-full-replace).


> **Note:** Groups permissions apply to IdP groups synced from an external identity provider. This section only applies if an external IdP is configured for your subscription.


---


#### Groups Permissions


**Get Groups Permissions:**


```
GET {CP_URL}/cp/api/v1/groups/permissions?groups=<groupAttributeName>:<groupAttributeValue>
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Query Parameters:**


| Parameter | Required | Description |
|-----------|----------|-------------|
| `groups` | Yes | Group filter in the format `<groupAttributeName>:<groupAttributeValue>`. Use `*` as the value to match all values for a given attribute (e.g. `manager:*`). Repeat the parameter to filter on multiple groups. |


**Sample Response:**


```json
{
 "groupsPermissions": [
   {
     "groupDetails": {
       "name": "<groupAttributeName>",
       "value": "<groupAttributeValue>"
     },
     "permissions": [
       {
         "roleId": "CAPABILITY_ADMIN",
         "dataplaneId": "*",
         "instanceId": "*"
       }
     ]
   }
 ]
}
```


---


**Update Groups Permissions:**


```
POST {CP_URL}/cp/api/v1/groups/permissions
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Request Body:**


```json
{
 "groups": [
   { "<groupAttributeName>": "<groupAttributeValue>" }
 ],
 "permissions": [
   {
     "roleId": "CAPABILITY_ADMIN",
     "dataplaneId": "*",
     "instanceId": "*"
   }
 ]
}
```


Each element in `groups` is a single-key object where the key is the group attribute name (e.g. `"manager"`, `"department"`) and the value is the group attribute value (e.g. `"veena"`, `"engineering"`).


| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `groups` | object[] | Yes | List of group attribute objects. Each object must have exactly one key-value pair: `{groupAttributeName: groupAttributeValue}` |
| `permissions` | object[] | Yes | Permissions to assign |
| `permissions[].roleId` | string | Yes | Role identifier (see [Permission Roles](#permission-roles)) |
| `permissions[].dataplaneId` | string | No | Data plane scope (`"*"` for all) |
| `permissions[].instanceId` | string | No | Instance scope (`"*"` for all) |


**Sample Response:**


```json
{
 "successData": [
   {
     "response": {},
     "group": { "name": "<groupAttributeName>", "value": "<groupAttributeValue>" },
     "status": 200
   }
 ],
 "errorData": []
}
```


| Error | Cause |
|-------|-------|
| `HTTP 400` | `groups` field missing, not an array, or empty |
| `HTTP 400` | One or more `roleId` values are not valid — check the error message for the unknown value |
| `HTTP 400` | One or more group attribute names are not configured in the IdP — check `errorData[].response.message` for details |


---


#### Teams Permissions


**Update Teams Permissions:**


```
POST {CP_URL}/cp/api/v1/teams/permissions
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Request Body:**


```json
{
 "teamIds": [42],
 "permissions": [
   {
     "roleId": "CAPABILITY_ADMIN",
     "dataplaneId": "*",
     "instanceId": "*"
   }
 ]
}
```


| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `teamIds` | integer[] | Yes | List of team IDs to assign permissions to. Use the integer `teamId` returned by the create/list teams APIs. |
| `permissions` | object[] | Yes | Permissions to assign |
| `permissions[].roleId` | string | Yes | Role identifier |
| `permissions[].dataplaneId` | string | No | Data plane scope (`"*"` for all) |
| `permissions[].instanceId` | string | No | Instance scope (`"*"` for all) |


**Sample Response:**


```json
{
 "message": "Permission(s) added successfully"
}
```


| Error | Cause |
|-------|-------|
| `HTTP 400` | One or more `roleId` values are not valid — check the error message for the unknown value |
| `HTTP 404` | One or more `teamIds` not found |


---


## Permission Roles


The `roleId` values must exactly match the identifiers below.


**Subscription-level roles** (no `dataplaneId`/`instanceId` needed):


| `roleId` | Display Name | Description |
|----------|-------------|-------------|
| `OWNER` | Owner | Add users and assign permissions to other users including other owners. Create and manage teams. |
| `IDP_MANAGER` | IdP Manager | Configure Single Sign On for the enterprise. |
| `TEAM_ADMIN` | Team Admin | Add, edit, and remove other users except owners or IdP managers. Manage teams. |
| `BROWSE_ASSIGNMENTS` | View Permissions | View the assigned permissions of all users. |


**Data-plane-scoped roles** (require `dataplaneId`; use `"*"` for all):


| `roleId` | Display Name | Description |
|----------|-------------|-------------|
| `PLATFORM_OPS` | Data Plane Manager | Register, manage, or de-register a data plane. |
| `DEV_OPS` | Capability Manager | Provision or de-provision a capability. |
| `CAPABILITY_ADMIN` | Application Manager | Deploy, edit, or delete applications for a selected capability. |
| `CAPABILITY_USER` | Application Viewer | Read-only access to all the applications of a capability. |


> **Scope:** Subscription-level roles apply globally. Data-plane-scoped roles require `dataplaneId` (and optionally `instanceId`). Use `"*"` to apply across all data planes or instances.


## Example Script


`phase2-user-management.sh` is a sample script that demonstrates all APIs above. Use it as a reference to write your own automation.


### Prerequisites


- **bash** 4.0+
- **curl**
- **jq**
- A provisioned CP subscription with a valid OAuth2 access token


### Quick Start


```bash
chmod +x phase2-user-management.sh


# Invite a user (default operation)
./phase2-user-management.sh \
    --cp-url https://acme.cp1-my.example.com \
    --cp-token 'eyJ...' \
    --invite-email newuser@example.com

# Create a team
./phase2-user-management.sh \
    --cp-url https://acme.cp1-my.example.com \
    --cp-token 'eyJ...' \
    --op teams-create \
    --team-data '{"name":"Platform Engineering","description":"Platform ops team"}'

# Get groups permissions
./phase2-user-management.sh \
    --cp-url https://acme.cp1-my.example.com \
    --cp-token 'eyJ...' \
    --op groups-get-perms \
    --group-filter 'manager:*'

# Update groups permissions
./phase2-user-management.sh \
    --cp-url https://acme.cp1-my.example.com \
    --cp-token 'eyJ...' \
    --op groups-update-perms \
    --permissions-data '{"groups":[{"manager":"alice"}],"permissions":[{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]}'
```


Or using environment variables:


```bash
export CP_SUB_URL=https://acme.cp1-my.example.com
export CP_ACCESS_TOKEN='eyJ...'
export CP_INVITE_EMAIL=newuser@example.com


./phase2-user-management.sh
```


### Configuration


All parameters accept both CLI flags and environment variables. CLI flags take precedence.


**Common:**


| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--cp-url` | `CP_SUB_URL` | *(required)* | CP subscription base URL |
| `--cp-token` | `CP_ACCESS_TOKEN` | *(required)* | CP OAuth2 access token |
| `--op` | `CP_OP` | `invite` | Operation to perform (see [Workflow Overview](#workflow-overview)) |
| `--curl-timeout` | `CP_CURL_TIMEOUT` | `30` | HTTP request timeout in seconds |
| `--verbose` | `VERBOSE` | `false` | Enable debug output |


**User Management** (`--op invite`, `delete`, `update-user-perms`):


| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--invite-email` | `CP_INVITE_EMAIL` | *(required unless `--user-id`)* | Email of the user to invite or look up |
| `--user-id` | `CP_USER_ID` | — | Skip invite; use this `userEntityId` directly |
| `--permissions` | `CP_PERMISSIONS` | `[{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]` | Permissions for the invited user |
| `--update-permissions` | `CP_UPDATE_PERMISSIONS` | same as `--permissions` | Permissions for the update step |
| `--skip-update` | — | `false` | Skip Step 2 (update permissions) |
| `--delete` | — | `false` | Shorthand for `--op delete` |


**Teams** (`--op teams-create`, `teams-get`, `teams-update`, `teams-delete`, `teams-get-perms`):


| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--team-id` | `CP_TEAM_ID` | — | Team entity ID |
| `--team-data` | `CP_TEAM_DATA` | — | Team JSON body for create/update |


**Permissions** (`--op groups-get-perms`, `groups-update-perms`, `teams-update-perms`):


| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--group-filter` | `CP_GROUP_FILTER` | *(required for `groups-get-perms`)* | Group filter: `<groupAttributeName>:<groupAttributeValue>`. Use `*` as value for wildcard. Repeat for multiple groups. |
| `--permissions-data` | `CP_PERMISSIONS_DATA` | *(required for update ops)* | Permissions JSON body |


### Script Help


```
NAME
    phase2-user-management.sh - Sample script for TIBCO Control Plane Phase 2 APIs: user management, teams, and permissions

SYNOPSIS
    phase2-user-management.sh --cp-url <URL> --cp-token <TOKEN> [--op <operation>] [OPTIONS]

REQUIRED
    --cp-url <URL>              CP subscription base URL
                                (env: CP_SUB_URL)
    --cp-token <TOKEN>          CP OAuth2 access token
                                (env: CP_ACCESS_TOKEN)

USER MANAGEMENT OPTIONS  (--op invite | delete | update-user-perms)
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

TEAMS OPTIONS  (--op teams-list | teams-create | teams-get | teams-update | teams-delete | teams-get-perms)
    --team-id <ID>              Team entity ID
                                (env: CP_TEAM_ID)
    --team-data <JSON>          Team JSON body for create/update (e.g. '{"name":"My Team","description":"..."}')
                                (env: CP_TEAM_DATA)

PERMISSIONS OPTIONS  (--op groups-get-perms | groups-update-perms | teams-update-perms)
    --group-filter <FILTER>     Group filter for groups-get-perms: <groupAttributeName>:<groupAttributeValue>
                                Use '*' as value to match all: e.g. 'manager:*'
                                Repeat the flag to filter on multiple groups.
                                (env: CP_GROUP_FILTER)
    --permissions-data <JSON>   Permissions JSON body for group/team permissions update
                                (env: CP_PERMISSIONS_DATA)

COMMON OPTIONS
    --curl-timeout <SECONDS>    Curl timeout (env: CP_CURL_TIMEOUT, default: 30)
    --verbose                   Enable debug output
    --help                      Show this help message

OPERATIONS
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
      groups-get-perms     Get groups permissions (requires --group-filter)
      groups-update-perms  Update groups permissions (requires --permissions-data)
      teams-update-perms   Update teams permissions (requires --permissions-data)

EXAMPLES
    # Invite user with default CAPABILITY_ADMIN role
    phase2-user-management.sh \
        --cp-url https://acme.cp1-my.example.com \
        --cp-token 'eyJ...' \
        --invite-email newuser@example.com

    # Get groups permissions (wildcard)
    phase2-user-management.sh \
        --cp-url https://acme.cp1-my.example.com \
        --cp-token 'eyJ...' \
        --op groups-get-perms \
        --group-filter 'manager:*'

    # Update groups permissions
    phase2-user-management.sh \
        --cp-url https://acme.cp1-my.example.com \
        --cp-token 'eyJ...' \
        --op groups-update-perms \
        --permissions-data '{"groups":[{"manager":"alice"}],"permissions":[{"roleId":"CAPABILITY_ADMIN","dataplaneId":"*","instanceId":"*"}]}'

    # Using environment variables
    export CP_SUB_URL=https://acme.cp1-my.example.com
    export CP_ACCESS_TOKEN='eyJ...'
    export CP_INVITE_EMAIL=newuser@example.com
    phase2-user-management.sh
```


## Troubleshooting


| Symptom | Cause | Fix |
|---------|-------|-----|
| `HTTP 401` on any step | Invalid or expired access token | Regenerate the CP access token (see [Token Renewal](README.md#token-renewal)) |
| `status: "error"` in invite response (`ATMOSPHERE-11006`) | Insufficient permissions | The token must belong to a user with `OWNER` or `TEAM_ADMIN` role |
| `status: "error"` in invite response (`ATMOSPHERE-11001`) | Invalid `roleId` in permissions | Verify `roleId` values against the [Permission Roles](#permission-roles) table — unrecognised values are rejected by PEngine (PCP-19052) |
| `status: "error"` in invite response (`ATMOSPHERE-11004`) | User already active | The email belongs to a user who has already accepted a prior invitation; remove and re-add instead of re-inviting (PCP-19062) |
| `status: "error"` in delete response (`ATMOSPHERE-11006`) | Self-deletion attempt | A user cannot delete their own account — ask another Owner or Team Admin to remove you (PCP-19058) |
| `HTTP 403` on update permissions | Insufficient permissions | The token user must have permission to both revoke existing and assign new roles |
| `Could not find user ID` | Email not found in subscription | Verify the email address. Users appear in the list immediately after invite with `status: "invited"` — acceptance is not required |
| `curl: connection refused` | Platform not running | Verify `--cp-url` and that the platform is accessible |
| `jq: command not found` | Missing dependency | Install jq: `apt install jq` / `brew install jq` |
