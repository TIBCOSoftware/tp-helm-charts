-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback of schema version 4 (PCP-24759) — back to version 3.
--
-- ⚠️ THIS DELIBERATELY DOES NOT DROP THE COLUMNS, following 3-down.sql. Here that is not only
-- the standard "additive columns are retained until every new revision is gone" rule — for
-- THESE two columns dropping them would be actively destructive, which is worth spelling out
-- because the usual argument for retention is merely that it is harmless.
--
-- 1. The ordinary reason, from 3-down.sql: a rollback exists to get a CP running again, and
--    the realistic sequence leaves some Hub pods already on the new image. Dropping a column
--    they name would raise 42703 on the next dial-home `hello`, and that error closes the
--    control-channel socket — turning a cosmetic problem into every dial-home gateway
--    disconnecting.
--
-- 2. ⭐ THE REASON SPECIFIC TO THIS PAIR. BUSINESS_TYPE / GATEWAY_KIND are a SECURITY
--    DISCRIMINATOR, and the Hub's compatibility rule is "both columns verifiably absent =>
--    treat the row as mcp/A". So dropping them does not merely lose information: an `llm` row
--    would read back as a legacy MCP gateway and become eligible for ContextForge push, pull,
--    plugin, tool and inventory operations. The rollback would silently undo the isolation the
--    columns exist to provide. Retention is what prevents that.
--
-- ⇒ IF THESE COLUMNS MUST GENUINELY BE REMOVED — a schema audit, not a rollback — that is its
-- own migration, and it MUST first establish that no row is anything other than mcp/A. Do not
-- write a bare DROP: for every other retained column a stray DROP is untidy, for these two it
-- is a security regression.
--
-- ⚠️ AND NOTHING WILL STOP YOU, WHICH IS WHY IT IS SPELLED OUT HERE. Two measured gaps, both
-- documented in scripts/database/tests/migration-invariants.bats:
--   - down files are NOT in the sha256 pin set (`_required_pins` is up-only, because the pin
--     models tp-mcp-hub's pg-migrate.ts whose scan is /^(\d+)-up\.sql$/). Extending the freeze
--     to down files is tracked on PCP-24857 and is not decided here.
--   - invariant 8 checks only that this FILE EXISTS. Nothing reads its contents, so a body
--     that drops columns — or an empty one — passes CI unchanged.
-- Meanwhile postgres-helper.bash's manageDbSchemaCommand calls persist_all_down_sql_to_efs on
-- every successful run, copying this file from the image over the EFS copy a rollback actually
-- executes. So a later edit adding DROPs here would become rollback-LIVE, silently, with no
-- check anywhere comparing it. Getting this body right is on the author and the reviewer.
--
-- What this file DOES do is move the version marker back, which is what the upgrade loop keys
-- on: a database at 3 re-runs 4-up.sql on the next upgrade, and every statement there is
-- idempotent (`ADD COLUMN IF NOT EXISTS`), so re-applying over retained columns is a no-op.
--
-- ⚠️ ONE THING THIS FILE CANNOT FIX, stated so nobody assumes it does. Rolling the HUB IMAGE
-- back to a revision that predates the runtime dispatcher means there is no dispatcher, so an
-- `llm` row on that revision is handled by code that only knows ContextForge. No schema file
-- can repair that; it is inherent to rolling back past the feature. Quarantine or remove
-- non-mcp/A rows before rolling the Hub image back that far.

BEGIN;

-- See the note in 4-up.sql: UPDATE, never INSERT — postgres-helper.bash reads this with a bare
-- single-value SELECT and whitespace-strips the result, so a second row breaks the version gate.
UPDATE SCHEMA_VERSION SET VERSION = 3;

COMMIT;
