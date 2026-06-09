-- Database schema changes for 1.18.0

-- PCP-13185 [tp-helm-charts]Add a new table email_config in user-sub db to store data of configured email
CREATE TABLE IF NOT EXISTS V3_EMAIL_CONFIG (
                                               email_config_id VARCHAR(255) PRIMARY KEY,
    email_type VARCHAR(255),
    details JSONB,
    created_by VARCHAR(255),
    modified_by VARCHAR(255),
    created_time VARCHAR(255),
    modified_time VARCHAR(255)
    );

--Trigger function for v3_email_config changes
CREATE OR REPLACE FUNCTION V3_EMAIL_CONFIG_NOTIFY_EVENT()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_notify('v3_email_config_events', 'NOTIFY v3_email_config_events');
RETURN NEW;
END;
$$;

--Trigger for INSERT, UPDATE, DELETE
DROP TRIGGER IF EXISTS V3_EMAIL_CONFIG_NOTIFY_EVENT_TRIGGER ON V3_EMAIL_CONFIG;

CREATE TRIGGER V3_EMAIL_CONFIG_NOTIFY_EVENT_TRIGGER
    AFTER INSERT OR UPDATE OR DELETE ON V3_EMAIL_CONFIG
    FOR EACH ROW EXECUTE FUNCTION V3_EMAIL_CONFIG_NOTIFY_EVENT();

-- Add host_cloud_type 'control-tower' for resource GATEWAYAPI PCP-17658
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{k8s,control-tower}' WHERE RESOURCE_ID = 'GATEWAYAPI' AND RESOURCE_LEVEL = 'PLATFORM';

--Add traefik controller for gateway api PCP-17659
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"gatewayAPIControllerName","enum":["nginx","GKE","Istio","traefik"],"name":"Gateway API Controller Name","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"gatewayName","name":"Gateway Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayNamespace","name":"Gateway Namespace","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayHostOrDomainName","name":"Host/Domain Name","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"gatewaySectionName","name":"Section Name","dataType":"string","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$","required":false,"maxLength":"253"}]}'
WHERE RESOURCE_ID = 'GATEWAYAPI' AND RESOURCE_LEVEL = 'PLATFORM';

--Add 'Other Gateway API Controller' controller for gateway api PCP-17361
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"gatewayAPIControllerName","enum":["nginx","GKE","Istio","traefik","other"],"name":"Gateway API Controller Name","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"gatewayName","name":"Gateway Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayNamespace","name":"Gateway Namespace","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayHostOrDomainName","name":"Host/Domain Name","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"gatewaySectionName","name":"Section Name","dataType":"string","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$","required":false,"maxLength":"253"}]}'
WHERE RESOURCE_ID = 'GATEWAYAPI' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource INGRESS PCP-17658
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{aws,azure,control-tower}' WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';

--Add 'NetScaler Controller' controller for gateway api PCP-18523
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"gatewayAPIControllerName","enum":["nginx","GKE","Istio","traefik","other","NetScaler"],"name":"Gateway API Controller Name","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"gatewayName","name":"Gateway Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayNamespace","name":"Gateway Namespace","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayHostOrDomainName","name":"Host/Domain Name","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"gatewaySectionName","name":"Section Name","dataType":"string","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$","required":false,"maxLength":"253"}]}'
WHERE RESOURCE_ID = 'GATEWAYAPI' AND RESOURCE_LEVEL = 'PLATFORM';

--Updated regex expression(^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$) for gatewayHostOrDomainName to  PCP-19000
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"gatewayAPIControllerName","enum":["nginx","GKE","Istio","traefik","other","NetScaler"],"name":"Gateway API Controller Name","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"gatewayName","name":"Gateway Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayNamespace","name":"Gateway Namespace","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"gatewayHostOrDomainName","name":"Host/Domain Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"gatewaySectionName","name":"Section Name","dataType":"string","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$","required":false,"maxLength":"253"}]}'
WHERE RESOURCE_ID = 'GATEWAYAPI' AND RESOURCE_LEVEL = 'PLATFORM';

--Updated regex expression(^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$) for FQDN to  PCP-19000
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"ingressController","enum":["nginx","kong","traefik","openshiftRouter", "haProxy"],"name":"Ingress Controller","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"ingressClassName","name":"Ingress Class Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"fqdn","name":"Default FQDN","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"annotations","name":"Annotations","dataType":"array","required":false,"maxLength":"255"}]}'
WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Namespace as Resource Instance — consolidated migration.
-- NAMESPACE/NAMESPACES columns are retained for this release; column drops deferred to 22-up.sql.
-- Safe to run multiple times: uses IF NOT EXISTS, ON CONFLICT, IS NULL guards, DROP IF EXISTS.

-- ============================================================================
-- PHASE 0: Make retained NAMESPACE/NAMESPACES columns nullable
--          Code no longer writes these columns; NOT NULL would break INSERTs.
--          NAMESPACE is part of v3_capability_instances PK, so rebuild PK first.
-- ============================================================================
ALTER TABLE v3_apps ALTER COLUMN namespace DROP NOT NULL;
ALTER TABLE v3_capability_instances DROP CONSTRAINT IF EXISTS V3_CAPABILITY_INSTANCES_PKEY;
ALTER TABLE v3_capability_instances ALTER COLUMN namespace DROP NOT NULL;
ALTER TABLE v3_capability_instances ADD CONSTRAINT V3_CAPABILITY_INSTANCES_PKEY
  PRIMARY KEY (CAPABILITY_INSTANCE_ID, CAPABILITY_ID, VERSION, DP_ID);
ALTER TABLE v3_data_planes ALTER COLUMN namespaces DROP NOT NULL;
ALTER TABLE v3_archived_apps ALTER COLUMN namespace DROP NOT NULL;
ALTER TABLE v3_archived_capability_instances ALTER COLUMN namespace DROP NOT NULL;
ALTER TABLE v3_archived_data_planes ALTER COLUMN namespaces DROP NOT NULL;

-- ============================================================================
-- PHASE 1: Create NAMESPACE resource template and migrate existing data
-- ============================================================================

-- 1. Add NAMESPACE resource template (idempotent via ON CONFLICT)
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('NAMESPACE', 'Kubernetes Namespace', 'Kubernetes Namespace on a Data Plane', 'Namespace',
        '{"fields":[{"name":"Namespace Name","key":"namespaceName","dataType":"string","required":true},{"name":"Is Primary","key":"isPrimary","dataType":"boolean","required":true},{"name":"Is Discovered","key":"isDiscovered","dataType":"boolean","required":false}]}',
        '{"k8s","control-tower"}', 'PLATFORM')
ON CONFLICT DO NOTHING;

-- Helper: generate ULID (26-char Crockford base32) matching Go runtime uid.GetChronologicalUniqueId() format.
-- Encodes current millisecond timestamp (10 chars) + 16 random chars from gen_random_uuid().
CREATE OR REPLACE FUNCTION generate_ulid() RETURNS TEXT AS $$
DECLARE
    encoding CONSTANT TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    timestamp_ms BIGINT;
    ts_part TEXT := '';
    rand_part TEXT;
    i INT;
