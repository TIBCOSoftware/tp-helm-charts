#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

## To support multiple deployments of TSC in same EKS cluster WHO and TENANT_SUFFIX is added.
## To avoid the postgres syntax errors for '-' character, all the '-' converted to '_' for WHO / TENANT_SUFFIX values.

PGDATABASE="${DB_PREFIX}mcphubdb"
PGUSER="${DB_PREFIX}mcphubuser"

# PCP-24560: 6 -> 7 (DATA, not DDL: rewrite RetryWithBackoffPlugin bindings stuck in the legacy
#   'enforce' blocking token to 'transform'. The plugin cannot produce a deny, so PCP-23515's
#   attach default mis-blocked it; it was added to the non-gating catalog after version 2 shipped,
#   so its data correction needs its own file — same shape as 2-up.sql PART B, one plugin).
# PCP-24963: 5 -> 6 (CP_SERVERS INJECTABLE_HEADERS — the per-server allow-list of header NAMES
#   a gateway plugin may inject onto the upstream request. Nullable with NO DEFAULT, breaking
#   the CP_SERVERS house style on purpose: NULL "never declared" and '[]' "explicitly revoked"
#   are opposite instructions to a gateway whose guard is `is not None`).
# PCP-24759 (AC 5): 4 -> 5 (GATEWAYS RUNTIME_HEALTH + observation time/error, DESIRED_ and
#   APPLIED_CONFIG_REVISION — health and applied configuration, separated from liveness).
# PCP-24759: 3 -> 4 (GATEWAYS BUSINESS_TYPE + GATEWAY_KIND — the gateway product pair).
# PCP-24482: 2 -> 3 (GATEWAYS reported_* version columns + PLACEMENT).
# ⚠️ NEITHER VALUE REACHES THE APPLY LOOP. Both are overwritten before it runs:
#   PREVIOUS_VERSION — upgradeDBSchema reads it from the live DB (`SELECT VERSION FROM
#     …SCHEMA_VERSION`), forcing 1 when that read is empty; rollbackDBSchema and the dispatcher
#     do the same.
#   CURRENT_VERSION  — runManualSchemaAction and manageDbSchemaCommand each `unset` it, source
#     this file, then `export` it from the version-map resolution.
# What CURRENT_VERSION IS load-bearing for is invariant 1 in
# scripts/database/tests/migration-invariants.bats, which asserts it equals the highest N-up.sql
# shipped here. PREVIOUS_VERSION is checked by nothing; it is kept in step by convention, as
# every peer service's metadata.bash does.
#
# ⚠️ DO NOT RE-DERIVE THE OLD CLAIM that leaving a value behind would make the loop re-run the
# previous N-up.sql — it reads plausibly, it is false, and it has now been written here twice.
#
# (Symbols, not line offsets, deliberately: an offset drifts on the next edit above it and
# nothing fails. Grep the function names.)
PREVIOUS_VERSION=6
CURRENT_VERSION=7
