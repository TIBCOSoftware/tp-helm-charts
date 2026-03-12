# TIBCO Control Plane API-Based Automation with IdP Configuration


Automated provisioning of TIBCO Control Plane subscriptions with external SAML IdP configuration. This covers the provisioning workflow including self-signed certificate generation, external IdP setup, and subscription/IdP verification steps.


## Table of Contents


- [Provisioning Workflow](#provisioning-workflow)
- [API Reference](#api-reference)
  - [Step 1 — Initialize TIBCO Platform Console](#step-1--initialize-tibco-platform-console)
  - [Step 2 — Register OAuth2 Client (ADMIN)](#step-2--register-oauth2-client-admin)
  - [Step 3 — Revoke Initial Access Token (ADMIN)](#step-3--revoke-initial-access-token-admin)
  - [Step 4 — OAuth2 Token Exchange (ADMIN)](#step-4--oauth2-token-exchange-admin)
  - [Step 5 — Generate Self-Signed Certificate](#step-5--generate-self-signed-certificate)
  - [Step 6 — Configure External IdP](#step-6--configure-external-idp)
  - [Step 7 — Create CP Subscription](#step-7--create-cp-subscription)
  - [Step 8 — Register OAuth2 Client (CP) & Revoke CP IAT](#step-8--register-oauth2-client-cp--revoke-cp-iat)
  - [Step 9 — OAuth2 Token Exchange (CP) & Verify](#step-9--oauth2-token-exchange-cp--verify)
- [Token Renewal](#token-renewal)
- [Example Script](#example-script)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
  - [Configuration](#configuration)
  - [Script Help](#script-help)
- [Troubleshooting](#troubleshooting)


## Provisioning Workflow


The provisioning executes 9 sequential steps:


```
Step 1  Initialize TIBCO Platform Console
        │
Step 2  Register ADMIN OAuth2 Client
        │
Step 3  Revoke ADMIN Initial Access Token
        │
Step 4  Exchange credentials for ADMIN Access Token ──► Verify via /whoami
        │
Step 5  Generate Self-Signed Certificate          (optional, for IdP configuration)
        │
Step 6  Configure External IdP ──► Verify ADMIN   (optional)
        │
Step 7  Create CP Subscription ──► Verify CP Subscription & IdP Details
        │
Step 8  Register CP OAuth2 Client ──► Revoke CP Initial Access Token
        │
Step 9  Exchange credentials for CP Access Token ──► Verify via /whoami
```


## API Reference


### Step 1 — Initialize TIBCO Platform Console


Bootstraps the ADMIN subscription and returns an Initial Access Token (IAT).


```
POST {BASE_URL}/platform-console/api/v1/init
```


**Auth:** HTTP Basic (`admin-email:admin-initial-password`)


**Request Body:**


```json
{
 "externalAccountId": "admin",
 "externalSubscriptionId": "admin-sub",
 "firstName": "<firstName>",
 "lastName": "<lastName>",
 "email": "<email>",
 "organizationName": "TSC Admin Subscription",
 "hostPrefix": "<hostPrefix>",
 "prefixId": "tibc",
 "generateIAT": true,
 "tenantSubscriptionDetails": [
   {
     "eula": true,
     "region": "global",
     "expiryInMonths": -1,
     "planId": "TIB_CLD_ADMIN_TIB_CLOUDOPS",
     "tenantId": "ADMIN",
     "seats": {
       "ADMIN": { "ENGR": -1, "PM": -1, "SUPT": -1, "OPS": -1, "PROV": -1, "TSUPT": -1 }
     }
   }
 ],
 "skipEmail": false
}
```


**Sample Response:**


```json
{
 "accountId": "<accountId>",
 "subscriptionId": "<subscriptionId>",
 "userEntityId": "<userEntityId>",
 "iat": {
   "id": "<iat-id>",
   "accessToken": "<initial-access-token>",
   "createdBy": "<userEntityId>",
   "createdTime": "<epoch>",
   "expiryTime": "<epoch>",
   "tenantId": "TSC",
   "comment": "Generate IAT for ADMIN subscription"
 }
}
```


---


### Step 2 — Register OAuth2 Client (ADMIN)


Registers an OAuth2 client under the ADMIN subscription using the IAT.


```
POST {BASE_URL}/idm/v1/oauth2/clients
```


**Auth:** `Authorization: Bearer <initial-access-token>`


**Request Body** (form-urlencoded):


| Field | Value |
|-------|-------|
| `client_name` | `admin-client` |
| `scope` | `ADMIN` |
| `token_endpoint_auth_method` | `client_secret_basic` |


**Sample Response:**


```json
{
 "client_id": "<client-id>",
 "client_secret": "<client-secret>",
 "client_name": "admin-client",
 "scope": "ADMIN",
 "token_endpoint_auth_method": "client_secret_basic"
}
```


---


### Step 3 — Revoke Initial Access Token (ADMIN)


Revokes the one-time IAT after the OAuth2 client is registered.


```
DELETE {BASE_URL}/idm/v1/oauth2/clients/initial-token
```


**Auth:** `Authorization: Bearer <initial-access-token>`


**Sample Response:**


```json
{
 "message": "Successfully revoked initial access_token sent in Authorization header as Bearer token"
}
```


---


### Step 4 — OAuth2 Token Exchange (ADMIN)


Exchanges OAuth2 client credentials for an ADMIN access token.


```
POST {BASE_URL}/idm/v1/oauth2/token
```


**Auth:** HTTP Basic (`client-id:client-secret`)


**Request Body** (form-urlencoded):


| Field | Value |
|-------|-------|
| `grant_type` | `client_credentials` |
| `scope` | `ADMIN` |


**Sample Response:**


```json
{
 "access_token": "<access-token>",
 "token_type": "Bearer",
 "expires_in": 28800,
 "scope": "ADMIN"
}
```


> Access tokens expire in 8 hours (28800 seconds).


#### Verify ADMIN Token — Who Am I


```
GET {BASE_URL}/admin/v1/whoami
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Sample Response:**


```json
{
 "email": "<email>",
 "rol": [
   "SRE"
 ],
 "firstName": "<firstName>",
 "lastName": "<lastName>",
 "region": "global",
 "auth": "client_credentials"
}
```


---


### Step 5 — Generate Self-Signed Certificate


Generates a self-signed SAML service provider certificate. Use this API if your IdP configuration requires a self-signed SP certificate. The returned `alias` should be referenced in the `serviceProviderCerts` array when configuring the external IdP in Step 6.


```
POST {BASE_URL}/platform-console/api/v1/idps/sp-certs/generate
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Request Body:**


```json
{
 "expiryTime": "<expiryEpoch>",
 "hostPrefix": "<hostPrefix>"
}
```


**Sample Response:**


```json
{
 "status": "success",
 "response": {
   "alias": "<cert-alias>",
   "cert": "<base64-encoded-certificate>"
 }
}
```


---


### Step 6 — Configure External IdP


Configures a SAML-based external Identity Provider for the ADMIN subscription.


```
POST {BASE_URL}/platform-console/api/v1/idps/{hostPrefix}
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Request Body:**


```json
{
 "type": "SAML",
 "accountId": "<accountId>",
 "status": "CONFIGURED",
 "metadataURL": "",
 "metadataDetails": "",
 "knownGroups": ["<group-name>"],
 "comment": "Configured via automation",
 "metadata": {
   "isSAMLRequestSigned": true,
   "isSAMLAssertionEncrypted": false,
   "signatureAlgorithmToUse": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
   "spId": "<saml-sp-entity-id>",
   "idpId": "<saml-idp-id>",
   "loginUrl": "<saml-login-url>",
   "loginBinding": "POST",
   "logoutUrl": "",
   "logoutBinding": "",
   "trustedCertsPem": [
     "<base64-encoded-idp-certificate>"
   ],
   "serviceProviderCerts": [
     {
       "alias": "<cert-alias>",
       "active": true
     }
   ],
   "attributeMappings": {
     "email": "email",
     "firstName": "firstName",
     "lastName": "lastName",
     "subject": "subject"
   }
 }
}
```


**Sample Response:**


```json
{
 "status": "success",
 "response": {
   "accountId": "<accountId>",
   "requestedBy": "",
   "prefixId": "<prefixId>",
   "type": "SAML",
   "metadata": {
     "attributeMappings": {
       "email": "email",
       "firstName": "firstName",
       "lastName": "lastName",
       "subject": "subject"
     },
     "idpId": "<saml-idp-id>",
     "isAttributesCaseInSensitive": false,
     "isSAMLAssertionEncrypted": false,
     "isSAMLRequestSigned": true,
     "loginBinding": "POST",
     "loginUrl": "<saml-login-url>",
     "logoutBinding": "",
     "logoutUrl": "",
     "nameIdPolicy": {
       "allowCreate": false,
       "format": "",
       "sPNameQualifier": ""
     },
     "serviceProviderCerts": [
       {
         "active": true,
         "alias": "<cert-alias>",
         "cert": "<base64-encoded-sp-certificate>"
       }
     ],
     "signatureAlgorithmToUse": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
     "spId": "<saml-sp-entity-id>",
     "trustedCertsPem": [
       "<base64-encoded-idp-certificate>"
     ],
     "updatedBy": "<user-guid>"
   },
   "knownGroups": [
     "<group-name>"
   ],
   "isEnabled": false,
   "updatedOnInMSec": 0,
   "enabledOnInMSec": 0
 },
 "context": [
   "<timestamp>"
 ]
}
```


#### Get Subscription Details


```
GET {BASE_URL}/platform-console/api/v1/subscriptions?hostPrefix={hostPrefix}
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Sample Response:**


```json
{
 "status": "success",
 "response": {
   "totalRecordsInTable": 1,
   "totalRecords": 1,
   "data": [
     {
       "account_comment": null,
       "created_time": "<epoch>",
       "data_planes": null,
       "display_name": "<organizationName>",
       "dp_count": 0,
       "dp_soft_limit": 10,
       "email": "<email>",
       "end_of_contract_time": 0,
       "external_account_id": "",
       "external_subscription_id": "<externalSubscriptionId>",
       "firstname": "<firstName>",
       "host_prefix": "<hostPrefix>",
       "lastname": "<lastName>",
       "owner_limit": 20,
       "soft_limit": null,
       "start_of_contract_time": 0,
       "status": "active",
       "subscription_id": "<subscriptionId>",
       "subscription_type": "TIB",
       "tsc_account_id": "<accountId>"
     }
   ]
 },
 "context": [
   "<timestamp>"
 ]
}
```


#### Get IdP Details


```
GET {BASE_URL}/platform-console/api/v1/idps/{hostPrefix}
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Sample Response:**


```json
{
 "status": "success",
 "response": [
   {
     "hostPrefix": "<hostPrefix>",
     "accountId": "<accountId>",
     "requestedBy": "<user-guid>",
     "prefixId": "<prefixId>",
     "type": "SAML",
     "status": "CONFIGURED",
     "metadata": {
       "isSAMLRequestSigned": true,
       "signatureAlgorithmToUse": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
       "isSAMLAssertionEncrypted": false,
       "spId": "<saml-sp-entity-id>",
       "idpId": "<saml-idp-id>",
       "loginUrl": "<saml-login-url>",
       "loginBinding": "POST",
       "logoutUrl": "",
       "logoutBinding": "",
       "attributeMappings": {
         "email": "email",
         "firstName": "firstName",
         "lastName": "lastName",
         "subject": "subject"
       },
       "isAttributesCaseInSensitive": false,
       "trustedCertsPem": [
         "<base64-encoded-idp-certificate>"
       ],
       "serviceProviderCerts": [
         {
           "alias": "<cert-alias>",
           "cert": "<base64-encoded-sp-certificate>",
           "active": true
         }
       ],
       "nameIdPolicy": {
         "format": "",
         "allowCreate": false,
         "sPNameQualifier": ""
       },
       "updatedBy": "<user-guid>"
     },
     "metadataURLDetails": {},
     "spMetadata": "<saml-sp-metadata-xml>",
     "knownGroups": [
       "<group-name>"
     ],
     "comment": "Configured via automation",
     "knownGroupKeyValues": {},
     "metadataURL": "",
     "metadataDetails": "",
     "updatedOnInMSec": "<epochMillis>",
     "enabledOnInMSec": 0
   }
 ],
 "context": [
   "<timestamp>"
 ]
}
```


> **Note:** The `spMetadata` field contains the full SAML SP metadata XML document including the entity descriptor, signature, key descriptors, assertion consumer service URL, and attribute consuming service definitions.


---


### Step 7 — Create CP Subscription


Creates a new Cloud Platform subscription under the ADMIN account. Set `copyAdminIdP` to `true` to clone the IdP configuration from the ADMIN subscription to the new CP subscription; set it to `false` to skip IdP cloning.


```
POST {BASE_URL}/platform-console/api/v1/subscriptions
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Request Body:**


```json
{
 "userDetails": {
   "firstName": "<firstName>",
   "lastName": "<lastName>",
   "email": "<cpEmail>",
   "initialPassword": "<cpPassword>",
   "country": "US",
   "state": "NC"
 },
 "accountDetails": {
   "companyName": "<companyName>",
   "ownerLimit": 10,
   "hostPrefix": "<cpHostPrefix>",
   "comment": "Provisioned via automation"
 },
 "generateIAT": true,
 "copyAdminIdP": "<true if ADMIN is configured with IdP, false otherwise>",
 "userRoles": ["*"],
 "useDefaultIDP": true,
 "customContainerRegistry": false
}
```


**Sample Response:**


```json
{
 "status": "success",
 "response": {
   "code": "ATMOSPHERE-11088",
   "status": "success",
   "message": "CPASS provisioning successfully completed.",
   "details": {
     "provisioningDetails": {
       "subscriptionId": "<subscriptionId>",
       "accountId": "<cpAccountId>",
       "userEntityId": "<userEntityId>",
       "subscriptionUrl": "<cpHostPrefix>.<domain>"
     },
     "tenantStatus": [
       {
         "tenantId": "TP",
         "planId": "TIB_CLD_TP_PAID_CPASS",
         "status": "success",
         "action": "NEW"
       }
     ]
   },
   "summary": {
     "pendingAction": "No action"
   },
   "subIdProvStatus": "committed",
   "iat": {
     "id": "<iat-id>",
     "accessToken": "<cp-initial-access-token>",
     "createdBy": "<userEntityId>",
     "createdTime": "<epoch>",
     "expiryTime": "<epoch>",
     "tenantId": "TSC",
     "comment": "Generate IAT for Control-Plane subscription"
   }
 },
 "context": [
   "<timestamp>"
 ]
}
```


#### Verify CP Subscription Details


```
GET {BASE_URL}/platform-console/api/v1/subscriptions?hostPrefix=<cpHostPrefix>
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Sample Response:**


```json
{
 "status": "success",
 "response": {
   "totalRecordsInTable": 1,
   "totalRecords": 1,
   "data": [
     {
       "account_comment": null,
       "created_time": "<epoch>",
       "data_planes": null,
       "display_name": "<companyName>",
       "dp_count": 0,
       "dp_soft_limit": 10,
       "email": "<cpEmail>",
       "end_of_contract_time": "<epoch>",
       "external_account_id": "",
       "external_subscription_id": "<externalSubscriptionId>",
       "firstname": "<firstName>",
       "host_prefix": "<cpHostPrefix>",
       "lastname": "<lastName>",
       "owner_limit": 10,
       "soft_limit": null,
       "start_of_contract_time": "<epoch>",
       "status": "active",
       "subscription_id": "<subscriptionId>",
       "subscription_type": "CPASS",
       "tsc_account_id": "<cpAccountId>"
     }
   ]
 },
 "context": [
   "<timestamp>"
 ]
}
```


#### Verify CP IdP Details


```
GET {BASE_URL}/platform-console/api/v1/idps/<cpHostPrefix>
```


**Auth:** `Authorization: Bearer <admin-access-token>`


**Sample Response:**


```json
{
 "status": "success",
 "response": [
   {
     "hostPrefix": "<cpHostPrefix>",
     "accountId": "<cpAccountId>",
     "requestedBy": "<user-guid>",
     "prefixId": "<prefixId>",
     "type": "SAML",
     "status": "CONFIGURED",
     "metadata": {
       "isSAMLRequestSigned": true,
       "signatureAlgorithmToUse": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
       "isSAMLAssertionEncrypted": false,
       "spId": "<saml-sp-entity-id>",
       "idpId": "<saml-idp-id>",
       "loginUrl": "<saml-login-url>",
       "loginBinding": "POST",
       "logoutUrl": "",
       "logoutBinding": "",
       "attributeMappings": {
         "email": "email",
         "firstName": "firstName",
         "lastName": "lastName",
         "subject": "subject"
       },
       "isAttributesCaseInSensitive": false,
       "trustedCertsPem": [
         "<base64-encoded-idp-certificate>"
       ],
       "serviceProviderCerts": [
         {
           "alias": "<cert-alias>",
           "cert": "<base64-encoded-sp-certificate>",
           "active": true
         }
       ],
       "nameIdPolicy": {
         "format": "",
         "allowCreate": false,
         "sPNameQualifier": ""
       },
       "updatedBy": "<user-guid>"
     },
     "metadataURLDetails": {},
     "spMetadata": "<saml-sp-metadata-xml>",
     "knownGroups": [
       "<group-name>"
     ],
     "comment": "Cloned from hostPrefix: <adminHostPrefix>",
     "knownGroupKeyValues": {},
     "metadataURL": "",
     "metadataDetails": "",
     "updatedOnInMSec": "<epochMillis>",
     "enabledOnInMSec": 0
   }
 ],
 "context": [
   "<timestamp>"
 ]
}
```


> **Note:** The `spMetadata` field contains the full SAML SP metadata XML document. It is the same structure as the ADMIN IdP but with the CP subscription's ACS callback URL.


---


### Step 8 — Register OAuth2 Client (CP) & Revoke CP IAT


Registers an OAuth2 client under the CP subscription and revokes the CP IAT.


#### Register CP Client


```
POST https://{CP_SUB_URL}/idm/v1/oauth2/clients
```


**Auth:** `Authorization: Bearer <cp-initial-access-token>`


**Request Body** (form-urlencoded):


| Field | Value |
|-------|-------|
| `client_name` | `cp-client` |
| `scope` | `TSC` |
| `token_endpoint_auth_method` | `client_secret_basic` |


**Sample Response:**


```json
{
 "client_id": "<cp-client-id>",
 "client_secret": "<cp-client-secret>",
 "client_name": "cp-client",
 "scope": "TSC",
 "token_endpoint_auth_method": "client_secret_basic"
}
```


#### Revoke CP IAT


```
DELETE https://{CP_SUB_URL}/idm/v1/oauth2/clients/initial-token
```


**Auth:** `Authorization: Bearer <cp-initial-access-token>`


**Sample Response:**


```json
{
 "message": "Successfully revoked initial access_token sent in Authorization header as Bearer token"
}
```


---


### Step 9 — OAuth2 Token Exchange (CP) & Verify


Exchanges CP OAuth2 client credentials for an access token and verifies it.


#### Token Exchange


```
POST https://{CP_SUB_URL}/idm/v1/oauth2/token
```


**Auth:** HTTP Basic (`cp-client-id:cp-client-secret`)


**Request Body** (form-urlencoded):


| Field | Value |
|-------|-------|
| `grant_type` | `client_credentials` |
| `scope` | `TSC` |


**Sample Response:**


```json
{
 "access_token": "<cp-access-token>",
 "token_type": "Bearer",
 "expires_in": 28800,
 "scope": "TSC"
}
```


#### Verify CP Token — Who Am I


```
GET https://{CP_SUB_URL}/cp/v1/whoami
```


**Auth:** `Authorization: Bearer <cp-access-token>`


**Sample Response:**


```json
{
 "email": "<cpEmail>",
 "firstName": "<firstName>",
 "lastName": "<lastName>",
 "accounts": [
   "<cpAccountId>"
 ],
 "account": "<cpAccountId>",
 "guid": "<user-guid>",
 "admn": true,
 "gsbc": "<subscriptionId>",
 "scope": "",
 "sexp": {
   "TP": "<expiryEpoch>"
 },
 "aud": [
   "TSC",
   "TSC.global"
 ],
 "regn": "global",
 "auth": "client_credentials",
 "eula": true,
 "rol": [
   "TEAM_ADMIN",
   "BROWSE_ASSIGNMENTS",
   "PLATFORM_OPS",
   "DEV_OPS",
   "CAPABILITY_ADMIN",
   "CAPABILITY_USER",
   "OWNER",
   "IDP_MANAGER"
 ],
 "hprfx": "<cpHostPrefix>",
 "accountsLength": 1
}
```


## Token Renewal


Access tokens expire in 8 hours. After provisioning completes, regenerate with:


**ADMIN token:**


```bash
curl -s -X POST '{BASE_URL}/idm/v1/oauth2/token' \
    -u '<ADMIN_CLIENT_ID>:<ADMIN_CLIENT_SECRET>' \
    -d 'grant_type=client_credentials&scope=ADMIN'
```


**CP token:**


```bash
curl -s -X POST 'https://<CP_SUB_URL>/idm/v1/oauth2/token' \
    -u '<CP_CLIENT_ID>:<CP_CLIENT_SECRET>' \
    -d 'grant_type=client_credentials&scope=TSC'
```


The example script prints the exact commands with your credentials at the end of a successful run.


## Example Script


An example automation script (`api-based-automation.sh`) is provided that implements the full provisioning workflow described in the API Reference above.


### Prerequisites


- **bash** 4.0+
- **curl**
- **jq**
- A running TIBCO Platform Console instance


### Quick Start


```bash
chmod +x api-based-automation.sh


./api-based-automation.sh \
   --base-url https://admin.cp1-my.example.com \
   --admin-email admin@example.com \
   --admin-initial-password 'yourPassword'
```


Or using environment variables:


```bash
export CP_BASE_URL=https://admin.cp1-my.example.com
export CP_ADMIN_EMAIL=admin@example.com
export CP_ADMIN_INITIAL_PASSWORD='yourPassword'


./api-based-automation.sh
```


### Configuration


All parameters accept both CLI flags and environment variables. CLI flags take precedence.


| Flag | Env Variable | Default | Description |
|------|-------------|---------|-------------|
| `--base-url` | `CP_BASE_URL` | *(required)* | TIBCO Platform Console base URL |
| `--admin-email` | `CP_ADMIN_EMAIL` | *(required)* | Admin email for basic auth |
| `--admin-initial-password` | `CP_ADMIN_INITIAL_PASSWORD` | *(required)* | Admin initial password for basic auth |
| `--admin-first-name` | `CP_ADMIN_FIRST_NAME` | `Admin` | Admin first name |
| `--admin-last-name` | `CP_ADMIN_LAST_NAME` | `User` | Admin last name |
| `--admin-host-prefix` | `CP_ADMIN_HOST_PREFIX` | `admin` | Admin host prefix |
| `--cp-email` | `CP_SUB_EMAIL` | same as admin-email | CP subscription owner email |
| `--cp-initial-password` | `CP_SUB_INITIAL_PASSWORD` | `changeMe@1` | CP subscription owner initial password |
| `--cp-first-name` | `CP_FIRST_NAME` | `Admin` | CP owner first name |
| `--cp-last-name` | `CP_LAST_NAME` | `User` | CP owner last name |
| `--cp-company` | `CP_COMPANY` | `acme` | Company name |
| `--cp-host-prefix` | `CP_HOST_PREFIX` | `acme` | Host prefix for subscription URL |
| `--idp-config` | `CP_IDP_CONFIG` | *(skipped)* | External IdP configuration body as JSON string. If not provided, steps 5 and 6 are skipped |
| `--curl-timeout` | `CP_CURL_TIMEOUT` | `30` | HTTP request timeout in seconds |
| `--verbose` | `VERBOSE=true` | `false` | Enable debug output |


### Script Help


```
NAME
    api-based-automation.sh - Automate TIBCO Platform provisioning with IdP configuration

SYNOPSIS
    api-based-automation.sh --base-url <URL> --admin-email <EMAIL> --admin-initial-password <PASSWORD> [OPTIONS]

REQUIRED
    --base-url <URL>            Platform Console base URL
                                (env: CP_BASE_URL)
    --admin-email <EMAIL>       Admin email for basic auth
                                (env: CP_ADMIN_EMAIL)
    --admin-initial-password <PASSWORD> Admin initial password for basic auth
                                (env: CP_ADMIN_INITIAL_PASSWORD)

OPTIONS
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

EXAMPLES
    # Minimal invocation
    api-based-automation.sh \
        --base-url https://admin.cp1-my.example.com \
        --admin-email admin@example.com \
        --admin-initial-password 's3cret!'

    # Using environment variables
    export CP_BASE_URL=https://admin.cp1-my.example.com
    export CP_ADMIN_EMAIL=admin@example.com
    export CP_ADMIN_INITIAL_PASSWORD='s3cret!'
    api-based-automation.sh

    # Full customization
    api-based-automation.sh \
        --base-url https://admin.cp1-my.example.com \
        --admin-email admin@example.com \
        --admin-initial-password 's3cret!' \
        --cp-email owner@example.com \
        --cp-initial-password 'Own3rP@ss' \
        --cp-first-name Jane \
        --cp-last-name Doe \
        --cp-company Acme \
        --cp-host-prefix acme \
        --verbose
```


## Troubleshooting


| Symptom | Cause | Fix |
|---------|-------|-----|
| `HTTP 401` on init | Wrong admin email/password | Verify `--admin-email` and `--admin-initial-password` |
| `HTTP 409` on init | Platform already initialized | The ADMIN subscription already exists |
| `HTTP 409` on subscription | Host prefix taken | Use a different `--cp-host-prefix` |
| `HTTP 401` on token exchange | Wrong client credentials | Re-run from the beginning; previous IAT may have expired |
| `HTTP 201` but cert alias is null | Invalid expiry time | Verify `expiryTime` in the cert generation request is a valid future epoch |
| `HTTP 4xx` on IdP config | Invalid SAML metadata | Check `--idp-config` JSON: certificate PEM, login URL, and attribute mappings |
| `curl: connection refused` | Platform not running | Verify `--base-url` and that the platform is accessible |
| `jq: command not found` | Missing dependency | Install jq: `apt install jq` / `brew install jq` |