BEGIN
    -- Timestamp part: 48-bit ms since epoch → 10 Crockford base32 chars
    timestamp_ms := (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;
    FOR i IN 1..10 LOOP
        ts_part := substr(encoding, (timestamp_ms & 31)::INT + 1, 1) || ts_part;
        timestamp_ms := timestamp_ms >> 5;
    END LOOP;

    -- Random part: 16 uppercase hex chars from uuid (0-9,A-F are valid Crockford base32)
    rand_part := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 16));

    RETURN ts_part || rand_part;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- BEGIN TRANSACTION: Everything from here to COMMIT is atomic.
-- On failure -> automatic ROLLBACK -> all functions revert to original bodies,
-- matviews unchanged, triggers unchanged, no partial state.
-- ============================================================================
BEGIN;

-- Lock tables to prevent concurrent writes from causing lost updates during
-- array_append operations on resource_instance_ids. Services wait until COMMIT.
LOCK TABLE v3_data_planes IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE v3_resource_instances IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE v3_capability_instances IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE v3_apps IN SHARE ROW EXCLUSIVE MODE;

-- ============================================================================
-- PHASE 1b: Replace trigger functions with no-ops to prevent deadlocks and
--           validation errors during migration.
--           Uses CREATE OR REPLACE (no table locks, transaction-safe).
--           Other sessions still see original function bodies (MVCC isolation).
-- ============================================================================

-- Matview refresh functions -> no-op (prevents deadlock from ExclusiveLock)
CREATE OR REPLACE FUNCTION V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;
CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;
CREATE OR REPLACE FUNCTION V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;
CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;
CREATE OR REPLACE FUNCTION V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;
CREATE OR REPLACE FUNCTION V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;

-- Validation functions -> no-op (prevents orphaned ID rejection during backfill)
CREATE OR REPLACE FUNCTION V3_VALIDATE_RESOURCE_INSTANCE_ID() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END; $$;
CREATE OR REPLACE FUNCTION V3_VALIDATE_APPS_RESOURCE_INSTANCE_ID() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END; $$;

-- Notification function -> no-op
CREATE OR REPLACE FUNCTION notify_dp_namespaces_change() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END; $$;

-- 2. Migrate existing namespaces from v3_data_planes.NAMESPACES to v3_resource_instances.
--    First element in NAMESPACES array is the primary namespace; rest are secondary.
--    Each namespace resource instance is linked to the dataplane via resource_instance_ids.
--    Idempotent: only runs if NAMESPACES column still exists.
DO $$
DECLARE
    dp_record RECORD;
    ns_name TEXT;
    ns_index INT;
    ri_id TEXT;
    is_primary BOOLEAN;
    ns_description TEXT;
    metadata JSONB;
    has_namespaces_col BOOLEAN;
BEGIN
    -- Check if NAMESPACES column still exists (skip if already dropped by prior run)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'v3_data_planes' AND column_name = 'namespaces'
    ) INTO has_namespaces_col;

    IF NOT has_namespaces_col THEN
        RAISE NOTICE 'NAMESPACES column already dropped, skipping namespace migration';
        RETURN;
    END IF;

    FOR dp_record IN
        SELECT dp_id, namespaces, running_region
        FROM v3_data_planes
        WHERE namespaces IS NOT NULL AND array_length(namespaces, 1) > 0
    LOOP
        ns_index := 0;
        FOREACH ns_name IN ARRAY dp_record.namespaces
        LOOP
            ns_index := ns_index + 1;
            is_primary := (ns_index = 1);

            -- Skip if this namespace already has a resource instance for this dataplane
            IF EXISTS (
                SELECT 1 FROM v3_resource_instances
                WHERE resource_id = 'NAMESPACE'
                  AND scope = 'DATAPLANE'
                  AND scope_id = dp_record.dp_id
                  AND resource_instance_metadata->'fields' @> ('[{"key":"namespaceName","value":"' || ns_name || '"}]')::jsonb
            ) THEN
                CONTINUE;
            END IF;

            ri_id := generate_ulid();

            IF is_primary THEN
                ns_description := 'Primary namespace for data plane';
            ELSE
                ns_description := 'Secondary namespace for data plane';
            END IF;

            metadata := jsonb_build_object(
                'fields', jsonb_build_array(
                    jsonb_build_object('key', 'namespaceName', 'value', ns_name,
                        'name', 'Namespace Name', 'dataType', 'string', 'required', true),
                    jsonb_build_object('key', 'isPrimary', 'value', is_primary,
                        'name', 'Is Primary', 'dataType', 'boolean', 'required', true),
                    jsonb_build_object('key', 'isDiscovered', 'value', false,
                        'name', 'Is Discovered', 'dataType', 'boolean', 'required', false)
                )
            );

            -- Insert namespace resource instance
            INSERT INTO v3_resource_instances (
                resource_instance_id, resource_id, resource_instance_name,
                resource_instance_description, scope, scope_id, region,
                resource_instance_metadata, created_by, modified_by,
                created_time, modified_time, resource_level
            ) VALUES (
                ri_id, 'NAMESPACE', ns_name,
                ns_description, 'DATAPLANE', dp_record.dp_id, dp_record.running_region,
                metadata, 'migration-21', 'migration-21',
                EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT, EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
                'PLATFORM'
            );

            -- Link resource instance to dataplane
            UPDATE v3_data_planes
            SET resource_instance_ids = array_append(COALESCE(resource_instance_ids, '{}'), ri_id)
            WHERE dp_id = dp_record.dp_id;

        END LOOP;
    END LOOP;
END $$;

-- ============================================================================
-- PHASE 2: Backfill namespace RI IDs into RESOURCE_INSTANCE_IDS arrays
--          (directly into RESOURCE_INSTANCE_IDS)
-- ============================================================================

-- 3. Backfill namespace RI ID into v3_apps.RESOURCE_INSTANCE_IDS
--    Looks up the NAMESPACE RI for each app's (dp_id, namespace) pair.
--    Idempotent: only runs if NAMESPACE column still exists.
DO $$
DECLARE
    has_namespace_col BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'v3_apps' AND column_name = 'namespace'
    ) INTO has_namespace_col;

    IF has_namespace_col THEN
        EXECUTE '
            UPDATE V3_APPS A
            SET RESOURCE_INSTANCE_IDS = array_append(COALESCE(A.RESOURCE_INSTANCE_IDS, ''{}''), RI.RESOURCE_INSTANCE_ID::TEXT)
            FROM V3_RESOURCE_INSTANCES RI
            WHERE RI.RESOURCE_ID = ''NAMESPACE''
              AND RI.SCOPE = ''DATAPLANE''
              AND RI.SCOPE_ID = A.DP_ID
              AND RI.RESOURCE_INSTANCE_METADATA->''fields'' @> (''[{"key":"namespaceName","value":"'' || A.NAMESPACE || ''"}]'')::jsonb
              AND (A.RESOURCE_INSTANCE_IDS IS NULL
                   OR NOT RI.RESOURCE_INSTANCE_ID = ANY(A.RESOURCE_INSTANCE_IDS))
        ';
    END IF;
END $$;

