#!/bin/bash

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}tscutdb"
PGUSER="${DB_PREFIX}tscutuser"

PREVIOUS_VERSION=15
CURRENT_VERSION=16
