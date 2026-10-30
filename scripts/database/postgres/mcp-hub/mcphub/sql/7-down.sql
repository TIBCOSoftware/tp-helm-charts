-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback of 7-up.sql (PCP-24560) — back to version 6. Re-blocks RetryWithBackoffPlugin by
-- restoring its pre-migration 'enforce' mode, and moves the version marker to 6.
--
-- LOSSY BY CONSTRUCTION, exactly as 2-down.sql documents for its seven names: the data does not
-- record whether a given 'transform' RetryWithBackoff row was rewritten by 7-up.sql or chosen by
-- a user (no provenance column, no history table). This rollback therefore re-blocks BOTH. And
-- once the PCP-24560 code fix is deployed, 'transform' is the CREATE-TIME DEFAULT for
-- RetryWithBackoff (defaultAttachMode -> NON_BLOCKING_DEFAULT), so on any install running the
-- fixed code that is the DOMINANT population — this rollback re-blocks essentially every
-- 'transform' binding of the plugin, not merely the rows 7-up.sql rewrote. A SQL rollback does
-- not roll back the code, so the Hub immediately starts writing 'transform' again for new
-- bindings. Practically harmless — the plugin cannot produce a deny in any mode — but the
-- breadth is intentional and a reviewer should not read this as a clean inverse.
--
-- The dirty-marking below shares the same over-reach, for the same reason 2-down.sql spells out:
-- the predicate that identifies "rows this rollback will change" (pre-state 'transform') also
-- matches a user's deliberate pre-migration 'transform', and MODIFIED_BY cannot separate the two
-- populations (TRIGGER_SET_MODIFIER stamps 'platform-default' on a console write too). Bounded
-- and self-correcting on the next push, and preferable to a predicate that looks discriminating
-- while discriminating nothing.
BEGIN;

-- Select the rows this statement is ABOUT TO CHANGE (pre-state 'transform'), never the
-- post-rollback 'enforce' — that would additionally sweep in Data Planes merely holding an
-- 'enforce' RetryWithBackoff binding, including rows created after 7-up.sql which this rollback
-- does not touch. 'error' preserved as in 7-up.sql.
UPDATE GATEWAYS
   SET SYNC_STATUS = 'pending'
 WHERE SYNC_STATUS IS DISTINCT FROM 'error'
   AND ID IN (
        SELECT DISTINCT DP_ID
          FROM CP_PLUGIN_ASSIGNMENTS
         WHERE MODE = 'transform'
           AND PLUGIN_ID = 'RetryWithBackoffPlugin'
   );

UPDATE CP_PLUGIN_ASSIGNMENTS
   SET MODE = 'enforce'
 WHERE MODE = 'transform'
   AND PLUGIN_ID = 'RetryWithBackoffPlugin';

-- UPDATE, never INSERT — see the note in 7-up.sql.
UPDATE SCHEMA_VERSION SET VERSION = 6;

COMMIT;
