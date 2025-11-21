#!/bin/bash

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}penginedb"
PGUSER="${DB_PREFIX}pengineuser"

PREVIOUS_VERSION=3
CURRENT_VERSION=3
