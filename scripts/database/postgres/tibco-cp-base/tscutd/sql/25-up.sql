-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- ============================================================================
-- PCP-10543: Drop raw-subscription and raw-user tables
--
-- The raw-subscription and raw-user features have been removed from the
-- tp-cp-user-subscriptions service. Drop the tables, archive tables, and
-- trigger function that are no longer used.
-- ============================================================================

-- Drop triggers first (CASCADE on the tables would handle this, but being
-- explicit keeps the intent clear).
DROP TRIGGER IF EXISTS VALIDATE_RAW_SUBSCRIPTION_INSERT ON V2_RAW_SUBSCRIPTIONS;
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_RAW_SUBSCRIPTIONS;
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_RAW_USERS;
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_RAW_USERS;

-- Drop the trigger function.
DROP FUNCTION IF EXISTS VALIDATE_RAW_SUBSCRIPTION() CASCADE;

-- Drop the main tables (CASCADE drops the FK constraint to V2_EXTERNAL_ACCOUNT_TYPES).
DROP TABLE IF EXISTS V2_RAW_SUBSCRIPTIONS CASCADE;
DROP TABLE IF EXISTS V2_RAW_USERS CASCADE;

-- Drop the archive tables.
DROP TABLE IF EXISTS V2_ARCHIVED_RAW_SUBSCRIPTIONS CASCADE;
DROP TABLE IF EXISTS V2_ARCHIVED_RAW_USERS CASCADE;


-- ============================================================================
-- PCP-19871 (orch-mon merge) — appended after the changes above, which came from
-- main. The two halves are independent: main's drops the raw-subscription/raw-user
-- tables, this one retires monitoringdb by adding the monitoring columns and tables
-- to tscutdb. Both share schema version 25, so the single update below covers both.
-- ============================================================================

-- Database schema changes for 1.22.0

---------------------------------------------------------
-- Monitoring tables for tscutdb (Epic PCP-19871, Story B / PCP-20152)
-- Consolidated from monitoringdb migrations 1-up.sql through 6-up.sql
-- Source: tp-cp-monitoring-service @ main (commit 8eb2192)
--
-- NOTE: this migration is 23-up.sql, not 22-up.sql — migration 22 was taken by
-- PCP-18605 (V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES) on the same line.
--
-- Design decisions:
--   - V3_DATA_PLANES, V3_CAPABILITY_INSTANCES, V3_RESOURCE_INSTANCES
--     are extended with monitoring columns (ALTER TABLE) instead of
--     creating redundant MON_ copies.
--   - MONITORING_STATUS already exists on all 3 V3 tables (added in 20-up.sql,
--     PCP-17036/17463). Maps to monitoring service STATUS (red/green/amber).
--   - HAS_TIBTUNNEL dropped: use existing CONNECTION_DETAILS -> hybridConnectivity
--   - LATEST_UPDATE dropped: write-only column, never read
--   - MON_ACTIVE NOT added to ANY V3 table (V3_DATA_PLANES, V3_CAPABILITY_INSTANCES,
--     V3_RESOURCE_INSTANCES): per PCP-20152 decision (2026-06-18) the monitoring `active`
--     filter is not needed — the V3 tables are the orchestrator's authoritative tables
--     (deprovisioned rows move to V3_ARCHIVED_*), so the monitoring `active` flag is redundant.
--   - MON_CAPABILITY_METADATA dropped: data already served from EFS files via
--     orchestrator /v1/capabilities-metadata API; DB table was a cron-refreshed
--     cache with zero read consumers.
--   - TIBTUNNEL_STATUS folded into V3_DATA_PLANES as CONNECTIVITY_STATUS /
--     CONNECTIVITY_STATUS_LAST_UPDATED (PCP-23425). It was briefly carried as a separate
--     MON_DP_CONNECTIVITY_STATUS table; see SECTION 2c for why that was removed.
--   - FinOps tables have no FK to V3_DATA_PLANES (self-contained).
--     NOTE: production monitoringdb DOES have fk_dp_id on all 4 finops
--     tables (running_app_instances, client_connections_v2, adapters,
--     processors). We deliberately DROP these FKs so finops/billing rows
--     survive data-plane deletion (decoupled retention). This is an
--     intentional divergence from the source schema, not an omission.
--   - Tables start empty. Cron jobs and DP heartbeats repopulate
--     naturally after deployment.
--   - Historical finops data migration handled in a later phase.
--
-- Validated against live cp1_monitoringdb (cluster ins-35.209.115.217,
-- schema_version=6) on 2026-06-10: all 11 source tables + DOMAINS(absent)
-- cross-checked for columns, PKs, FKs, types. capability_metadata empty
-- (0 rows) confirms zero data to migrate. FKs on services -> capability_instances
-- and tibtunnel_status/capability_instances/resources -> dataplanes confirmed.
---------------------------------------------------------

