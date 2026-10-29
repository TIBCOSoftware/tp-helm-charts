-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback database schema changes for PCP-10543 (reverse of 25-up.sql)

-- ============================================================================
-- PCP-10543: Recreate raw-subscription and raw-user tables, archive tables,
-- and trigger function that were dropped in 25-up.sql.
-- ============================================================================

-- 1. V2_ARCHIVED_RAW_SUBSCRIPTIONS

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_RAW_SUBSCRIPTIONS (
    ID VARCHAR(255) NOT NULL,
    RAW_PAYLOAD JSON NOT NULL,
    EMAIL VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255),
    SUBSCRIPTION_ID VARCHAR(255),
    REGION VARCHAR(255),
    IAAS_VENDOR VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    LOGS TEXT,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    CATEGORY VARCHAR(255) NOT NULL,
    ACTIVATION_URL TEXT,
    START_DATE BIGINT,
    IT_NOTIFICATION_RESPONSE JSONB,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP),
    ORIGINAL_CATEGORY VARCHAR(255)
);

-- 2. V2_ARCHIVED_RAW_USERS

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_RAW_USERS (
    ID VARCHAR(255) NOT NULL,
    EMAIL VARCHAR(255) NOT NULL,
    FIRSTNAME VARCHAR(255) NOT NULL,
    LASTNAME VARCHAR(255) NOT NULL,
    COMPANYNAME VARCHAR(255),
    STATE VARCHAR(255),
    COUNTRY VARCHAR(255),
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP)
);

-- 3. V2_RAW_SUBSCRIPTIONS

CREATE TABLE IF NOT EXISTS V2_RAW_SUBSCRIPTIONS (
    ID VARCHAR(255) NOT NULL PRIMARY KEY,
    RAW_PAYLOAD JSON NOT NULL,
    EMAIL VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255),
    SUBSCRIPTION_ID VARCHAR(255),
    REGION VARCHAR(255),
    IAAS_VENDOR VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    LOGS TEXT,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    CATEGORY VARCHAR(255) NOT NULL,
    ACTIVATION_URL TEXT,
    START_DATE BIGINT,
    IT_NOTIFICATION_RESPONSE JSONB,
    ORIGINAL_CATEGORY VARCHAR(255),

    CONSTRAINT V2_RAW_SUBSCRIPTIONS_FK1 FOREIGN KEY (SUBSCRIPTION_TYPE) REFERENCES V2_EXTERNAL_ACCOUNT_TYPES(EXTERNAL_ACCOUNT_TYPE)
);

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_RAW_SUBSCRIPTIONS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_RAW_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- Trigger function: validates new records before insertion — checks for
-- duplicate (email, tenant_id, category) for DPL_CHECK and CONTROLLED_TRIAL.

DROP FUNCTION IF EXISTS VALIDATE_RAW_SUBSCRIPTION() CASCADE;
CREATE FUNCTION VALIDATE_RAW_SUBSCRIPTION()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    PERFORM *
    FROM v2_raw_subscriptions
    WHERE tenant_id = new.tenant_id
      AND category = new.category
      AND email = new.email
      AND new.category IN ('DPL_CHECK', 'CONTROLLED_TRIAL');
    IF FOUND THEN
        RAISE 'Violates unique constraint for category %',new.category USING ERRCODE = 'unique_violation';
    END IF;
    NEW.CREATED_TIME = (SELECT cast(EXTRACT(EPOCH FROM NOW()) AS BIGINT));
    NEW.MODIFIED_TIME = (SELECT cast(EXTRACT(EPOCH FROM NOW()) AS BIGINT));
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS VALIDATE_RAW_SUBSCRIPTION_INSERT ON V2_RAW_SUBSCRIPTIONS;
CREATE TRIGGER VALIDATE_RAW_SUBSCRIPTION_INSERT BEFORE INSERT ON V2_RAW_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE VALIDATE_RAW_SUBSCRIPTION();

-- 4. V2_RAW_USERS

CREATE TABLE IF NOT EXISTS V2_RAW_USERS (
    ID VARCHAR(255) NOT NULL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL UNIQUE,
    FIRSTNAME VARCHAR(255) NOT NULL,
    LASTNAME VARCHAR(255) NOT NULL,
    COMPANYNAME VARCHAR(255),
    STATE VARCHAR(255),
    COUNTRY VARCHAR(255),
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL
);

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_RAW_USERS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_RAW_USERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_RAW_USERS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_RAW_USERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();


-- ============================================================================
-- PCP-19871 (orch-mon merge) — appended after the changes above, which came from
-- main. The two halves are independent: main's drops the raw-subscription/raw-user
-- tables, this one retires monitoringdb by adding the monitoring columns and tables
-- to tscutdb. Both share schema version 25, so the single update below covers both.
-- ============================================================================

-- Rollback database schema changes for 1.22.0 (reverse of 25-up.sql)
-- PCP-19871 (orch-mon merge) / PCP-23012 (finops data migration) / PCP-23723

