#!/bin/bash

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}rtmon"
PGUSER="${DB_PREFIX}rtmonadm"
CREATE_UUID_OSSP_EXTENSION=true

PREVIOUS_VERSION=1
CURRENT_VERSION=2

# Define a custom schema name for this service
PGSCHEMA="redtail_ct_info"