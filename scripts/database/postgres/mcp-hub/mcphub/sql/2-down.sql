-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback of 2-up.sql — restores the pre-migration blocking attach mode for the seven
-- non-gating plugins (PCP-23515), and deliberately does NOT undo PCP-24190's DDL.
--
-- ⚠️ PART A of 2-up.sql (the five columns) is deliberately NOT reversed here. Dropping them
-- would re-create the very 42703 PCP-24190 fixes — every shipped Hub image writes HUB_ORIGIN on
-- insert and FEDERATION_HEALTH on sync, and a SQL rollback does not roll back the running code.
-- It would not even match a genuine version-1 database, since 1-up.sql:920-940 creates the same
-- columns on a fresh install. And it is irreversible: HUB_ORIGIN is insert-only, so re-running
-- the Hub would not repopulate existing rows. The DDL is additive and idempotent, so leaving it
-- is forward-compatible; a re-upgrade simply finds the columns present.
--
-- LOSSY BY CONSTRUCTION, stated plainly rather than glossed: the data does not record whether a
-- given 'transform' row was rewritten by 2-up.sql or chosen by a user (there is no provenance
-- column and no history table). This rollback therefore re-blocks BOTH. That is the same
-- limitation 2-up.sql documents in the other direction, and it is unavoidable without adding a
-- provenance column — which would itself be a schema change.
--
-- Consequence, and it is broader than "a user who happened to choose transform": once the
-- PCP-23515 code fix is deployed, 'transform' is the CREATE-TIME DEFAULT for these seven
-- (defaultAttachMode -> NON_BLOCKING_DEFAULT), so on any install running the fixed code that is
-- the DOMINANT population, not a rare one. This rollback therefore re-blocks essentially every
-- 'transform' binding of the seven, not merely the rows 2-up.sql rewrote.
--
-- And a SQL rollback does not roll back the code: the Hub keeps writing 'transform' afterwards.
-- So this is NOT a return to the pre-migration state — it is a one-shot re-block that the
-- running code will immediately start undoing for newly created bindings. Practically harmless
-- (these plugins cannot produce a deny in any mode), but the breadth is intentional and a
-- reviewer should not read this file as a clean inverse.
--
-- ⚠️ THE SAME OVER-REACH APPLIES TO THE DIRTY-MARKING BELOW, and it is worth being exact
-- because 2-up.sql's equivalent comment does NOT apply here. There, selecting the pre-state
-- genuinely isolates the rows the statement changes. Here it cannot: the predicate that
-- identifies "rows this rollback will change" is the same predicate that matches a user's
-- deliberate pre-migration 'transform'. So a Data Plane holding only such a row IS marked
-- pending by this file even though the mode it carries was already what the user chose.
--
-- Reviewed and left as-is rather than narrowed. The obvious narrowing —
-- AND MODIFIED_BY = 'platform-default' — does NOT work: TRIGGER_SET_MODIFIER (1-up.sql:29-42)
-- resolves the actor as coalesce(current_setting('cp.userId', true), 'platform-default'), and
-- the Hub backend never sets cp.userId on its session, so a console write stamps the identical
-- literal. The column is last-writer, not provenance, and it cannot separate the two
-- populations. Distinguishing them needs a real provenance column, i.e. a schema change.
--
-- Net: a rollback re-blocks and re-dirties slightly more than it strictly created. Bounded and
-- self-correcting on the next push, and preferable to a predicate that looks discriminating
-- while discriminating nothing.

-- Select the rows this statement is ABOUT TO CHANGE (pre-state 'transform'), never the
-- post-rollback 'enforce' — that would additionally sweep in every Data Plane merely holding an
-- 'enforce' binding for one of these plugins, including rows created after the up-migration
-- which the rollback does not touch at all.
--
-- 'error' is preserved for the same reason as in 2-up.sql: it is operator triage state.
BEGIN;

-- Declared once, read by both predicates below — see the note in 2-up.sql.
CREATE TEMP TABLE non_gating_plugins(plugin_id) ON COMMIT DROP AS
VALUES
       ('JwtClaimsExtractionPlugin'), ('VaultPlugin'), ('SafeHTMLSanitizer'),
       ('LicenseHeaderInjector'), ('PrivacyNoticeInjector'),
       ('CachedToolResultPlugin'), ('ResponseCacheByPrompt');

UPDATE GATEWAYS
   SET SYNC_STATUS = 'pending'
   -- IS DISTINCT FROM, not <>: SYNC_STATUS is nullable, so `NULL <> 'error'` is NULL and the
   -- row would be silently skipped. Kept symmetric with 2-up.sql.
 WHERE SYNC_STATUS IS DISTINCT FROM 'error'
   AND ID IN (
        SELECT DISTINCT DP_ID
          FROM CP_PLUGIN_ASSIGNMENTS
         WHERE MODE = 'transform'
           AND PLUGIN_ID IN (SELECT plugin_id FROM non_gating_plugins)
   );

UPDATE CP_PLUGIN_ASSIGNMENTS
   SET MODE = 'enforce'
 WHERE MODE = 'transform'
   AND PLUGIN_ID IN (SELECT plugin_id FROM non_gating_plugins);

-- See the note in 2-up.sql: UPDATE, never INSERT — postgres-helper.bash reads this with a bare
-- single-value SELECT and whitespace-strips the result.
UPDATE SCHEMA_VERSION SET VERSION = 1;

COMMIT;
