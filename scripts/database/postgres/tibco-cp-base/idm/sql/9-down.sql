-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------------------------------
-- Rollback database schema changes for PCP-21466 follow-up (reverse of 9-up.sql).
--
-- 9-up.sql only WIDENED OAUTH2_ACCESS_TOKENS.SESSION_INDEX (VARCHAR(96) -> VARCHAR(255)),
-- which is a backward-compatible, non-breaking change. We intentionally DO NOT shrink the
-- column back to VARCHAR(96) on rollback:
--   * a shrink would FAIL if any row already holds a value longer than 96 chars - exactly the
--     values 9-up.sql was added to allow (63-char host prefix + long SAML sessionIndex), and
--   * ALTER ... TYPE to a smaller length forces a full table rewrite + hash-index rebuild under
--     an ACCESS EXCLUSIVE lock on the hot OAUTH2_ACCESS_TOKENS table.
-- Leaving the column at VARCHAR(255) is harmless - a wider column accepts every value the
-- narrower one did - so rollback stays safe and instantaneous. Only the schema version is rolled
-- back here; a later re-upgrade re-runs 9-up.sql, an idempotent no-op on the already-wide column.
---------------------------------------------------------------------------

-- Roll back database schema version (going from 9 back to 8)
UPDATE SCHEMA_VERSION SET version = 8;