-- 4. Backfill namespace RI ID into v3_capability_instances.RESOURCE_INSTANCE_IDS
DO $$
DECLARE
    has_namespace_col BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'v3_capability_instances' AND column_name = 'namespace'
    ) INTO has_namespace_col;

    IF has_namespace_col THEN
        EXECUTE '
            UPDATE V3_CAPABILITY_INSTANCES CI
            SET RESOURCE_INSTANCE_IDS = array_append(COALESCE(CI.RESOURCE_INSTANCE_IDS, ''{}''), RI.RESOURCE_INSTANCE_ID::TEXT)
            FROM V3_RESOURCE_INSTANCES RI
            WHERE RI.RESOURCE_ID = ''NAMESPACE''
              AND RI.SCOPE = ''DATAPLANE''
              AND RI.SCOPE_ID = CI.DP_ID
              AND RI.RESOURCE_INSTANCE_METADATA->''fields'' @> (''[{"key":"namespaceName","value":"'' || CI.NAMESPACE || ''"}]'')::jsonb
              AND (CI.RESOURCE_INSTANCE_IDS IS NULL
                   OR NOT RI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS))
        ';
    END IF;
END $$;

-- 5. Backfill archived capability instances
DO $$
DECLARE
    has_namespace_col BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'v3_archived_capability_instances' AND column_name = 'namespace'
    ) INTO has_namespace_col;

    IF has_namespace_col THEN
        EXECUTE '
            UPDATE V3_ARCHIVED_CAPABILITY_INSTANCES CI
            SET RESOURCE_INSTANCE_IDS = array_append(COALESCE(CI.RESOURCE_INSTANCE_IDS, ''{}''), RI.RESOURCE_INSTANCE_ID::TEXT)
            FROM V3_RESOURCE_INSTANCES RI
            WHERE RI.RESOURCE_ID = ''NAMESPACE''
              AND RI.SCOPE = ''DATAPLANE''
              AND RI.SCOPE_ID = CI.DP_ID
              AND RI.RESOURCE_INSTANCE_METADATA->''fields'' @> (''[{"key":"namespaceName","value":"'' || CI.NAMESPACE || ''"}]'')::jsonb
              AND (CI.RESOURCE_INSTANCE_IDS IS NULL
                   OR NOT RI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS))
        ';
    END IF;
END $$;

-- 6. Backfill archived apps (add RESOURCE_INSTANCE_IDS column if missing)
ALTER TABLE V3_ARCHIVED_APPS ADD COLUMN IF NOT EXISTS RESOURCE_INSTANCE_IDS TEXT[];

DO $$
DECLARE
    has_namespace_col BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'v3_archived_apps' AND column_name = 'namespace'
    ) INTO has_namespace_col;

    IF has_namespace_col THEN
        EXECUTE '
            UPDATE V3_ARCHIVED_APPS A
            SET RESOURCE_INSTANCE_IDS = array_append(COALESCE(A.RESOURCE_INSTANCE_IDS, ''{}''), RI.RESOURCE_INSTANCE_ID::TEXT)
            FROM V3_RESOURCE_INSTANCES RI
            WHERE RI.RESOURCE_ID = ''NAMESPACE''
              AND RI.SCOPE = ''DATAPLANE''
              AND RI.SCOPE_ID = A.DP_ID
              AND RI.RESOURCE_INSTANCE_METADATA->''fields'' @> (''[{"key":"namespaceName","value":"'' || A.NAMESPACE || ''"}]'')::jsonb
              AND (A.RESOURCE_INSTANCE_IDS IS NULL
                   OR NOT RI.RESOURCE_INSTANCE_ID = ANY(A.RESOURCE_INSTANCE_IDS))
        ';
    END IF;
END $$;

-- ============================================================================
-- PHASE 4: Recreate materialized views with RI-based namespace lookups
-- ============================================================================

-- 13a0. V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE (originally defined in 18-up.sql, references CI.NAMESPACE)
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
AS
SELECT
    DP.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAME AS DP_NAME,
    CI.CAPABILITY_ID,
    (SELECT f->>'value'
     FROM V3_RESOURCE_INSTANCES RI,
          jsonb_array_elements(RI.RESOURCE_INSTANCE_METADATA->'fields') AS f
     WHERE RI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS)
       AND RI.RESOURCE_ID = 'NAMESPACE'
       AND f->>'key' = 'namespaceName'
     ORDER BY CASE WHEN RI.RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END
     LIMIT 1) AS NAMESPACE,
    CI.VERSION,
    CI.STATUS,
    CI.REGION,
    CI.CREATED_TIME,
    CI.MODIFIED_TIME,
    (select CONCAT(U.firstname || ' ',lastname) from v2_users U where U.USER_ENTITY_ID = CI.MODIFIED_BY)
        as MODIFIED_BY,
    (select CONCAT(U.firstname|| ' ',lastname) from v2_users U where U.USER_ENTITY_ID = CI.CREATED_BY)
        as CREATED_BY,
    CI.TAGS,
    CI.CAPABILITY_INSTANCE_ID,
    CI.CAPABILITY_INSTANCE_NAME,
    CI.CAPABILITY_INSTANCE_DESCRIPTION,
    COALESCE(
            (
                SELECT JSON_AGG(
                               JSON_BUILD_OBJECT(
                                       'id', RI.RESOURCE_INSTANCE_ID,
                                       'name', RI.RESOURCE_INSTANCE_NAME
                               )
                       )
                FROM V3_RESOURCE_INSTANCES RI
                WHERE RI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS)
            ),
            '[]'::JSON
    ) AS "resource_instances",
    CI.CAPABILITY_TYPE
FROM V3_CAPABILITY_INSTANCES CI
         LEFT JOIN V3_DATA_PLANES DP
                   USING(DP_ID)
WHERE CI.CAPABILITY_TYPE = 'PLATFORM'
    WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_INDEX ON V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
    (SUBSCRIPTION_ID, DP_ID,CAPABILITY_INSTANCE_ID);

-- Recreate refresh function and triggers for V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
CREATE OR REPLACE FUNCTION V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, CAPABILITY_INSTANCE_ID, CAPABILITY_ID, CAPABILITY_TYPE, VERSION, STATUS, REGION, CREATED_TIME, MODIFIED_TIME, CREATED_BY, MODIFIED_BY, TAGS, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, RESOURCE_INSTANCE_IDS
              ON V3_CAPABILITY_INSTANCES
                  FOR EACH STATEMENT
                  EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_DP_TRIGGER
    AFTER INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME
                    ON V3_DATA_PLANES
                        FOR EACH STATEMENT
                        EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

-- Refresh when resource instances change (namespace derived from RI)
DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_RI_TRIGGER
    AFTER INSERT OR UPDATE OR DELETE
                    ON V3_RESOURCE_INSTANCES
                        FOR EACH STATEMENT
                        EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