-- ============================================================================
-- DESTRUCTIVE BY DESIGN
-- ============================================================================
-- This rollback is a true reverse of 25-up.sql: every table it created and every column it added
-- are dropped. Data loss is accepted and intended (PCP-23723).
--
-- That is only safe because of the other half of PCP-23723: monitoringdb is NEVER dropped. It is
-- retired the PCP-6689 way, by `monitoringdb: -1` in version-map.yaml, which makes
-- resolve_target_schema_version skip it. A fresh install never creates it; an existing one keeps
-- it, orphaned but intact. So the original finops data is still sitting in monitoringdb when this
-- runs, and rolling forward re-migrates it in full.
--
-- The two decisions depend on each other. If monitoringdb were ever dropped again, this file would
-- destroy the only remaining copy and MUST be made non-destructive at the same time.
--
-- Rolling forward is safe: every statement in 25-up.sql is IF NOT EXISTS or an idempotent
-- CREATE OR REPLACE, verified live by rolling 1.20 -> alpha.010 over retained objects.
--
-- WHAT THIS FIXES. The previous version of this file dropped nothing, to protect the migrated
-- data. That preserved MON_FINOPS_MIGRATION_MARKER across a rollback, so the next upgrade saw the
-- marker, skipped the migration, and permanently stranded everything the old monitoring-service
-- had written to monitoringdb during the rollback window. Demonstrated on ins-orchmon-0409-01: a
-- row inserted while rolled back to 1.20.106 never appeared in tscutdb after rolling forward.
-- Dropping everything here — the marker included, via 25-up.sql — means the migration simply runs
-- again and picks that window up.
--
-- NOT REVERSED, deliberately: MON_DP_CONNECTIVITY_STATUS. 25-up.sql drops it (PCP-23425) and this
-- file does not bring it back. No up script has ever created it — it only existed on development
-- clusters from an earlier iteration of this branch — and its FK to V3_DATA_PLANES is what made
-- data planes undeletable in the first place. Recreating it would restore a known-broken state.
--
-- NOT DROPPED, because 25-up.sql did not add them: MONITORING_STATUS on any table. Those columns
-- pre-date the merge. Dropping them would break the older build this rollback exists to serve.
--
-- WHY THIS FILE MUST EXIST AT ALL:
-- downgradeDBSchema() in postgres-helper.bash does not write SCHEMA_VERSION itself — each
-- N-down.sql does it. A missing down script is only a WARNING there: the loop logs
-- "Skipping rollback for version N", decrements its own counter and reports success, leaving
-- SCHEMA_VERSION untouched in the database. Rolling back to a chart that expects 23 would
-- therefore leave the row saying 24, and every service's check-sql-schema-version init container
-- would block on "Current: 24, Expected: 23" until the helm install times out on --wait — with no
-- error logged anywhere.
-- ============================================================================

-- SECTION 3 reverse: FinOps metrics tables.
DROP TABLE IF EXISTS V3_TELEMETRY_RUNNING_APP_INSTANCES;
DROP TABLE IF EXISTS V3_TELEMETRY_CLIENT_CONNECTIONS;
DROP TABLE IF EXISTS V3_TELEMETRY_ADAPTERS;
DROP TABLE IF EXISTS V3_TELEMETRY_PROCESSORS;

-- SECTION 2 reverse: homepage metrics and per-service status.
DROP TABLE IF EXISTS V3_HOMEPAGE_METRICS;
DROP TABLE IF EXISTS V3_CAPABILITY_INSTANCE_SERVICES_STATUS;

-- SECTION 1 reverse: the monitoring columns added to the three existing V3 tables.
-- Exactly the eight ADD COLUMN statements in 25-up.sql, and nothing else.
ALTER TABLE V3_DATA_PLANES          DROP COLUMN IF EXISTS MON_LAST_STATUS_UPDATED;
ALTER TABLE V3_DATA_PLANES          DROP COLUMN IF EXISTS MON_MESSAGE;
ALTER TABLE V3_DATA_PLANES          DROP COLUMN IF EXISTS CONNECTIVITY_STATUS;
ALTER TABLE V3_DATA_PLANES          DROP COLUMN IF EXISTS CONNECTIVITY_STATUS_LAST_UPDATED;

ALTER TABLE V3_CAPABILITY_INSTANCES DROP COLUMN IF EXISTS MON_LAST_STATUS_UPDATED;
ALTER TABLE V3_CAPABILITY_INSTANCES DROP COLUMN IF EXISTS MON_MESSAGE;

ALTER TABLE V3_RESOURCE_INSTANCES   DROP COLUMN IF EXISTS MON_LAST_STATUS_UPDATED;
ALTER TABLE V3_RESOURCE_INSTANCES   DROP COLUMN IF EXISTS MON_MESSAGE;

UPDATE schema_version SET version = 24;
