-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------------------------------
-- Rollback database schema changes for PCP-18744 (reverse of 8-up.sql).
-- Drops the orphan-IAT cleanup trigger, its function, and the
-- INITIAL_ACCESS_TOKEN_REVOKED column, restoring the pre-8 (version 7) schema.
--
-- Drop order matters: the trigger depends on the function, and the function
-- body reads OAUTH2_CLIENTS.INITIAL_ACCESS_TOKEN_REVOKED, so we drop
-- trigger -> function -> column.
--
-- NOTE: the one-time data backfill in 8-up.sql (deleted INITIAL_ACCESS_TOKENS
-- rows) is intentionally NOT reverted here - that data is not restorable.
---------------------------------------------------------------------------

-- 1. Drop the trigger first (depends on the function)
DROP TRIGGER IF EXISTS CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN_TRIGGER ON OAUTH2_ACCESS_TOKENS;

-- 2. Then drop the function (reads the column dropped in step 3)
DROP FUNCTION IF EXISTS CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN() CASCADE;

-- 3. Then drop the column added in 8-up.sql
ALTER TABLE OAUTH2_CLIENTS
    DROP COLUMN IF EXISTS INITIAL_ACCESS_TOKEN_REVOKED;

-- 4. PCP-21466: Revert the IDP_DETAILS.HOST_PREFIX relaxation from 8-up.sql.
--    WARNING: shrinking HOST_PREFIX back to VARCHAR(32) will FAIL if any row
--    holds a value longer than 32 characters (only possible once 8-up.sql has
--    allowed 33-63 char prefixes). Such rows must be shortened or removed first.
ALTER TABLE IDP_DETAILS DROP CONSTRAINT IF EXISTS host_prefix_valid_check;
ALTER TABLE IDP_DETAILS ALTER COLUMN HOST_PREFIX TYPE VARCHAR(32);

-- Roll back database schema version (going from 8 back to 7)
UPDATE SCHEMA_VERSION SET version = 7;