-- ============================================================================
-- SECTION 1: ALTER existing V3 tables with monitoring columns
-- ============================================================================

-- 1a. V3_DATA_PLANES — add monitoring health tracking columns
--     MONITORING_STATUS already exists (20-up.sql) — maps to monitoring STATUS.
--     MON_ACTIVE deliberately omitted (PCP-20152 decision 2026-06-18): the DP
--     active filter is not needed; V3_DATA_PLANES already reflects registered DPs.
--     PCP-24285: MON_LAST_STATUS_UPDATED MUST carry a default. Pre-merge this column lived in
--     monitoringdb.DATAPLANES, an insert-only table whose rows were created by the first
--     heartbeat, so it was never zero. Here the column is added onto V3_DATA_PLANES rows that
--     ALREADY EXIST, so without a default every DP present at upgrade time reads back NULL,
--     which COALESCE turns into 0, which checkIfOldStatus (monitoring_server.go) reads as
--     "Never heard status" and forces the DP RED.
--
--     That red is unrecoverable: the same write that sets it also stamps
--     MON_LAST_STATUS_UPDATED = now, so the condition clears itself one tick later while the
--     red remains, and only a full monitor-agent payload ever overwrites MONITORING_STATUS —
--     which the agent sends solely when its own view changes. A healthy DP therefore stayed
--     red until tp-dp-monitor-agent was restarted. Observed on the local cluster as
--     {"mon_message":"Never heard status","monitoring_status":"red"}.
--
--     The default also covers rows created later: it is evaluated per INSERT, so a DP whose
--     creation-time monitoring write never lands (InformDPOperations is fire-and-forget and
--     only warns on failure) still gets a real timestamp instead of NULL.
ALTER TABLE V3_DATA_PLANES ADD COLUMN IF NOT EXISTS MON_LAST_STATUS_UPDATED BIGINT DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT);
ALTER TABLE V3_DATA_PLANES ADD COLUMN IF NOT EXISTS MON_MESSAGE TEXT;

--     PCP-23425: DP connectivity (the tibtunnel check), folded in from the former
--     MON_DP_CONNECTIVITY_STATUS satellite table — see SECTION 2c below for why that
--     table is gone. Same principle as the two columns above: extend V3_DATA_PLANES
--     rather than keep a parallel satellite table.
--
--     Unprefixed, unlike MON_LAST_STATUS_UPDATED / MON_MESSAGE above: PCP-23429 renamed
--     the imported monitoring tables to the V3 scheme, and these columns were named to
--     match it. The two MON_ columns are left as they are by the same decision.
--
--     DEFAULT false reproduces the old MON_INSERT_CONN_STATUS trigger, which seeded
--     every newly registered DP with false. Without it a new DP would read NULL, which
--     GetConnectivityStatusForDP reports as ErrDPProvisioning instead of "not connected".
--
--     CONNECTIVITY_STATUS_LAST_UPDATED is NOT decoration: generateTempTrafficLightsResp
--     (monitoring_server.go) treats a value older than 5 minutes as "the tunnel cron has
--     died, stop trusting the stored flag" and forces the tunnel down, which turns a
--     healthy DP amber. The tibTunnelRefresh cron therefore writes BOTH columns every
--     minute even when the value has not changed — the write is a liveness signal, not
--     just a data update. Do not "optimise" it to write only on change.
--     PCP-24285: CONNECTIVITY_STATUS_LAST_UPDATED needs a default for the same reason as
--     MON_LAST_STATUS_UPDATED above, and the paragraph immediately above says why: a value
--     older than 5 minutes is read as "the tunnel cron has died". NULL/0 on an existing row
--     is instantly older than 5 minutes, so every DP present at upgrade time has its tunnel
--     forced down and goes AMBER until the first tibTunnelRefresh tick writes a real value.
ALTER TABLE V3_DATA_PLANES ADD COLUMN IF NOT EXISTS CONNECTIVITY_STATUS BOOLEAN DEFAULT false;
ALTER TABLE V3_DATA_PLANES ADD COLUMN IF NOT EXISTS CONNECTIVITY_STATUS_LAST_UPDATED BIGINT DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT);

