#!/bin/bash

## To support multiple deployments of TAS in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}tctadomainserver"
PGUSER="${DB_PREFIX}tctadomainserveruser"

PREVIOUS_VERSION=1
CURRENT_VERSION=3
