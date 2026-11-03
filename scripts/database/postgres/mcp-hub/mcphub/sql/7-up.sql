-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Schema version 7 (PCP-24560) — DATA: one more plugin binding stuck in a blocking mode.
--
-- This is the exact shape of 2-up.sql's PART B (PCP-23515), applied to ONE additional plugin:
-- RetryWithBackoffPlugin. It re-invokes the tool on retry-eligible status codes and, once
-- max_retries is exhausted, hands back the ORIGINAL failed result — it never returns
-- continue_processing=False and never returns a deny decision payload, so it cannot produce a
-- deny in any mode. PCP-23515's attach default nonetheless placed it in the legacy 'enforce'
-- token (the gateway resolves it to the BLOCKING canonical mode 'sequential'), because
-- RetryWithBackoff was NOT in the non-gating set at the time. A binding's mode is written once
-- at attach time and never recomputed, so rows created in the 1.20/1.21 window stay stuck
-- blocking even after the code fix. Correct them.
--
-- WHY A NEW FILE (7) AND NOT A FOLD INTO 2-up.sql — 2-up.sql is RELEASED (pinned in
-- scripts/database/tests/released-migrations.txt; it shipped in Hub 1.20). Its seven-name list
-- and CURRENT_VERSION=2 are frozen. Any database in the wild has already run version 2 and will
-- never re-run it, so adding RetryWithBackoff there would reach no existing row on a CP upgrade
-- and would fail the sha256 drift check on a self-apply install. A name added to the non-gating
-- catalog AFTER a version is released needs its OWN (N+1)-up.sql — 2-up.sql says exactly this:
-- "a plugin later marked non-gating in the catalog gets the code fix automatically but NEVER the
-- Postgres data correction … If you add a name to the catalog, the already-persisted rows for it
-- need their own (N+1)-up.sql." This file is that (N+1) — the numbering has since advanced past 2
-- on unrelated DDL (3–6), so the next free number is 7.
--
-- ⚠️ THE AUTHORITY FOR THIS NAME LIVES IN ANOTHER REPO, AND NOTHING HERE CHECKS IT.
--   Authority: the `enforcement` column of tp-mcp-hub docs/contracts/plugin-catalog.json, where
--   RetryWithBackoffPlugin is 'non-gating' as of PCP-24560. That column is parity-guarded in
--   both directions against NON_GATING_PLUGINS in react/src/contracts/plugin-catalog.ts and
--   backend/src/lib/plugin-enforcement.ts. The SQLite half of this migration
--   (backend/src/sqlite-schema.ts, user_version 3) hardcodes the same name — its protection is
--   the parity test holding catalog and code Sets together, not derivation. This file hardcodes
--   the name in a different repo with NO such check; it matches character-for-character as of
--   PCP-24560.
--
-- Every constraint 2-up.sql PART B documents holds identically here, and is not re-argued:
--   * WHY ONLY 'enforce' IS REWRITTEN — it is the sole blocking token any DEFAULT path ever
--     produced; 'sequential' / 'concurrent' / 'enforce_ignore_error' imply a deliberate pick and
--     are left alone, so an operator's chosen Block survives.
--   * WHY 'transform' AND NOT 'audit' — 'transform' is the minimal non-blocking mode that still
--     merges global_context.state back into the shared context.
--   * KNOWN LIMITATION — a deliberate 'enforce' is indistinguishable from the buggy default
--     (no provenance column), so this is deliberately BROAD and rewrites both. Safe because the
--     plugin cannot produce a deny in any mode, so a deliberate 'enforce' on it was already a
--     no-op at the gateway.
--   * AUDIT-COLUMN SIDE EFFECT — the BEFORE UPDATE trigger pair on CP_PLUGIN_ASSIGNMENTS and
--     GATEWAYS advances MODIFIED_TIME / rewrites MODIFIED_BY to 'platform-default'; accepted,
--     and NOT a provenance marker (see 2-up.sql).
--   * Idempotent: re-running matches nothing, because the row no longer reads 'enforce'.
--   * ATOMICITY: wrapped in an explicit transaction — postgres-helper.bash runs an upgrade file
--     with ON_ERROR_STOP=1 but WITHOUT --single-transaction, so the dirty-marking and the
--     rewrite must not be able to commit independently.
BEGIN;

-- Mark every affected Data Plane dirty FIRST, while the rows still read 'enforce' — selecting on
-- the post-state would also sweep in Data Planes whose RetryWithBackoff binding was already
-- 'transform' and which this migration did not touch. Needed because the gateway only learns a
-- mode at push time and a direct SQL write bypasses the markDpDirty the API routes do.
--
-- 'error' is preserved (IS DISTINCT FROM, because SYNC_STATUS is nullable): it is operator triage
-- state, and this fires across the whole estate during an upgrade Job. Nothing is lost — the push
-- diff reads the rows live, so the corrected mode still ships on the next push.
UPDATE GATEWAYS
   SET SYNC_STATUS = 'pending'
 WHERE SYNC_STATUS IS DISTINCT FROM 'error'
   AND ID IN (
        SELECT DISTINCT DP_ID
          FROM CP_PLUGIN_ASSIGNMENTS
         WHERE MODE = 'enforce'
           AND PLUGIN_ID = 'RetryWithBackoffPlugin'
   );

-- UPDATED_AT is deliberately NOT bumped — the gateway push diff does not read it, and one
-- identical timestamp across sibling rows would flip the max(updated_at) tie-break that
-- buildVsPolicies uses to collapse two hooks of the same plugin to one policy.
UPDATE CP_PLUGIN_ASSIGNMENTS
   SET MODE = 'transform'
 WHERE MODE = 'enforce'
   AND PLUGIN_ID = 'RetryWithBackoffPlugin';

-- UPDATE, never INSERT — postgres-helper.bash reads the version with a bare single-value SELECT
-- and whitespace-strips it, so a second row would collapse to "17" at the version gate.
UPDATE SCHEMA_VERSION SET VERSION = 7;

COMMIT;
