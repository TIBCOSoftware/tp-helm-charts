-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Schema version 5 (PCP-24759 AC 5) — liveness, HEALTH and APPLIED CONFIGURATION are three
-- different things, and until now the GATEWAYS table could express only the first.
--
-- WHY A NEW FILE RATHER THAN A FOLD INTO 4-up.sql — the question was asked, not assumed.
-- 4-up.sql is NOT in scripts/database/tests/released-migrations.txt (only 1/2/3 are), and that
-- pin file is the stated oracle for the freeze, so editing 4-up.sql would trip no check here.
-- It is still the wrong move:
--   * the fold-instead-of-add rule applies to a migration still on an UNMERGED PR. 4-up.sql is
--     merged to main, so hub images built from main already bake it;
--   * on a SELF-APPLY install (DB_AUTO_MIGRATE, the default outside CP) tp-mcp-hub records the
--     sha256 of every migration it applies and REFUSES TO START when an applied file changes.
--     Any database that has already run version 4 would be bricked on restart by an edit here;
--   * on a CP install the failure is quieter and worse — manageDbSchema sees the version
--     already at target, prints "no action needed", and the edited bytes never arrive.
-- "Probably nothing has applied version 4 yet" is not a basis for an irreversible edit, and the
-- cost of being wrong is asymmetric. A second file costs one PR.
--
-- ─────────────────────────────────────────────────────────────────────────────────────────
-- WHY `STATUS` COULD NOT CARRY HEALTH. It is not that nobody got round to it: PCP-20289 (C4)
-- deliberately made STATUS SELF-HEAL — ws-server.ts's heartbeat handler re-asserts
-- status='online' on EVERY heartbeat, so "a row can never drift offline while it is actively
-- heart-beating". AC 5 needs the opposite for health ("connected plus unhealthy REMAINS
-- unhealthy"). Re-purposing STATUS would reverse a pinned prior decision across six writers in
-- two subsystems plus a CAS key derived from it. A separate column SIDESTEPS C4 instead of
-- overturning it. ⚠️ Do not "simplify" this later by folding RUNTIME_HEALTH back into STATUS.
--
-- ─────────────────────────────────────────────────────────────────────────────────────────
-- NOT NULL vs NULLABLE IS DECIDED PER COLUMN, BY WHETHER "NEVER REPORTED" IS A REAL ANSWER.
-- 3-up.sql's REPORTED_* columns are nullable precisely so "never reported" stays distinct from
-- "reported an empty string"; 4-up.sql's pair is NOT NULL because the columns' ABSENCE already
-- answers the legacy question. Both patterns appear below, on purpose:
--   * RUNTIME_HEALTH      NOT NULL DEFAULT 'unknown' — 'unknown' IS the honest initial state,
--                         and a health discriminator must never be NULL-ambiguous.
--   * *_OBSERVED_AT / *_ERROR / APPLIED_CONFIG_REVISION  NULLABLE — each has a real "never"
--                         that must not be confused with a reported empty value. An old agent
--                         that never reports an applied revision leaves NULL; an agent that
--                         reports an empty one is a different (and wrong) thing.
--   * DESIRED_CONFIG_REVISION  NOT NULL DEFAULT '' — the Hub is the sole writer, so '' is
--                         legitimately "no revision issued yet", exactly as PLACEMENT and
--                         CHART_VERSION use ''.
--
-- ⚠️ 'unknown' IS NOT 'healthy'. Every consumer must treat them as distinct; defaulting an
-- unobserved gateway to healthy would make the column decorative for the case it exists for.
--
-- ⚠️ A DATABASE DRIVEN TO VERSION 5 BY AN IMAGE THAT LACKS THIS FILE WILL NOT SELF-REPAIR.
-- Same trap 2/3/4-up.sql each document: upgradeDBSchema early-returns on "already at the
-- required version", so a later image carrying this file never runs it. The repair is the chart
-- flag `rerunCurrentUpgrade: true` on mcp-hub-webserver for one upgrade, not manual SQL.
-- Everything here is idempotent, so the rerun is safe on a database that already has them.
--
-- SQLITE MIRROR: tp-mcp-hub backend/src/sqlite-schema.ts + backend/tests/setup.ts, in the same
-- change. ⚠️ Their absence FAILS NO CHECK here — schema-parity asserts only sqlite ⊆ postgres,
-- so a postgres-only column is invisible to it. It does fail in the other direction: the
-- hub-side SQLite columns cannot land before THIS file is on tp-helm-charts main, because
-- schema-parity resolves postgres from HELM_CHARTS_SQL_REF=main.

BEGIN;

-- ── Health, as OBSERVED — never inferred from liveness ────────────────────────────────────
-- 'unknown' | 'healthy' | 'unhealthy'. Written by the health observer, never by the heartbeat
-- path. ⚠️ Deliberately NOT constrained by a CHECK: the Hub validates this at its own boundary
-- with a registry it can evolve, and a CHECK here would make adding a fourth state a schema
-- migration in a different repo from the code that needs it.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS RUNTIME_HEALTH TEXT NOT NULL DEFAULT 'unknown';

-- When that verdict was last OBSERVED. NULL = never — which is why RUNTIME_HEALTH='unknown'
-- with a NULL timestamp ("we have never looked") is distinguishable from 'unknown' with a
-- recent one ("we looked and could not tell"). Those need different operator responses.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS RUNTIME_HEALTH_OBSERVED_AT TEXT;

-- The reason for the last 'unhealthy'/'unknown' verdict, verbatim from the observation. NULL =
-- no error recorded. ⚠️ This is operator-facing text, not a machine discriminator — never
-- branch on its contents; branch on RUNTIME_HEALTH.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS RUNTIME_HEALTH_ERROR TEXT;

-- ── Desired vs applied configuration ──────────────────────────────────────────────────────
-- What the Hub has ISSUED. Hub is the only writer, so '' = nothing issued yet.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS DESIRED_CONFIG_REVISION TEXT NOT NULL DEFAULT '';

-- What the gateway has CONFIRMED it applied, reported over the dial-home `hello` frame. NULL =
-- never reported, which is the state of every gateway running an agent older than the protocol
-- addition that carries it — and of every non-dial-home gateway, which has no reporting channel
-- at all. ⚠️ NULL must NOT be read as "applied nothing": it means we do not know. A rejected
-- revision leaves this at its previous value, which is the whole point of separating the two.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS APPLIED_CONFIG_REVISION TEXT;

-- UPDATE, not INSERT. postgres-helper.bash reads the version with a bare
-- `SELECT VERSION FROM SCHEMA_VERSION` and whitespace-strips the result, so a second row would
-- collapse to the string "45" at the version gate and break the upgrade loop's arithmetic.
UPDATE SCHEMA_VERSION SET VERSION = 5;

COMMIT;
