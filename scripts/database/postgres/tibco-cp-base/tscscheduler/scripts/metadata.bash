#!/bin/bash

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}tscschedulerdb"
PGUSER="${DB_PREFIX}tscscheduleruser"

PREVIOUS_VERSION=1
CURRENT_VERSION=1