-- 13a. V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (optimized with CTEs)
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES AS
WITH
-- Scan V3_RESOURCE_INSTANCES once for all NAMESPACE/DATAPLANE rows.
-- RESOURCE_INSTANCE_NAME equals the namespaceName field value by data-model contract,
-- so jsonb_array_elements is not needed to extract the name.
ns_ri AS (
    SELECT
        RI.RESOURCE_INSTANCE_ID,
        RI.SCOPE_ID                 AS dp_id,
        RI.RESOURCE_INSTANCE_NAME   AS namespace_name,
        CASE WHEN RI.RESOURCE_INSTANCE_METADATA->'fields'
                  @> '[{"key":"isPrimary","value":true}]'::jsonb
             THEN 0 ELSE 1 END      AS primary_order
    FROM V3_RESOURCE_INSTANCES RI
    WHERE RI.RESOURCE_ID = 'NAMESPACE'
      AND RI.SCOPE       = 'DATAPLANE'
),
-- One TEXT[] of namespace names per dataplane, primary first.
dp_ns AS (
    SELECT dp_id,
           ARRAY_AGG(namespace_name ORDER BY primary_order) AS namespaces
    FROM   ns_ri
    GROUP  BY dp_id
),
-- Primary namespace per capability instance; resolved set-based via unnest.
ci_ns AS (
    SELECT DISTINCT ON (CI.CAPABILITY_INSTANCE_ID)
        CI.CAPABILITY_INSTANCE_ID,
        NS.namespace_name
    FROM  V3_CAPABILITY_INSTANCES CI,
          unnest(CI.RESOURCE_INSTANCE_IDS) AS ri_id
    JOIN  ns_ri NS ON NS.resource_instance_id = ri_id
    ORDER BY CI.CAPABILITY_INSTANCE_ID, NS.primary_order
),
-- Flatten CI + CR + resolved namespace into one row set.
ci_flat AS (
    SELECT
        CI.DP_ID,
        CI.CAPABILITY_INSTANCE_ID,
        CI.CAPABILITY_INSTANCE_NAME,
        CI.CAPABILITY_INSTANCE_DESCRIPTION,
        CI.CAPABILITY_ID,
        CI.VERSION,
        CI.STATUS,
        CI.REGION,
        CI.TAGS,
        CI.MODIFIED_TIME,
        CI.MONITORING_STATUS,
        CR.DISPLAY_NAME,
        CR.CAPABILITY_TYPE,
        cn.namespace_name AS namespace
    FROM  V3_CAPABILITY_INSTANCES CI
    LEFT  JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID, CAPABILITY_TYPE)
    LEFT  JOIN ci_ns cn            USING (CAPABILITY_INSTANCE_ID)
),
-- Aggregate capabilities per dataplane.
ci_agg AS (
    SELECT
        cf.DP_ID,
        json_agg(row_to_json((
            SELECT ColumnName
            FROM (
                SELECT cf.CAPABILITY_INSTANCE_ID,
                       cf.CAPABILITY_INSTANCE_NAME,
                       cf.CAPABILITY_INSTANCE_DESCRIPTION,
                       cf.CAPABILITY_ID,
                       cf.DISPLAY_NAME,
                       cf.CAPABILITY_TYPE,
                       cf.namespace,
                       cf.VERSION, cf.STATUS, cf.REGION, cf.TAGS,
                       cf.MODIFIED_TIME, cf.MONITORING_STATUS
            ) AS ColumnName (
                CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION,
                CAPABILITY_ID, CAPABILITY_NAME, CAPABILITY_TYPE, NAMESPACE,
                VERSION, STATUS, REGION, TAGS, MODIFIED_TIME, MONITORING_STATUS
            )
        ))) AS CAPABILITIES
    FROM   ci_flat cf
    GROUP  BY cf.DP_ID
),
-- Apps aggregation (logic unchanged).
app_agg AS (
    SELECT DP_ID,
           json_agg(row_to_json((
               SELECT ColumnName
               FROM (SELECT A.APP_ID, A.APP_NAME, A.APP_VERSION,
                            A.CAPABILITY_INSTANCE_ID, A.CAPABILITY_ID,
                            A.CAPABILITY_VERSION, A.STATE, A.TAGS, A.MODIFIED_TIME)
                    AS ColumnName (APP_ID, APP_NAME, APP_VERSION,
                                   CAPABILITY_INSTANCE_ID, CAPABILITY_ID,
                                   CAPABILITY_VERSION, STATE, TAGS, MODIFIED_TIME)
           ))) AS APPS
    FROM   V3_APPS A
    GROUP  BY DP_ID
)
SELECT
    DP.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAME,
    DP.DESCRIPTION,
    DP.HOST_CLOUD_TYPE,
    DP.DP_CONFIG,
    DP.STATUS,
    DP.MONITORING_STATUS,
    DP.REGISTERED_REGION,
    DP.RUNNING_REGION,
    DP.MODIFIED_DATE,
    DP.TAGS,
    DP.CONTAINER_REGISTRY_CREDENTIAL,
    DP.CONNECTION_DETAILS,
    COALESCE(dn.namespaces, ARRAY[]::TEXT[]) AS NAMESPACES,
    ci_agg.CAPABILITIES,
    app_agg.APPS,
    RI.RESOURCE_INSTANCE_METADATA
FROM  V3_DATA_PLANES DP
LEFT  JOIN dp_ns    dn    ON dn.dp_id     = DP.DP_ID
LEFT  JOIN ci_agg         ON ci_agg.DP_ID = DP.DP_ID
LEFT  JOIN app_agg        ON app_agg.DP_ID = DP.DP_ID
LEFT  JOIN V3_RESOURCE_INSTANCES RI
          ON RI.SCOPE          = 'DATAPLANE'
         AND RI.SCOPE_ID       = DP.DP_ID
         AND RI.RESOURCE_ID    = 'SERVICEACCOUNT'
         AND RI.RESOURCE_LEVEL = 'INFRA'
WITH DATA;

CREATE UNIQUE INDEX VIEW_DATA_PLANE_CAPABILITY_INSTANCE_INDEX ON V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (DP_ID);

-- Recreate refresh function and triggers for V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES
CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME, DESCRIPTION, HOST_CLOUD_TYPE, DP_CONFIG, STATUS, REGISTERED_REGION, RUNNING_REGION, MODIFIED_DATE, TAGS, CONTAINER_REGISTRY_CREDENTIAL, CONNECTION_DETAILS, RESOURCE_INSTANCE_IDS
ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, CAPABILITY_TYPE, VERSION, STATUS, REGION, TAGS, MODIFIED_TIME, MONITORING_STATUS, RESOURCE_INSTANCE_IDS
ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_APPS_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_APPS_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, APP_ID, APP_NAME, APP_VERSION, CAPABILITY_INSTANCE_ID, CAPABILITY_ID, CAPABILITY_VERSION, STATE, TAGS, MODIFIED_TIME
ON V3_APPS
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

-- 13b. V3_VIEW_APPS_ON_SUBSCRIPTIONS
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS;

