#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}monitoringdb"
PGUSER="${DB_PREFIX}monitoringuser"

PREVIOUS_VERSION=5
CURRENT_VERSION=6
