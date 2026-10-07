-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Schema version 2 — two migrations under one version:
--   PART A (PCP-24190) DDL: five columns for already-provisioned databases.
--   PART B (PCP-23515) DATA: plugin bindings stuck in a blocking mode.
--
-- PART A — why it is here. PCP-22742 added CP_TOOLS/CP_PROMPTS/CP_RESOURCES.HUB_ORIGIN and
-- CP_SERVERS.FEDERATION_HEALTH/FEDERATION_CHECKED_AT as guarded ALTERs appended to 1-up.sql
-- (:920-940). Those are correct but UNREACHABLE on upgrade: upgradeDBSchema pre-increments
-- PREVIOUS_VERSION before the apply loop and builds `${PREVIOUS_VERSION}-up.sql`
-- arithmetically, and the create path runs 1-up.sql only when SCHEMA_VERSION is ABSENT. So on
-- an upgraded CP the columns never arrive and every Virtual Tool / Prompt / Resource insert
-- fails 42703. Copying them to a reachable version is the fix. 1-up.sql is NOT edited: it is
-- released (pinned in scripts/database/tests/released-migrations.txt), an edit reaches no
-- existing database, and on a self-apply install pg-migrate's digest check refuses to boot.
--
-- A DATABASE ALREADY AT VERSION 2 NEEDS ONE EXTRA STEP — and as of chart 1.21.0-alpha.18 that
-- is a common state, not a corner case. PCP-23913 (#10673) pinned cpScripts 9734-main-27a235f,
-- which carries the OLD data-only 2-up.sql (sha256 a90cd5ac…, no DDL) with CURRENT_VERSION=2, so
-- a CP taking alpha.18 is driven to version 2 WITHOUT these columns. A NORMAL upgrade will not
-- repair it: current == target, so upgradeDBSchema takes the "already at the required version"
-- early return and this file never runs.
--
-- The fix for those is a chart flag, not manual SQL: set `rerunCurrentUpgrade: true` on
-- mcp-hub-webserver (values.yaml -> jobs.yaml RERUN_CURRENT_UPGRADE) for one upgrade. At
-- postgres-helper.bash:856-866 that skips the pre-increment and re-executes
-- ${CURRENT_VERSION}-up.sql -- which, on an image carrying this file, IS this file. Verified
-- against Postgres 16: a v2 database missing all five columns has them after the rerun, with
-- SCHEMA_VERSION still a single row at 2. Everything here is idempotent, so the rerun is safe on
-- a database that already has them. Set the flag back to false afterwards.
--
-- Shipping this as version 2 rather than a new 3-up.sql is a deliberate PCP-24190 decision. Do
-- not "fix" it by editing this file again once an image carrying it has shipped -- that is the
-- fold pattern for the fourth time; from that point the answer is a 3-up.sql.
--
-- Recovery if you already applied the PRE-PCP-24190 bytes of this file:
--   CP / Job path  — no digest check; redeploy with rerunCurrentUpgrade=true to re-run it.
--   self-apply     — that flag does not apply; pg-migrate fails its sha256 drift check and the
--                    Hub will not boot. `DELETE FROM mcphub_schema_migrations WHERE version = 2;`
--                    then restart, and it re-applies. Everything here is idempotent.
--
-- PART B — PCP-23515. The original contents of this file, unchanged.
--
-- Seven CPEX plugins are verified incapable of producing a deny outcome: they never return
-- continue_processing=False and never return a deny decision payload, so they can only
-- observe or rewrite a request. The Hub nonetheless attached them in the legacy 'enforce'
-- token, which the gateway resolves to the BLOCKING canonical mode 'sequential'. A binding's
-- mode is written once at attach time and never recomputed, so rows created before the code
-- fix stay stuck in a blocking mode even after upgrading. Correct them.
--
-- ⚠️ THE AUTHORITY FOR THESE SEVEN NAMES LIVES IN ANOTHER REPO, AND NOTHING HERE CHECKS IT.
--   Authority: the `enforcement` column of tp-mcp-hub docs/contracts/plugin-catalog.json.
--   That column is parity-guarded in both directions against NON_GATING_PLUGINS in
--   react/src/contracts/plugin-catalog.ts and backend/src/lib/plugin-enforcement.ts. The SQLite
--   half of this migration ALSO hardcodes the list rather than deriving it — the protection
--   there is the parity test holding the catalog and the code Set together, not derivation.
--   This file hardcodes the same seven names in a different repo with NO such check. They match
--   character-for-character as of PCP-23515.
--
--   The drift is asymmetric and unrecoverable: a plugin later marked non-gating in the catalog
--   gets the code fix automatically but NEVER the Postgres data correction, because this is a
--   one-shot numbered migration that cannot be re-run against rows written before it. If you add
--   a name to the catalog, the already-persisted rows for it need their own (N+1)-up.sql.
--   A cross-repo assertion belongs in dev/check-mcp-version-sync.sh — see PCP-23515.
--
-- WHY ONLY 'enforce' IS REWRITTEN
--   'enforce' is a LEGACY ALIAS, not a canonical mode — the gateway resolves it to
--   'sequential'. The full set of stored tokens with blocking semantics is
--   {'enforce', 'enforce_ignore_error', 'sequential', 'concurrent'}, so a predicate of
--   `MODE = 'sequential'` would match nothing in practice. Of those four, only 'enforce' was
--   ever produced by a default path: the console's mode picker does not offer 'sequential' at
--   all, and 'concurrent' / 'enforce_ignore_error' are deliberate picks. Rewriting those would
--   clobber intent. 'audit', 'disabled', 'fire_and_forget', 'permissive' and 'transform' are
--   already non-blocking and are left alone.
--
-- WHY 'transform' AND NOT 'audit'
--   'transform' is the minimal non-blocking mode that still merges global_context.state back
--   into the shared context. 'audit' runs the plugin on an isolated snapshot which is then
--   discarded — for JwtClaimsExtractionPlugin, whose ONLY output channel is that state, audit
--   would fire the plugin and deliver nothing.
--
-- KNOWN LIMITATION — a deliberate 'enforce' is indistinguishable from the buggy default.
--   There is no provenance column and no per-row history: a create-time default and a
--   user-chosen "Block" write the identical literal. This migration is therefore deliberately
--   BROAD — it rewrites both. That is judged safe because these seven plugins cannot produce a
--   deny in any mode, so a deliberate 'enforce' on them was already a no-op at the gateway.
--
-- AUDIT-COLUMN SIDE EFFECT, on BOTH tables this file writes. CP_PLUGIN_ASSIGNMENTS
--   (1-up.sql:813-817) and GATEWAYS (1-up.sql:167-174) carry the same BEFORE UPDATE trigger pair,
--   so every row touched by EITHER statement below has MODIFIED_BY rewritten and MODIFIED_TIME
--   advanced. Accepted: there is no history table whose attribution would otherwise be preserved.
--
--   Note MODIFIED_BY becomes 'platform-default' for every such row — but that is NOT a marker of
--   "written by the migration". TRIGGER_SET_MODIFIER resolves the actor as
--   coalesce(current_setting('cp.userId', true), 'platform-default'), and the Hub backend never
--   sets cp.userId on its session (grep: no set_config / cp.userId anywhere in backend/src), so a
--   console write lands the identical literal. Do not build a predicate on it.
--
--   GATEWAYS.UPDATED_AT is likewise left alone here, deliberately, matching the
--   CP_PLUGIN_ASSIGNMENTS.UPDATED_AT decision explained below. markDpDirty does bump it, but the
--   only readers in the hub are test fixtures, so leaving it costs nothing.
--
-- Idempotent: re-running matches nothing, because the rows no longer read 'enforce'.
--
-- ATOMICITY: wrapped in an explicit transaction. postgres-helper.bash runs an upgrade file with
--   -v ON_ERROR_STOP=1 but WITHOUT --single-transaction (:798; the create path at :489 does pass
--   it), so each statement would otherwise autocommit on its own. If the dirty-marking committed
--   and the rewrite then failed, Data Planes would report "changes to push" for a rewrite that
--   never happened while SCHEMA_VERSION stayed at 1. A retry converges either way, but the
--   interim operator-visible state is avoidable and this file cannot change the helper's flags.

-- Mark every affected Data Plane dirty so the console surfaces "changes to push".
--
-- This MUST run BEFORE the mode rewrite below, while the rows still read 'enforce' — selecting
-- on the post-state would also sweep in Data Planes whose bindings were already 'transform' and
-- which this migration did not touch.
--
-- It is needed at all because the gateway only learns a binding's mode at push time, and the
-- API write paths mark the DP dirty themselves (markDpDirty / updateSyncStatus) — a direct SQL
-- write bypasses both, so without this the corrected mode would never reach an already-pushed
-- gateway unprompted.
BEGIN;

-- ── PART B (PCP-23515): the plugin-binding data correction ───────────────────────────────
-- The seven names, declared ONCE per file. Both predicates below read from this rather than
-- repeating the literal list, so the two statements in this file cannot drift apart. Scoped to
-- the transaction (ON COMMIT DROP), so it leaves nothing behind and cannot collide with a
-- concurrent session.
CREATE TEMP TABLE non_gating_plugins(plugin_id) ON COMMIT DROP AS
VALUES
       ('JwtClaimsExtractionPlugin'), ('VaultPlugin'), ('SafeHTMLSanitizer'),
       ('LicenseHeaderInjector'), ('PrivacyNoticeInjector'),
       ('CachedToolResultPlugin'), ('ResponseCacheByPrompt');

UPDATE GATEWAYS
   SET SYNC_STATUS = 'pending'
   -- Never overwrite 'error': that is triage state an operator may be actively working, and
   -- this fires across the whole estate during an upgrade Job rather than on one Data Plane the
   -- user just edited. Nothing is lost by skipping it — sync_status is a console hint, and the
   -- push diff reads the rows live, so the corrected mode still ships on the next push.
   --
   -- IS DISTINCT FROM, not <>: SYNC_STATUS is NULLABLE (1-up.sql:59 declares it
   -- VARCHAR(64) DEFAULT 'unknown' with no NOT NULL), and `NULL <> 'error'` is NULL, not TRUE —
   -- so a NULL row would be silently skipped, which is the exact outcome this statement exists
   -- to prevent. Matches the idiom already used elsewhere in this corpus (idm/sql/8-up.sql:61).
 WHERE SYNC_STATUS IS DISTINCT FROM 'error'
   AND ID IN (
        SELECT DISTINCT DP_ID
          FROM CP_PLUGIN_ASSIGNMENTS
         WHERE MODE = 'enforce'
           AND PLUGIN_ID IN (SELECT plugin_id FROM non_gating_plugins)
   );

-- UPDATED_AT is deliberately NOT bumped. The gateway push diff does not read it, and rewriting
-- it to one identical timestamp across sibling rows would flip the max(updated_at) tie-break
-- that buildVsPolicies uses to collapse two hooks of the same plugin to one policy.
UPDATE CP_PLUGIN_ASSIGNMENTS
   SET MODE = 'transform'
 WHERE MODE = 'enforce'
   AND PLUGIN_ID IN (SELECT plugin_id FROM non_gating_plugins);

-- ── PART A (PCP-24190): the five columns, same statements as 1-up.sql:920-940 ────────────
-- Deliberately placed AFTER Part B and immediately before the version bump. ALTER TABLE takes
-- ACCESS EXCLUSIVE and, like every lock in Postgres, holds it until COMMIT -- so running the DDL
-- first would keep all four tables locked for the whole of Part B's UPDATEs, and ACCESS EXCLUSIVE
-- conflicts with plain SELECT. Running it last shrinks that window to the tail of the transaction
-- without giving up atomicity (either all of version 2 applies or none of it does).
--
-- Idempotent, so a no-op on a fresh install where 1-up.sql already created them, and
-- metadata-only in PG 11+ (nullable / non-volatile default) -- no table rewrite, so the statements
-- themselves are effectively instant. lock_timeout bounds the wait for the lock itself: this Job
-- is a pre-upgrade Helm hook, so a long-running reader must not be able to wedge the release.
-- SET LOCAL, so it reverts at COMMIT and affects nothing else.
--
-- What happens if it FIRES, stated so nobody has to infer it: the ALTER errors, the WHOLE
-- version-2 transaction rolls back (Part B's UPDATEs included), and the Job fails -- the release
-- stalls rather than partially applying. That is the intended behaviour, and retrying is safe
-- because nothing was committed. Note also that 15s bounds the wait for EACH ALTER
-- independently, not the transaction as a whole, so the worst case is five waits, not one.
SET LOCAL lock_timeout = '15s';

ALTER TABLE CP_TOOLS     ADD COLUMN IF NOT EXISTS HUB_ORIGIN TEXT DEFAULT '';
ALTER TABLE CP_PROMPTS   ADD COLUMN IF NOT EXISTS HUB_ORIGIN TEXT DEFAULT '';
ALTER TABLE CP_RESOURCES ADD COLUMN IF NOT EXISTS HUB_ORIGIN TEXT DEFAULT '';
ALTER TABLE CP_SERVERS   ADD COLUMN IF NOT EXISTS FEDERATION_HEALTH TEXT DEFAULT '';
ALTER TABLE CP_SERVERS   ADD COLUMN IF NOT EXISTS FEDERATION_CHECKED_AT TEXT;

-- UPDATE, not INSERT. postgres-helper.bash reads the version with a bare
-- `SELECT VERSION FROM SCHEMA_VERSION` and then strips whitespace (`tr -d ' \t\n\r'` at :298,
-- `sed 's/[ \t]*//g'` at :751). A second row would collapse to the string "12" at the version
-- gate and break the arithmetic comparison in the upgrade loop. 1-up.sql's trailing
-- `INSERT ... VALUES (1) ON CONFLICT DO NOTHING` is the one-time seed of that single row.
UPDATE SCHEMA_VERSION SET VERSION = 2;

COMMIT;