--     WARNING: do NOT add either column to the V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES
--     refresh trigger in 21-up.sql. They are absent from its UPDATE OF list, which is
--     correct — the view does not read them. Adding them would fire a full
--     REFRESH MATERIALIZED VIEW CONCURRENTLY once a minute for every DP, which is exactly
--     the lock contention 22-up.sql was written to eliminate.

-- 1b. V3_CAPABILITY_INSTANCES — add monitoring health tracking columns
--     MON_ACTIVE deliberately omitted (PCP-20152 decision 2026-06-18): monitoring active
--     filter not needed; V3_CAPABILITY_INSTANCES is authoritative (archive lifecycle).
--     PCP-24285: same default as 1a, for the same reason — the column is added onto rows that
--     already exist, so without it every capability instance present at upgrade time reads
--     back NULL/0. The DP roll-up reds capabilities off the DP's timestamp rather than this
--     one (generateTempTrafficLightsResp passes tableData.LastUpdated), so this is not the
--     column that caused the red — but leaving it NULL would surface as a 1970 "last updated"
--     on the UI and keeps the same zero-means-never trap one refactor away.
ALTER TABLE V3_CAPABILITY_INSTANCES ADD COLUMN IF NOT EXISTS MON_LAST_STATUS_UPDATED BIGINT DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT);
ALTER TABLE V3_CAPABILITY_INSTANCES ADD COLUMN IF NOT EXISTS MON_MESSAGE TEXT;

-- 1c. V3_RESOURCE_INSTANCES — add monitoring health tracking columns
--     MON_ACTIVE deliberately omitted (same decision as 1a/1b).
ALTER TABLE V3_RESOURCE_INSTANCES ADD COLUMN IF NOT EXISTS MON_LAST_STATUS_UPDATED BIGINT;
ALTER TABLE V3_RESOURCE_INSTANCES ADD COLUMN IF NOT EXISTS MON_MESSAGE TEXT;

-- ============================================================================
-- SECTION 2: New monitoring-only tables
-- ============================================================================