CREATE MATERIALIZED VIEW V3_VIEW_APPS_ON_SUBSCRIPTIONS
AS
SELECT
    SUB.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAME as dp_name,
    DP.DESCRIPTION as dp_description,
    DP.HOST_CLOUD_TYPE,
    DP.STATUS as dp_status,
    DP.REGISTERED_REGION,
    DP.RUNNING_REGION,
    DP.TAGS as dp_tags,
    CI.CAPABILITY_INSTANCE_ID,
    CI.CAPABILITY_INSTANCE_NAME,
    CI.CAPABILITY_ID,
    CI.CAPABILITY_INSTANCE_DESCRIPTION,
    (SELECT f->>'value' FROM V3_RESOURCE_INSTANCES NRI, jsonb_array_elements(NRI.RESOURCE_INSTANCE_METADATA->'fields') AS f WHERE NRI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS) AND NRI.RESOURCE_ID = 'NAMESPACE' AND f->>'key' = 'namespaceName' ORDER BY CASE WHEN NRI.RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END LIMIT 1) as capability_instance_namespace,
    CI.STATUS as capability_instance_status,
    CI.TAGS as capability_instance_tags,
    APPS.CAPABILITY_VERSION as capability_instance_version,
    APPS.APP_ID,
    APPS.APP_NAME,
    APPS.APP_DESCRIPTION,
    APPS.APP_VERSION,
    APPS.STATE as app_state,
    APPS.DESIRED_REPLICAS,
    APPS.TAGS as app_tags,
    APPS.APP_LINKS,
    APPS.EULA as app_eula,
    APPS.RESOURCE_INSTANCE_IDS as app_resource_instance_ids,
    APPS.CREATED_TIME,
    APPS.MODIFIED_TIME,
    (SELECT f->>'value' FROM V3_RESOURCE_INSTANCES NRI, jsonb_array_elements(NRI.RESOURCE_INSTANCE_METADATA->'fields') AS f WHERE NRI.RESOURCE_INSTANCE_ID = ANY(APPS.RESOURCE_INSTANCE_IDS) AND NRI.RESOURCE_ID = 'NAMESPACE' AND f->>'key' = 'namespaceName' ORDER BY CASE WHEN NRI.RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END LIMIT 1) as app_namespace,
    (select CONCAT(U.firstname || ' ',lastname) from v2_users U where U.USER_ENTITY_ID = APPS.MODIFIED_BY)
        as modified_by,
    (select CONCAT(U.firstname|| ' ',lastname) from v2_users U where U.USER_ENTITY_ID = APPS.CREATED_BY)
        as created_by
FROM V2_SUBSCRIPTIONS SUB JOIN V3_DATA_PLANES DP ON SUB.SUBSCRIPTION_ID = DP.SUBSCRIPTION_ID
                          JOIN V3_CAPABILITY_INSTANCES CI ON DP.DP_ID = CI.DP_ID
                          JOIN V3_APPS APPS ON CI.CAPABILITY_INSTANCE_ID = APPS.CAPABILITY_INSTANCE_ID
    WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_INDEX ON V3_VIEW_APPS_ON_SUBSCRIPTIONS (SUBSCRIPTION_ID,REGISTERED_REGION,DP_ID,CAPABILITY_INSTANCE_ID,APP_ID);

-- Recreate refresh function and triggers for V3_VIEW_APPS_ON_SUBSCRIPTIONS
CREATE OR REPLACE FUNCTION V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_APPS_ON_SUBSCRIPTIONS;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_APPS_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_APPS_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, APP_ID, APP_NAME, APP_DESCRIPTION, APP_VERSION, CAPABILITY_INSTANCE_ID, CAPABILITY_ID, CAPABILITY_VERSION, STATE, DESIRED_REPLICAS, TAGS, APP_LINKS, EULA, RESOURCE_INSTANCE_IDS, CREATED_TIME, MODIFIED_TIME, CREATED_BY, MODIFIED_BY
              ON V3_APPS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_ID, CAPABILITY_INSTANCE_DESCRIPTION, RESOURCE_INSTANCE_IDS, STATUS, TAGS
              ON V3_CAPABILITY_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME, DESCRIPTION, HOST_CLOUD_TYPE, STATUS, REGISTERED_REGION, RUNNING_REGION, TAGS
              ON V3_DATA_PLANES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_SUB_TRIGGER ON V2_SUBSCRIPTIONS;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_SUB_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_SUBSCRIPTIONS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

-- Refresh when resource instances change (namespace derived from RI)
DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

-- 13c. V3_VIEW_DATA_PLANE_MONITOR_DETAILS
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_MONITOR_DETAILS
AS
SELECT
    VDP.SUBSCRIPTION_ID,
    json_agg(row_to_json((
        SELECT ColumnName
        FROM (SELECT VDP.DP_ID, VDP.NAME, VDP.REGISTERED_REGION, VDP.RUNNING_REGION, VDP.DP_CONFIG, VDP.STATUS, VDP.HOST_CLOUD_TYPE,
             (SELECT ARRAY_AGG(NRI.RESOURCE_INSTANCE_NAME ORDER BY CASE WHEN NRI.RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END) FROM V3_RESOURCE_INSTANCES NRI WHERE NRI.SCOPE_ID = VDP.DP_ID AND NRI.RESOURCE_ID = 'NAMESPACE' AND NRI.SCOPE = 'DATAPLANE'),
             DPCP.CAPABILITIES, VRI.RESOURCE_INSTANCES)
                 AS ColumnName (DP_ID, NAME, REGISTERED_REGION, RUNNING_REGION, DP_CONFIG, DP_STATUS, HOST_CLOUD_TYPE, NAMESPACES, CAPABILITIES, RESOURCE_INSTANCES)
    ))) DATAPLANES
FROM V3_DATA_PLANES VDP LEFT JOIN (SELECT DP_ID, json_agg(row_to_json((
    SELECT ColumnName
    FROM (
             SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CI.CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA,
             (SELECT f->>'value' FROM V3_RESOURCE_INSTANCES NRI, jsonb_array_elements(NRI.RESOURCE_INSTANCE_METADATA->'fields') AS f WHERE NRI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS) AND NRI.RESOURCE_ID = 'NAMESPACE' AND f->>'key' = 'namespaceName' ORDER BY CASE WHEN NRI.RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END LIMIT 1),
             CI.VERSION, STATUS, REGION, TAGS)
             AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, NAME, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, VERSION, STATUS, REGION, TAGS)
))) CAPABILITIES
                                   FROM (V3_CAPABILITY_INSTANCES CI LEFT JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID,CAPABILITY_TYPE))
                                   GROUP BY DP_ID) DPCP ON VDP.DP_ID = DPCP.DP_ID LEFT JOIN  (SELECT SCOPE_ID, json_agg(row_to_json((SELECT ColumnName
                                                                                                                                     FROM (SELECT RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_METADATA)
                                                                                                                                              AS ColumnName (RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_METADATA)
))) AS RESOURCE_INSTANCES FROM V3_RESOURCE_INSTANCES
                                                                                              WHERE  SCOPE = 'DATAPLANE' AND (RESOURCE_ID = 'HAWKDOMAIN' OR RESOURCE_ID = 'BW6TEAAGENT' OR RESOURCE_ID='BETEAAGENT' OR RESOURCE_ID='MSGSERVER')
                                                                                              GROUP BY SCOPE_ID) VRI ON VDP.DP_ID = VRI.SCOPE_ID
GROUP BY VDP.SUBSCRIPTION_ID
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_DATA_PLANE_MONITOR_DETAILS_INDEX ON V3_VIEW_DATA_PLANE_MONITOR_DETAILS (SUBSCRIPTION_ID);

