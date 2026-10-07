-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------
-- Database schema changes for 1.21
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

-- PCP-24148 (1.21): index the per-user / per-account access-token lookup that runs on every
-- token-generation request. PCP-19817 moved the USER_ENTITY_ID / TSC_ACCOUNT_ID predicates out
-- of the COUNT(CASE WHEN ...) expressions into a real WHERE clause, so the query can now be
-- served by an index -- but no index leads with those columns. Both candidates bury the pair
-- behind a column the query does not constrain: the primary key is
-- (ACCESS_TOKEN, USER_ENTITY_ID, TENANT_ID) and OAUTH2_ACCESS_TOKENS_UNIQUE is
-- (ACCESS_TOKEN_NAME, USER_ENTITY_ID, TSC_ACCOUNT_ID, TENANT_ID, REGION). Neither is a usable
-- btree prefix, and ACCESS_TOKEN_NAME is nullable so it is a poor skip-scan candidate too, which
-- leaves the planner applying both predicates as a Filter over a scan of the whole index.
--
-- CONCURRENTLY, and why it is safe on THIS path: OAUTH2_ACCESS_TOKENS is hot, so the
-- ACCESS EXCLUSIVE lock a plain CREATE INDEX takes would stall every token read and write for
-- the duration of the build. n-up.sql files (n >= 2) are applied by upgradeDBSchema in
-- postgres-helper.bash as `psql -f <file> -v ON_ERROR_STOP=1` with NO --single-transaction, and
-- the runner only prepends `SET ROLE ...;` and `SET search_path ...;` -- both plain statements --
-- so psql autocommits and CONCURRENTLY is not inside a transaction block.
-- DO NOT move this into 1-up.sql: createTables runs that file WITH --single-transaction
-- (PCP-20008), where CONCURRENTLY fails outright and would break every fresh install. Fresh
-- installs still get this index -- they run 1-up.sql and then replay 2..n through this same
-- unwrapped upgrade loop.
--
-- The DROP is the retry guard, and it must stay a top-level statement. A CONCURRENTLY build that
-- fails or is killed leaves an INVALID index behind; ON_ERROR_STOP=1 then aborts this file before
-- the SCHEMA_VERSION bump, so the Job retries and replays it. Without the DROP, IF NOT EXISTS
-- would match that invalid leftover, skip the rebuild, and still bump the version -- a green
-- migration with an index the planner will never use. This cannot be expressed as a conditional
-- DO block: PL/pgSQL runs inside an implicit transaction, so neither CREATE nor DROP ...
-- CONCURRENTLY is permitted there. On a normal first run the DROP is a no-op NOTICE; if this
-- file is ever replayed on a DB already at version 10 (RERUN_CURRENT_UPGRADE=true) the DROP+CREATE
-- rebuilds the index by design -- both concurrent, so the rebuild never takes an ACCESS EXCLUSIVE
-- lock, though the query is briefly un-indexed until the CREATE completes.
DROP INDEX CONCURRENTLY IF EXISTS idx_oauth2_access_tokens_user_account;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oauth2_access_tokens_user_account
    ON OAUTH2_ACCESS_TOKENS (USER_ENTITY_ID, TSC_ACCOUNT_ID);

-- Update database schema at the end (earlier version is 9)
UPDATE SCHEMA_VERSION SET version = 10;