-- 2a. V3_CAPABILITY_INSTANCE_SERVICES_STATUS (was MON_SERVICES — PCP-23429)
--     Per-service health within a capability instance.
--     No equivalent in tscutdb.
--     INSTANCE_ID is named CAPABILITY_INSTANCE_ID here, matching what it actually
--     references and the column name used on V3_CAPABILITY_INSTANCES (PCP-23429).
--     NOTE: no FK to V3_CAPABILITY_INSTANCES. The namespace-as-resource
--     migration (21-up.sql/22-up.sql, PCP-17xxx) rebuilt that table's PK into a
--     composite key, so CAPABILITY_INSTANCE_ID is no longer a unique/PK column and
--     a single-column FK to it cannot be created (Postgres: "there is no unique
--     constraint matching given keys for referenced table"). Dropping the FK matches
--     the precedent set in the tp-cp-user-subscriptions testdata 23-up.sql (PCP-20601),
--     applied by hand on live o11y-10/o11y-16. See PCP-19871 / PCP-20152.

CREATE TABLE IF NOT EXISTS V3_CAPABILITY_INSTANCE_SERVICES_STATUS (
                                                                      NAME VARCHAR(50),
    CAPABILITY_INSTANCE_ID VARCHAR(255),
    STATUS VARCHAR(16),
    LAST_UPDATED INT,
    MESSAGE TEXT,
    PRIMARY KEY (NAME, CAPABILITY_INSTANCE_ID)
    );

-- 2b. V3_HOMEPAGE_METRICS (was MON_HOMEPAGE_METRICS — PCP-23429)
--     Aggregated metrics for homepage display, refreshed hourly by cron.

CREATE TABLE IF NOT EXISTS V3_HOMEPAGE_METRICS (
                                                   SUBSCRIPTION_ID VARCHAR(50),
    CAPABILITY_ID VARCHAR(50),
    METRIC_ID VARCHAR(50),
    REGION VARCHAR(50),
    HOST_CLOUD_TYPE VARCHAR(50),
    HISTORY jsonb,
    LAST_UPDATED INT,
    CONSTRAINT V3_HOMEPAGE_METRICS_PKEY PRIMARY KEY (SUBSCRIPTION_ID, METRIC_ID, CAPABILITY_ID, REGION, HOST_CLOUD_TYPE)
    );

-- 2c. MON_DP_CONNECTIVITY_STATUS — REMOVED (PCP-23425)
--
-- Was a rename of monitoring-service's TIBTUNNEL_STATUS: a 1:1 satellite of
-- V3_DATA_PLANES holding a boolean and a timestamp, refreshed every minute by the
-- tibTunnelRefresh cron. Both columns now live on V3_DATA_PLANES itself (SECTION 1a) as
-- CONNECTIVITY_STATUS / CONNECTIVITY_STATUS_LAST_UPDATED.
--
-- WHY IT HAD TO GO, not just tidiness:
--   FK_MON_CONN_DATAPLANE referenced V3_DATA_PLANES(DP_ID) with no ON DELETE CASCADE,
--   while MON_INSERT_CONN_STATUS gave EVERY registered DP a row here. So every data
--   plane permanently owned a child row that blocked its own deletion, and no DP could
--   be deleted at all — UI or API — with:
--     pq: update or delete on table "v3_data_planes" violates foreign key constraint
--         "fk_mon_conn_dataplane" on table "mon_dp_connectivity_status"
--   That FK has no counterpart in monitoring-service main, where this table lived in
--   monitoringdb — a different database from tscutdb — so Postgres could not have
--   expressed it. It was a pure artefact of collapsing the two databases into one.
--   Folding the columns in removes the parent/child relationship entirely, so the whole
--   class of failure becomes impossible rather than patched with ON DELETE CASCADE.
--
-- The two triggers and two functions go with it:
--   MON_INSERT_CONN_STATUS  — replaced by DEFAULT false on the new column.
--   MON_SET_CONN_LAST_UPDATED — the timestamp is now written by the application in the
--     same UPDATE as the status, matching how MON_LAST_STATUS_UPDATED is already handled
--     (insertValues.go). That also removes a clock mismatch: the trigger stamped the
--     DATABASE clock while checkIfOldStatus compares against the ORCHESTRATOR clock.
--
-- No data migration: 25-up.sql is unreleased, so the only rows anywhere are on test
-- clusters, and the tibTunnelRefresh cron repopulates both columns within 60 seconds.
-- Until it does, DEFAULT false plus a NULL timestamp reads as "stale, tunnel down",
-- which is the same conclusion the old empty table produced.

DROP TRIGGER IF EXISTS MON_INSERT_CONN_STATUS ON V3_DATA_PLANES;
DROP FUNCTION IF EXISTS MON_PROC_INSERT_CONN_STATUS() CASCADE;
DROP FUNCTION IF EXISTS MON_TRIGGER_SET_CONN_LAST_UPDATED() CASCADE;
DROP TABLE IF EXISTS MON_DP_CONNECTIVITY_STATUS;

-- PCP-23723: remove the finops migration marker. migrate_finops.sh used to create this table
-- itself, at runtime, to record "I have already run" — a table in tscutdb that no schema file
-- declared. It is gone from the script, and dropped here so control planes that already have one
-- are cleaned up rather than left carrying an orphan.
--
-- The migration is now safe to run on every upgrade instead of being gated on this marker: the
-- four dated telemetry tables insert with ON CONFLICT DO NOTHING, and the homepage merge is
-- trimmed to the live 30-day window so it cannot re-inject dates that have already aged out.
--
-- Dropping it also closes a real gap. Under the marker, anything written to monitoringdb while a
-- control plane was rolled back was stranded for ever — the marker survived the rollback, so the
-- next upgrade skipped the migration entirely. Demonstrated on ins-orchmon-0409-01.
DROP TABLE IF EXISTS MON_FINOPS_MIGRATION_MARKER;

-- ============================================================================
-- SECTION 3: FinOps metrics tables (historical daily aggregations)
--            Self-contained — no FK to V3_DATA_PLANES.
--            Each row carries its own DATAPLANE_ID + SUBSCRIPTION_ID.
-- ============================================================================

-- 3a. V3_TELEMETRY_RUNNING_APP_INSTANCES
--     No FK to V3_DATA_PLANES: finops tables are self-contained
--     (each row carries DATAPLANE_ID + SUBSCRIPTION_ID).
--     Avoids coupling DP lifecycle to finops data retention.
CREATE TABLE IF NOT EXISTS V3_TELEMETRY_RUNNING_APP_INSTANCES (
                                                                  DATAPLANE_ID VARCHAR,
                                                                  SUBSCRIPTION_ID VARCHAR,
                                                                  APP_ID VARCHAR,
                                                                  CAPABILITY_ID VARCHAR,
                                                                  CONNECTORS VARCHAR,
                                                                  TAGS VARCHAR,
                                                                  RAI NUMERIC,
                                                                  DATED DATE,
                                                                  PRIMARY KEY (DATAPLANE_ID, APP_ID, DATED)
    );

-- 3b. V3_TELEMETRY_CLIENT_CONNECTIONS
CREATE TABLE IF NOT EXISTS V3_TELEMETRY_CLIENT_CONNECTIONS (
                                                               DATAPLANE_ID VARCHAR,
                                                               SUBSCRIPTION_ID VARCHAR,
                                                               CAPABILITY_ID VARCHAR,
                                                               CAPABILITY_INSTANCE_ID VARCHAR,
                                                               CONNECTIONS NUMERIC,
                                                               DATED DATE,
                                                               PRIMARY KEY (DATAPLANE_ID, CAPABILITY_ID, CAPABILITY_INSTANCE_ID, DATED)
    );

-- 3c. V3_TELEMETRY_ADAPTERS
CREATE TABLE IF NOT EXISTS V3_TELEMETRY_ADAPTERS (
                                                     DATAPLANE_ID VARCHAR,
                                                     SUBSCRIPTION_ID VARCHAR,
                                                     CAPABILITY_ID VARCHAR,
                                                     ADAPTERS VARCHAR,
                                                     DATED DATE,
                                                     PRIMARY KEY (DATAPLANE_ID, CAPABILITY_ID, DATED)
    );

-- 3d. V3_TELEMETRY_PROCESSORS
CREATE TABLE IF NOT EXISTS V3_TELEMETRY_PROCESSORS (
                                                       DATAPLANE_ID VARCHAR,
                                                       SUBSCRIPTION_ID VARCHAR,
                                                       CAPABILITY_ID VARCHAR,
                                                       AGENT_IP VARCHAR,
                                                       PROCESSORS NUMERIC,
                                                       DATED DATE,
                                                       PRIMARY KEY (DATAPLANE_ID, AGENT_IP, CAPABILITY_ID, DATED)
    );

-- ============================================================================
-- SECTION 4: Indexes
-- ============================================================================
-- (none — idx_mon_ci_active removed; MON_ACTIVE dropped per PCP-20152 decision 2026-06-18)

-- Update database schema at the end (earlier version is 1.19.0 i.e. 22)

UPDATE schema_version SET version = 25;