-- Recreate refresh function and triggers for V3_VIEW_DATA_PLANE_MONITOR_DETAILS
CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_DATA_PLANE_MONITOR_DETAILS;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_SH_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_SH_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME, REGISTERED_REGION, RUNNING_REGION, DP_CONFIG, STATUS, HOST_CLOUD_TYPE
ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, RESOURCE_INSTANCE_IDS, VERSION, STATUS, REGION, TAGS
ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER ON V3_CAPABILITY_METADATA;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_METADATA
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- Refresh monitor view when resource instances change (namespace add/remove)
DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- 13d. V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
AS
SELECT
    U.EMAIL,
    U.FIRSTNAME,
    U.LASTNAME,
    A.DISPLAY_NAME,
    A.HOST_PREFIX,
    A.CREATED_TIME,
    A.ACCOUNT_SETTINGS -> 'ownerLimit' as owner_limit,
    A.ACCOUNT_SETTINGS -> 'softLimit' as soft_limit,
    A.ACCOUNT_SETTINGS -> 'externalAccountId' as external_account_id,
    A.comment as ACCOUNT_COMMENT,
    S.SUBSCRIPTION_ID,
    S.EXTERNAL_SUBSCRIPTION_ID,
    S.TSC_ACCOUNT_ID,
    S.SUBSCRIPTION_TYPE,
    S.START_OF_CONTRACT_TIME,
    S.END_OF_CONTRACT_TIME,
    S.STATUS,
    (SELECT count(*) from v3_data_planes where subscription_id = S.subscription_id) as DP_COUNT,
    (SELECT coalesce(v2arq.soft_limit, v2r.soft_limit)) as dp_soft_limit,
    DP.DATA_PLANES
FROM ((
    V2_SUBSCRIPTIONS S
        LEFT JOIN (
        SELECT SUBSCRIPTION_ID, json_agg(row_to_json((
            SELECT ColumnName
            FROM (SELECT DP_ID, NAME, DESCRIPTION, HOST_CLOUD_TYPE, STATUS, REGISTERED_REGION,RUNNING_REGION,CREATED_DATE,MODIFIED_DATE,CREATED_BY,MODIFIED_BY,TAGS,
                (SELECT ARRAY_AGG(f->>'value' ORDER BY CASE WHEN NRI.RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END) FROM V3_RESOURCE_INSTANCES NRI, jsonb_array_elements(NRI.RESOURCE_INSTANCE_METADATA->'fields') AS f WHERE NRI.RESOURCE_ID = 'NAMESPACE' AND NRI.SCOPE = 'DATAPLANE' AND NRI.SCOPE_ID = DP_ID AND f->>'key' = 'namespaceName'),
                RESOURCE_INSTANCE_IDS,DP_CONFIG,EULA)
                     AS ColumnName (DP_ID, NAME, DESCRIPTION, HOST_CLOUD_TYPE, STATUS,REGISTERED_REGION,RUNNING_REGION,CREATED_DATE,MODIFIED_DATE,CREATED_BY,MODIFIED_BY,TAGS,NAMESPACES,RESOURCE_INSTANCE_IDS,DP_CONFIG,EULA)
        ))) DATA_PLANES
        FROM V3_DATA_PLANES
        GROUP BY SUBSCRIPTION_ID) DP USING (SUBSCRIPTION_ID)
    ))
         LEFT JOIN V2_USERS U ON U.USER_ENTITY_ID=S.CREATED_FOR
         LEFT JOIN V2_ACCOUNTS A ON A.TSC_ACCOUNT_ID = S.TSC_ACCOUNT_ID
         LEFT JOIN V2_RESOURCES v2r ON v2r.RESOURCE_NAME = 'DATA_PLANE_COUNT'
         LEFT JOIN V2_ACCOUNTS_RESOURCES_QUOTA v2arq ON v2r.id = v2arq.id AND v2arq.TSC_ACCOUNT_ID = S.TSC_ACCOUNT_ID
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_INDEX ON V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES (SUBSCRIPTION_ID);

-- Recreate refresh function and triggers for V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
CREATE OR REPLACE FUNCTION V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_SUB_TRIGGER ON V2_SUBSCRIPTIONS;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_SUB_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_SUBSCRIPTIONS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_ACCOUNT_TRIGGER ON V2_ACCOUNTS;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_ACCOUNT_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_ACCOUNTS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_USERS_TRIGGER ON V2_USERS;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_USERS_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_USERS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME, DESCRIPTION, HOST_CLOUD_TYPE, STATUS, REGISTERED_REGION, RUNNING_REGION, CREATED_DATE, MODIFIED_DATE, CREATED_BY, MODIFIED_BY, TAGS, RESOURCE_INSTANCE_IDS, DP_CONFIG, EULA
              ON V3_DATA_PLANES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_RESOURCES_TRIGGER ON V2_RESOURCES;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_RESOURCES_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_RESOURCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_ACC_RESOURCESQUOTA_TRIGGER ON V2_ACCOUNTS_RESOURCES_QUOTA;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_ACC_RESOURCESQUOTA_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_ACCOUNTS_RESOURCES_QUOTA
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

-- Refresh when resource instances change (namespaces derived from RI)
DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

-- ============================================================================
-- PHASE 5: Namespace change notification triggers on v3_resource_instances
--          Split into separate INSERT/DELETE triggers with WHEN clause
--          to filter at trigger level (avoids function execution for non-NAMESPACE rows).
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_dp_namespaces_change_on_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  payload text;
  sub_id text;
BEGIN
  -- Resolve subscription_id from v3_data_planes (scope_id = dp_id)
  SELECT subscription_id INTO sub_id FROM v3_data_planes WHERE dp_id = NEW.scope_id LIMIT 1;

  payload := json_build_object(
      'msgId', nextval('utd_notification_msg_id_seq'),
      'event', 'dp_namespaces_changed',
      'operation', TG_OP,
      'modifiedDate', EXTRACT(EPOCH FROM NOW())::BIGINT,
      'modifiedBy', COALESCE(NEW.modified_by, NEW.created_by),
      'data', json_build_object(
        'dpId', NEW.scope_id,
        'subscriptionId', COALESCE(sub_id, ''),
        'region', COALESCE(NEW.region, '')
      )
    )::text;

  PERFORM pg_notify('utd_notification_channel', payload);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION notify_dp_namespaces_change_on_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  payload text;
  sub_id text;
BEGIN
  -- Resolve subscription_id from v3_data_planes (scope_id = dp_id)
  SELECT subscription_id INTO sub_id FROM v3_data_planes WHERE dp_id = OLD.scope_id LIMIT 1;

  payload := json_build_object(
      'msgId', nextval('utd_notification_msg_id_seq'),
      'event', 'dp_namespaces_changed',
      'operation', TG_OP,
      'modifiedDate', EXTRACT(EPOCH FROM NOW())::BIGINT,
      'modifiedBy', COALESCE(OLD.modified_by, OLD.created_by),
      'data', json_build_object(
        'dpId', OLD.scope_id,
        'subscriptionId', COALESCE(sub_id, ''),
        'region', COALESCE(OLD.region, '')
      )
    )::text;

  PERFORM pg_notify('utd_notification_channel', payload);

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS notify_dp_namespaces_change ON v3_resource_instances;
DROP TRIGGER IF EXISTS notify_dp_namespaces_insert ON v3_resource_instances;
DROP TRIGGER IF EXISTS notify_dp_namespaces_delete ON v3_resource_instances;

