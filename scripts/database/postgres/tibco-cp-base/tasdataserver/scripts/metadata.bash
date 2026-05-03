#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

## To support multiple deployments of TAS in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}tctadataserver"
PGUSER="${DB_PREFIX}tctadataserveruser"
CREATE_UUID_OSSP_EXTENSION=true

PREVIOUS_VERSION=6
CURRENT_VERSION=7
