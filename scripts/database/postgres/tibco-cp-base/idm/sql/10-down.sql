-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------------------------------
-- Rollback database schema changes for PCP-24148 (reverse of 10-up.sql).
--
-- 10-up.sql only ADDED an index. An index is purely a planner aid -- no data, constraint or
-- column shape depends on it -- so the rollback is a straight drop with nothing to preserve.
-- CONCURRENTLY here for the same reason as the forward migration: downgradeDBSchema also runs
-- down files as `psql -f <file> -v ON_ERROR_STOP=1` with no --single-transaction, so DROP INDEX
-- CONCURRENTLY is permitted, and it keeps a rollback -- the worst possible moment for a stall --
-- off the ACCESS EXCLUSIVE lock on the hot OAUTH2_ACCESS_TOKENS table.
-- IF EXISTS keeps this a no-op when the forward build never completed.
---------------------------------------------------------------------------

DROP INDEX CONCURRENTLY IF EXISTS idx_oauth2_access_tokens_user_account;

-- Roll back database schema version (going from 10 back to 9)
UPDATE SCHEMA_VERSION SET version = 9;