CREATE TRIGGER notify_dp_namespaces_insert
    AFTER INSERT
    ON v3_resource_instances
    FOR EACH ROW
    WHEN (NEW.resource_id = 'NAMESPACE' AND NEW.scope = 'DATAPLANE')
    EXECUTE FUNCTION notify_dp_namespaces_change_on_insert();

CREATE TRIGGER notify_dp_namespaces_delete
    AFTER DELETE
    ON v3_resource_instances
    FOR EACH ROW
    WHEN (OLD.resource_id = 'NAMESPACE' AND OLD.scope = 'DATAPLANE')
    EXECUTE FUNCTION notify_dp_namespaces_change_on_delete();

-- ============================================================================
-- PHASE 6: V4_VIEW_DATA_PLANE_MONITOR_DETAILS (one row per dataplane)
-- ============================================================================
-- The v4 view returns one row per dataplane (unlike v3 which groups by subscription).
-- Flat columns: subscription_id, dp_id, registered_region, host_cloud_type, dp_status
-- Nested JSON column "dataplanes": name, running_region, dp_config, namespaces,
--   capabilities, resource_instances
-- Namespaces are derived from v3_resource_instances (NAMESPACE resource type).

DROP MATERIALIZED VIEW IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS CASCADE;

CREATE MATERIALIZED VIEW V4_VIEW_DATA_PLANE_MONITOR_DETAILS AS
WITH
dp_namespaces AS (
    SELECT
        SCOPE_ID AS DP_ID,
        ARRAY_AGG(
            RESOURCE_INSTANCE_NAME
            ORDER BY CASE WHEN RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END
        ) AS NAMESPACES
    FROM V3_RESOURCE_INSTANCES
    WHERE SCOPE = 'DATAPLANE' AND RESOURCE_ID = 'NAMESPACE'
    GROUP BY SCOPE_ID
),
ns_ri AS (
    SELECT
        RESOURCE_INSTANCE_ID,
        RESOURCE_INSTANCE_NAME AS NAMESPACE_NAME,
        CASE WHEN RESOURCE_INSTANCE_METADATA->'fields' @> '[{"key":"isPrimary","value":true}]'::jsonb THEN 0 ELSE 1 END AS IS_PRIMARY
    FROM V3_RESOURCE_INSTANCES
    WHERE RESOURCE_ID = 'NAMESPACE' AND SCOPE = 'DATAPLANE'
),
ci_ns AS (
    SELECT DISTINCT ON (CI.CAPABILITY_INSTANCE_ID)
        CI.CAPABILITY_INSTANCE_ID,
        ns.NAMESPACE_NAME
    FROM V3_CAPABILITY_INSTANCES CI
    JOIN ns_ri ns ON ns.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS)
    ORDER BY CI.CAPABILITY_INSTANCE_ID, ns.IS_PRIMARY
),
dp_capabilities AS (
    SELECT
        CI.DP_ID,
        json_agg(row_to_json((SELECT ColumnName FROM (SELECT
            CI.CAPABILITY_INSTANCE_ID, CI.CAPABILITY_INSTANCE_NAME, CI.CAPABILITY_INSTANCE_DESCRIPTION,
            CI.CAPABILITY_ID, CR.DISPLAY_NAME,
            CI.CAPABILITY_TYPE, CI.CAPABILITY_INSTANCE_METADATA,
            cn.NAMESPACE_NAME,
            CI.VERSION, CI.STATUS, CI.REGION, CI.TAGS
        ) AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, NAME, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, VERSION, STATUS, REGION, TAGS)
        ))) AS CAPABILITIES
    FROM V3_CAPABILITY_INSTANCES CI
    LEFT JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID, CAPABILITY_TYPE)
    LEFT JOIN ci_ns cn ON cn.CAPABILITY_INSTANCE_ID = CI.CAPABILITY_INSTANCE_ID
    GROUP BY CI.DP_ID
),
dp_resources AS (
    SELECT
        SCOPE_ID,
        json_agg(row_to_json((SELECT ColumnName FROM (SELECT RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_METADATA)
            AS ColumnName (RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_METADATA)
        ))) AS RESOURCE_INSTANCES
    FROM V3_RESOURCE_INSTANCES
    WHERE SCOPE = 'DATAPLANE'
      AND RESOURCE_ID IN ('HAWKDOMAIN', 'BW6TEAAGENT', 'BETEAAGENT', 'MSGSERVER')
    GROUP BY SCOPE_ID
)
SELECT
    VDP.SUBSCRIPTION_ID,
    VDP.DP_ID,
    VDP.REGISTERED_REGION,
    VDP.HOST_CLOUD_TYPE,
    VDP.STATUS AS DP_STATUS,
    row_to_json((SELECT ColumnName FROM (SELECT
        VDP.NAME, VDP.RUNNING_REGION, VDP.DP_CONFIG,
        COALESCE(dpns.NAMESPACES, ARRAY[]::TEXT[]),
        dpc.CAPABILITIES,
        dpr.RESOURCE_INSTANCES
    ) AS ColumnName (NAME, RUNNING_REGION, DP_CONFIG, NAMESPACES, CAPABILITIES, RESOURCE_INSTANCES)
    )) AS DATAPLANES
FROM V3_DATA_PLANES VDP
LEFT JOIN dp_namespaces dpns ON dpns.DP_ID = VDP.DP_ID
LEFT JOIN dp_capabilities dpc ON dpc.DP_ID = VDP.DP_ID
LEFT JOIN dp_resources dpr ON dpr.SCOPE_ID = VDP.DP_ID
    WITH DATA;

CREATE UNIQUE INDEX V4_VIEW_DATA_PLANE_MONITOR_DETAILS_INDEX ON V4_VIEW_DATA_PLANE_MONITOR_DETAILS (DP_ID);

-- Recreate refresh function and triggers for V4_VIEW_DATA_PLANE_MONITOR_DETAILS
CREATE OR REPLACE FUNCTION V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V4_VIEW_DATA_PLANE_MONITOR_DETAILS;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V4_VIEW_DATA_PLANE_MONITOR_DETAILS_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, REGISTERED_REGION, HOST_CLOUD_TYPE, STATUS, NAME, RUNNING_REGION, DP_CONFIG
ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

DROP TRIGGER IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V4_VIEW_DATA_PLANE_MONITOR_DETAILS_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, RESOURCE_INSTANCE_IDS, VERSION, STATUS, REGION, TAGS
ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

DROP TRIGGER IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V4_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

DROP TRIGGER IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER ON V3_CAPABILITY_METADATA;
CREATE TRIGGER V4_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_METADATA
                  FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- ============================================================================
-- Namespace RI enforcement triggers
-- ============================================================================

