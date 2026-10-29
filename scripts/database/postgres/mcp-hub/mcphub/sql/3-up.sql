-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Schema version 3 (PCP-24482) — what a DIAL-HOME gateway reports about ITSELF, plus where it
-- was placed.
--
-- WHY A NEW FILE AND NOT A FOLD INTO 2-up.sql. 2-up.sql says so itself: folding was a
-- deliberate PCP-24190 decision and "from that point the answer is a 3-up.sql". It is also
-- released — pinned by sha256 in scripts/database/tests/released-migrations.txt — so an edit
-- reaches no existing database, and on a self-apply install pg-migrate's digest check refuses
-- to boot.
--
-- WHY THESE COLUMNS EXIST AT ALL. The Hub can tell a customer "Upgrade available" only if it
-- knows what the gateway is CURRENTLY running. It does not: the dial-home `hello` frame has
-- declared agentVersion and gatewayVersion since PCP-20279, and the handler reads neither —
-- they are never persisted and have no consumer. Meanwhile GATEWAYS.CHART_VERSION and
-- .MCPGATEWAY_VERSION are written ONLY by the CP-deploy and CP-upgrade paths, and the
-- dial-home branch returns before reaching any of them, so on a dial-home row they stay empty
-- forever. So the Hub has a DESIRED version (its own pin) and no OBSERVED one.
--
-- WHY NOT REUSE CHART_VERSION. It carries CP-deploy lifecycle semantics — "the Hub's release
-- identity for a gateway the Hub deployed, rewritten only by the Hub's own upgrade" — AND a
-- NON-EMPTY default. Reusing it would make "never reported" indistinguishable from "reported
-- exactly the default", which is precisely the ambiguity the unknown-state policy exists to
-- prevent: a gateway that has told us nothing must never render an upgrade prompt. These
-- columns are therefore distinct and NULLABLE, so NULL means "not reported".
--
-- PLACEMENT is not a version: it records WHERE the gateway was installed (standalone vs the
-- Control Plane's own cluster), because a later upgrade command has to render under the same
-- registry policy the install used. Without it a re-rendered command can point at a different
-- registry than the one already on the cluster.
--
-- ⚠️ A DATABASE DRIVEN TO VERSION 3 BY AN IMAGE THAT LACKS THIS FILE WILL NOT SELF-REPAIR.
-- Same trap 2-up.sql documents: upgradeDBSchema early-returns on "already at the required
-- version", so a later image carrying this file never runs it. The repair is the chart flag
-- `rerunCurrentUpgrade: true` on mcp-hub-webserver for one upgrade, not manual SQL. Everything
-- here is idempotent, so the rerun is safe on a database that already has the columns.
--
-- ⚠️ TWO LEAD TIMES, and the Hub tolerates both. CP installs get this only once a
-- core-cp-scripts image carrying it is built AND pinned in mcp-hub-webserver/values.yaml;
-- self-apply installs get it as soon as the hub image rebuilds. The Hub therefore probes for
-- these columns and degrades to "unknown" on BOTH its read and its write paths — an UPDATE
-- naming an absent column raises 42703 and closes the dial-home socket, which would turn a
-- cosmetic feature into an outage.

BEGIN;

-- What the gateway reported over its dial-home `hello` frame. NULL = never reported, which is
-- a distinct state from "reported an empty string" and must not produce an upgrade prompt.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS REPORTED_CHART_VERSION   TEXT;
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS REPORTED_AGENT_VERSION   TEXT;
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS REPORTED_GATEWAY_VERSION TEXT;

-- Where this gateway was installed: 'standalone' (a customer's own cluster) or 'cp-platform'
-- (the Control Plane's own cluster). Decides which container registry a re-rendered upgrade
-- command must carry. Empty default rather than NULL: every existing row predates the
-- cp-platform placement, so 'not recorded' and 'standalone' are the same thing for them.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS PLACEMENT TEXT DEFAULT '';

-- ─────────────────────────────────────────────────────────────────────────────────────────
-- PCP-24485 — NOT this ticket's column, riding here deliberately.
--
-- This file is still UNRELEASED (it appears in no `released-migrations.txt` sha pin), and the
-- repo's rule for exactly that case is to fold into the existing N-up.sql rather than add an
-- (N+1). `2-up.sql` records why: folding was a one-time PCP-24190 decision and "from that
-- point the answer is a 3-up.sql" — and 2-up.sql is itself released and sha-pinned, so editing
-- IT would reach no existing database and would make pg-migrate refuse to boot on digest drift.
--
-- A `4-up.sql` would also have to land AFTER this file regardless (or collide on the number),
-- so it would be neither faster nor more independent — just an extra CURRENT_VERSION bump, an
-- extra Secure-CI rebuild and an extra cpScripts.tag bump, for changes that ship as one unit.
--
-- ⚠️ The SQLite mirror for this column is deliberately NOT here, and its absence FAILS NO
-- CHECK: schema-parity only asserts sqlite ⊆ postgres, so a postgres-only column is invisible
-- to it. It belongs in tp-mcp-hub `backend/src/sqlite-schema.ts` and PCP-24485 owns that half;
-- without it the column is simply missing in sqlite-mode dev environments, silently.
--
-- Additive, nullable, defaulted: inert on any release whose code does not read it.
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS INCLUDE_ALL_TOOLS_FROM TEXT DEFAULT '[]';

-- UPDATE, not INSERT. postgres-helper.bash reads the version with a bare
-- `SELECT VERSION FROM SCHEMA_VERSION` and whitespace-strips the result, so a second row would
-- collapse to the string "23" at the version gate and break the upgrade loop's arithmetic.
UPDATE SCHEMA_VERSION SET VERSION = 3;

COMMIT;
