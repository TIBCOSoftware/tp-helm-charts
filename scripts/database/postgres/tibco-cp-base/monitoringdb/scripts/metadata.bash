#!/bin/bash

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}monitoringdb"
PGUSER="${DB_PREFIX}monitoringuser"

PREVIOUS_VERSION=2
CURRENT_VERSION=3
