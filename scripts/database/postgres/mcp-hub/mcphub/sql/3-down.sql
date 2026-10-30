-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback of schema version 3 (PCP-24482) — back to version 2.
--
-- ⚠️ THIS DELIBERATELY DOES NOT DROP THE COLUMNS, and that is the safe direction rather than
-- the lazy one.
--
-- A rollback exists to get a CP running again after a bad upgrade, and the realistic sequence
-- is: version 3 applied, some Hub pods already rolled to the new image, something unrelated
-- goes wrong, operator rolls the SCHEMA back. If this dropped the columns, every Hub pod still
-- running the new image would take 42703 on its next dial-home `hello` — an UPDATE naming a
-- column that no longer exists — and that error closes the control-channel socket. The
-- rollback would convert a cosmetic problem into every dial-home gateway disconnecting.
--
-- The columns are additive, nullable (bar PLACEMENT's empty default) and read defensively by
-- the Hub, so leaving them costs a version-2 database five unused columns and nothing else
-- (four on GATEWAYS, one on CP_VIRTUAL_SERVERS — see the PCP-24485 note in 3-up.sql).
-- That is the standard "additive columns are retained until every new revision is gone" rule.
-- If they must genuinely be removed — a schema audit, not a rollback — do it as its own
-- migration once no Hub revision reads them, with the DROPs written out explicitly then.
--
-- What this file DOES do is move the version marker back, which is the thing the upgrade loop
-- actually keys on: a database at 2 will re-run 3-up.sql on the next upgrade, and every
-- statement in it is idempotent (`ADD COLUMN IF NOT EXISTS`), so re-applying over retained
-- columns is a no-op.

BEGIN;

-- See the note in 3-up.sql: UPDATE, never INSERT — postgres-helper.bash reads this with a bare
-- single-value SELECT and whitespace-strips the result, so a second row breaks the version gate.
UPDATE SCHEMA_VERSION SET VERSION = 2;

COMMIT;
