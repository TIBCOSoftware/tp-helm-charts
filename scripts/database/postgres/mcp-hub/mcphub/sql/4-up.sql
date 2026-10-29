-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Schema version 4 (PCP-24759) — the gateway (BUSINESS TYPE, KIND) pair.
--
-- WHY A NEW FILE AND NOT A FOLD INTO 3-up.sql. 3-up.sql's own PCP-24485 note says it "is still
-- UNRELEASED (it appears in no released-migrations.txt sha pin)" and folds a column in on that
-- basis. ⚠️ THAT SENTENCE IS NOW STALE AND MUST NOT BE REASONED FROM: 3-up.sql was pinned in
-- scripts/database/tests/released-migrations.txt by #10904 (PCP-24482), so editing it now
-- reaches no existing database, trips the sha256 invariant in migration-invariants.bats, and
-- makes pg-migrate refuse to boot on digest drift. The live oracle is the sha pin, not any
-- file's prose about itself.
--
-- WHAT THE PAIR IS. Two dimensions, orthogonal to PLACEMENT / ORIGIN / CONNECTION_MODE:
--   BUSINESS_TYPE — 'mcp' | 'llm'
--   GATEWAY_KIND  — 'A' | 'B' | 'C' … an ORDINAL LETTER, allocated in the order products are
--                   added, carrying no meaning of its own, and SCOPED to the business type.
-- The registry that gives the letter its only meaning lives in tp-mcp-hub at
-- backend/src/lib/gateway-kind.ts and docs/design/mcp-hub/deployment-modes.md (two copies,
-- asserted equal by a test). ⚠️ Do NOT restate the mapping here — a third copy is one the
-- assertion cannot police, and a drifted lookup table for a meaningless letter cannot be
-- repaired by reading the surrounding code.
--
-- WHY BOTH COLUMNS, ALWAYS TOGETHER. 'A' means ContextForge under 'mcp' and LiteLLM under
-- 'llm'. A bare kind is unresolvable, so the pair is the key everywhere: schema, API, logs.
--
-- WHY NOT NULL WITH NON-EMPTY DEFAULTS, unlike 3-up.sql's REPORTED_* columns. Those are
-- nullable precisely so "never reported" stays distinguishable from "reported an empty
-- string". Here the equivalent question — "is this a row from before the pair existed?" — is
-- answered by the COLUMNS' ABSENCE, which the Hub probes for, not by a per-row NULL. So every
-- row that exists carries a real pair, and the compatibility default backfills legacy rows as
-- mcp/A, which is what they are.
--
-- ⚠️ THE EMPTY STRING IS NOT A SENTINEL FOR THESE TWO COLUMNS. PLACEMENT and CHART_VERSION use
-- '' as "unset" BECAUSE their default is ''. These default to non-empty values, so this
-- migration cannot produce an empty one — and the Hub therefore treats '' as an unregistered
-- pair and FAILS CLOSED on it rather than defaulting to mcp/A. Do not "helpfully" change these
-- defaults to '' for consistency with neighbouring columns; it would turn a write-time typo
-- into a silently mis-identified product.
--
-- ⚠️ A DATABASE DRIVEN TO VERSION 4 BY AN IMAGE THAT LACKS THIS FILE WILL NOT SELF-REPAIR.
-- Same trap 2-up.sql and 3-up.sql both document: upgradeDBSchema early-returns on "already at
-- the required version", so a later image carrying this file never runs it. The repair is the
-- chart flag `rerunCurrentUpgrade: true` on mcp-hub-webserver for one upgrade, not manual SQL.
-- Everything here is idempotent, so the rerun is safe on a database that already has the
-- columns.
--
-- ⚠️ TWO LEAD TIMES, and the Hub tolerates both. CP installs get this only once a
-- core-cp-scripts image carrying it is built AND pinned in mcp-hub-webserver/values.yaml;
-- self-apply installs get it as soon as the hub image rebuilds. The Hub therefore probes for
-- these columns with a FOUR-STATE verdict (both present / both absent / partial / probe
-- failed) and applies the mcp/A compatibility default ONLY on a verified both-absent. Partial
-- or unknown fails closed, because defaulting on a guess would classify an existing llm row as
-- legacy MCP and route it to ContextForge.
--
-- SQLITE MIRROR: tp-mcp-hub backend/src/sqlite-schema.ts, in the same change. ⚠️ Its absence
-- FAILS NO CHECK here — schema-parity asserts only sqlite ⊆ postgres, so a postgres-only
-- column is invisible to it (3-up.sql records the same gap for PCP-24485). It does, however,
-- fail in the other direction: the hub-side SQLite columns cannot land before THIS file is on
-- tp-helm-charts main, because schema-parity resolves postgres from HELM_CHARTS_SQL_REF=main.

BEGIN;

-- Dimension 1. 'mcp' | 'llm'. NOT NULL: every row has a business type, and legacy rows are
-- genuinely MCP rather than unknown.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS BUSINESS_TYPE TEXT NOT NULL DEFAULT 'mcp';

-- Dimension 2. The ordinal letter, scoped to BUSINESS_TYPE. NOT NULL for the same reason, and
-- 'A' because a legacy MCP gateway is ContextForge, which is mcp's first allocation.
-- ⚠️ Never reason about this value positionally (no "> 'A'", no "not the default"): the letter
-- asserts nothing, so allocation order says nothing about behaviour.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS GATEWAY_KIND TEXT NOT NULL DEFAULT 'A';

-- UPDATE, not INSERT. postgres-helper.bash reads the version with a bare
-- `SELECT VERSION FROM SCHEMA_VERSION` and whitespace-strips the result, so a second row would
-- collapse to the string "34" at the version gate and break the upgrade loop's arithmetic.
UPDATE SCHEMA_VERSION SET VERSION = 4;

COMMIT;
