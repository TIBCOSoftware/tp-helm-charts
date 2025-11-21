#!/bin/bash

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}tscidmdb"
PGUSER="${DB_PREFIX}tscidmuser"
CREATE_UUID_OSSP_EXTENSION=true

PREVIOUS_VERSION=6
CURRENT_VERSION=6