-- Clean up dataplane enforcement trigger if present from a prior run
-- (removed because namespace RI has scope_id = dp_id, which doesn't exist at INSERT time)
DROP TRIGGER IF EXISTS v3_validate_dataplane_namespace_ri_trigger ON v3_data_planes;
DROP FUNCTION IF EXISTS v3_validate_dataplane_namespace_ri();

CREATE OR REPLACE FUNCTION v3_validate_capability_namespace_ri()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.resource_instance_ids IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM unnest(NEW.resource_instance_ids) AS rid
        JOIN v3_resource_instances ri ON ri.resource_instance_id = rid
        WHERE ri.resource_id = 'NAMESPACE' AND ri.scope = 'DATAPLANE' AND ri.scope_id = NEW.dp_id
    ) THEN
        RAISE EXCEPTION 'Capability instance resource_instance_ids must include at least one namespace resource instance for dataplane "%"', NEW.dp_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS v3_validate_capability_namespace_ri_trigger ON v3_capability_instances;
CREATE TRIGGER v3_validate_capability_namespace_ri_trigger
    BEFORE INSERT OR UPDATE OF resource_instance_ids ON v3_capability_instances
    FOR EACH ROW EXECUTE FUNCTION v3_validate_capability_namespace_ri();

CREATE OR REPLACE FUNCTION v3_validate_app_namespace_ri()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.resource_instance_ids IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM unnest(NEW.resource_instance_ids) AS rid
        JOIN v3_resource_instances ri ON ri.resource_instance_id = rid
        WHERE ri.resource_id = 'NAMESPACE' AND ri.scope = 'DATAPLANE' AND ri.scope_id = NEW.dp_id
    ) THEN
        RAISE EXCEPTION 'App resource_instance_ids must include at least one namespace resource instance for dataplane "%"', NEW.dp_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS v3_validate_app_namespace_ri_trigger ON v3_apps;
CREATE TRIGGER v3_validate_app_namespace_ri_trigger
    BEFORE INSERT OR UPDATE OF resource_instance_ids ON v3_apps
    FOR EACH ROW EXECUTE FUNCTION v3_validate_app_namespace_ri();

-- ============================================================================
-- Performance indexes on base tables for faster matview refresh
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_resource_instances_namespace_scope
    ON V3_RESOURCE_INSTANCES (RESOURCE_ID, SCOPE, SCOPE_ID);

CREATE INDEX IF NOT EXISTS idx_capability_instances_dp_id
    ON V3_CAPABILITY_INSTANCES (DP_ID);

CREATE INDEX IF NOT EXISTS idx_apps_dp_id
    ON V3_APPS (DP_ID);

CREATE INDEX IF NOT EXISTS idx_apps_capability_instance_id
    ON V3_APPS (CAPABILITY_INSTANCE_ID);

CREATE INDEX IF NOT EXISTS idx_resource_instances_metadata
    ON V3_RESOURCE_INSTANCES USING GIN (RESOURCE_INSTANCE_METADATA);

-- GIN index on RESOURCE_INSTANCE_IDS array for ANY() lookups in CTE-based matviews
CREATE INDEX IF NOT EXISTS idx_capability_instances_resource_instance_ids_gin
    ON V3_CAPABILITY_INSTANCES USING GIN (RESOURCE_INSTANCE_IDS);

-- ============================================================================
-- Restore validation functions with proper bodies
-- ============================================================================

CREATE OR REPLACE FUNCTION V3_VALIDATE_RESOURCE_INSTANCE_ID()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    ID TEXT;
BEGIN
    IF NEW.RESOURCE_INSTANCE_IDS IS NOT NULL THEN
        FOREACH ID IN ARRAY NEW.RESOURCE_INSTANCE_IDS
            LOOP
                IF EXISTS (SELECT 1 FROM V3_RESOURCE_INSTANCES VRI WHERE VRI.RESOURCE_INSTANCE_ID = ID) THEN
                ELSE
                    RAISE EXCEPTION 'INVALID RESOURCE_INSTANCE_ID';
                END IF;
            END LOOP;
    END IF ;
    RETURN NEW;
END;
$FUNCTION$;

CREATE OR REPLACE FUNCTION V3_VALIDATE_APPS_RESOURCE_INSTANCE_ID()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    ID TEXT;
BEGIN
    IF NEW.RESOURCE_INSTANCE_IDS IS NOT NULL THEN
        FOREACH ID IN ARRAY NEW.RESOURCE_INSTANCE_IDS
            LOOP
                IF EXISTS (SELECT 1 FROM V3_RESOURCE_INSTANCES VRI WHERE VRI.RESOURCE_INSTANCE_ID = ID) THEN
                ELSE
                    RAISE EXCEPTION 'INVALID INGRESS_CONTROLLER_RESOURCE_INSTANCE_ID';
                END IF;
            END LOOP;
    END IF ;
    RETURN NEW;
END;
$FUNCTION$;

-- Cleanup: drop migration helper function
DROP FUNCTION IF EXISTS generate_ulid();

-- Data correction: backfill missing SERVICEACCOUNT,INGRESS,GATEWAYAPI RIs for O11Y capability instances on control-tower DPs.
UPDATE v3_capability_instances ci
SET resource_instance_ids = (
    COALESCE(ci.resource_instance_ids, '{}')
        ||
    ARRAY(
        SELECT dp_ri.resource_instance_id::TEXT
          FROM v3_resource_instances dp_ri
          WHERE dp_ri.resource_instance_id = ANY(dp.resource_instance_ids)
            AND dp_ri.resource_id IN ('SERVICEACCOUNT', 'INGRESS', 'GATEWAYAPI')
            AND NOT (COALESCE(ci.resource_instance_ids, '{}') @> ARRAY[dp_ri.resource_instance_id::TEXT])
      )
    )
    FROM v3_data_planes dp
WHERE ci.dp_id = dp.dp_id
  AND ci.capability_id = 'O11Y'
  AND dp.host_cloud_type = 'control-tower'
  AND (
-- missing SERVICEACCOUNT
    NOT EXISTS (
    SELECT 1 FROM v3_resource_instances ri
    WHERE ri.resource_instance_id = ANY(ci.resource_instance_ids)
  AND ri.resource_id = 'SERVICEACCOUNT'
    )
   OR
-- missing both INGRESS and GATEWAYAPI
    NOT EXISTS (
    SELECT 1 FROM v3_resource_instances ri
    WHERE ri.resource_instance_id = ANY(ci.resource_instance_ids)
  AND ri.resource_id IN ('INGRESS', 'GATEWAYAPI')
    )
    )
-- DP has at least one missing resource to contribute
  AND EXISTS (
    SELECT 1 FROM v3_resource_instances dp_ri
    WHERE dp_ri.resource_instance_id = ANY(dp.resource_instance_ids)
  AND dp_ri.resource_id IN ('SERVICEACCOUNT', 'INGRESS', 'GATEWAYAPI')
  AND NOT (COALESCE(ci.resource_instance_ids, '{}') @> ARRAY[dp_ri.resource_instance_id::TEXT])
    );

-- Update database schema at the end (earlier version is 1.17.0 i.e. 20)
UPDATE schema_version SET version = 21;

-- ============================================================================
-- END TRANSACTION
-- ============================================================================
COMMIT;
