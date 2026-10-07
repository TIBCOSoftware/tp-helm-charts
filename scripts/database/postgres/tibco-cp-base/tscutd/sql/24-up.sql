-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Database schema changes for 1.21.0

-- ============================================================================
-- PCP-20702: Async materialized-view refresh queue
--
-- Replace synchronous REFRESH MATERIALIZED VIEW CONCURRENTLY inside trigger
-- functions with a lightweight queue insert. A Go-side consumer (cp-cronjobs)
-- polls the queue, claims PENDING rows, refreshes views in parallel, then
-- deletes processed rows.
-- ============================================================================

-- Queue table: composite PK (VIEW_ID, STATUS) allows at most one PENDING
-- and one PROCESSING row per view. Triggers insert with ON CONFLICT DO
-- NOTHING — if a PENDING row already exists the insert is a no-op; if only
-- a PROCESSING row exists the insert succeeds, ensuring the view is
-- refreshed again after the in-flight refresh completes.
CREATE TABLE IF NOT EXISTS V3_MV_REFRESH_QUEUE (
    VIEW_ID    TEXT        NOT NULL,
    STATUS     TEXT        NOT NULL DEFAULT 'PENDING'
                           CHECK (STATUS IN ('PENDING', 'PROCESSING')),
    CREATED_AT TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UPDATED_AT TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (VIEW_ID, STATUS)
);

CREATE INDEX IF NOT EXISTS idx_mv_refresh_queue_status_created
    ON V3_MV_REFRESH_QUEUE (STATUS, CREATED_AT);

-- Enqueue helper — called by every trigger function below.
CREATE OR REPLACE FUNCTION V3_ENQUEUE_MV_REFRESH(p_view_name TEXT) RETURNS VOID
    LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO V3_MV_REFRESH_QUEUE (VIEW_ID)
    VALUES (p_view_name)
    ON CONFLICT DO NOTHING;
END; $$;

-- Convert trigger functions ------------------------------------------------
-- CREATE OR REPLACE preserves all existing triggers — no trigger DDL needed.

CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_ACCOUNT_ALLOWED_RESOURCE');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_DATA_PLANE_MONITOR_DETAILS');
    RETURN NULL;
END; $$;

-- Original used non-concurrent refresh and RETURN NEW; safe to change —
-- trigger is AFTER / FOR EACH STATEMENT where the return value is ignored.
CREATE OR REPLACE FUNCTION V3_VIEW_RESOURCE_SCOPE_HIERARCHY_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_RESOURCE_SCOPE_HIERARCHY');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_APPS_ON_SUBSCRIPTIONS');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_TAGS_DATA_PLANES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_TAGS_DATA_PLANES');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_TAGS_CAPABILITY_INSTANCES');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V4_VIEW_DATA_PLANE_MONITOR_DETAILS');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE');
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM V3_ENQUEUE_MV_REFRESH('V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES');
    RETURN NULL;
END; $$;

-- PCP-21310: Add BPMGATEWAY as the INFRA dependency auto-provisioned on first BPM discovery
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('BPMGATEWAY', 'BPM Gateway', 'BPM API Gateway', 'INFRA')
    ON CONFLICT DO NOTHING;

-- ACE-10777: Add BPM as a PLATFORM Capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('BPM', 'BPM', 'BPM capability for TIBCO Platform', 'PLATFORM')
ON CONFLICT DO NOTHING;

-- PCP-23237: Add PROVISIONING_MODE to V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE.
-- Extracted from CAPABILITY_INSTANCE_METADATA->>'provisioningMode' so that the
-- UI can distinguish DISCOVERED instances from HELM-managed ones without parsing
-- the full metadata JSONB on the client side.
-- DROP CASCADE removes the unique index and all triggers created by 22-up.sql.

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE AS
WITH
ns_ri AS (
    SELECT
        RI.RESOURCE_INSTANCE_ID,
        RI.RESOURCE_INSTANCE_NAME   AS namespace_name,
        CASE WHEN RI.RESOURCE_INSTANCE_METADATA->'fields'
                  @> '[{"key":"isPrimary","value":true}]'::jsonb
             THEN 0 ELSE 1 END      AS primary_order
    FROM V3_RESOURCE_INSTANCES RI
    WHERE RI.RESOURCE_ID = 'NAMESPACE'
      AND RI.SCOPE       = 'DATAPLANE'
),
ci_ns AS (
    SELECT DISTINCT ON (CI.CAPABILITY_INSTANCE_ID)
        CI.CAPABILITY_INSTANCE_ID,
        NS.namespace_name
    FROM  V3_CAPABILITY_INSTANCES CI,
          unnest(CI.RESOURCE_INSTANCE_IDS) AS ri_id
    JOIN  ns_ri NS ON NS.resource_instance_id = ri_id
    ORDER BY CI.CAPABILITY_INSTANCE_ID, NS.primary_order
)
SELECT
    DP.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAME AS DP_NAME,
    CI.CAPABILITY_ID,
    cn.namespace_name AS NAMESPACE,
    CI.VERSION,
    CI.STATUS,
    CI.MONITORING_STATUS,
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
    CI.CAPABILITY_TYPE,
    CI.CAPABILITY_INSTANCE_METADATA->>'provisioningMode' AS PROVISIONING_MODE
FROM V3_CAPABILITY_INSTANCES CI
    LEFT JOIN ci_ns cn         USING (CAPABILITY_INSTANCE_ID)
    LEFT JOIN V3_DATA_PLANES DP USING (DP_ID)
-- No CAPABILITY_TYPE filter: view returns both PLATFORM and INFRA rows.
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_INDEX ON V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
    (SUBSCRIPTION_ID, DP_ID, CAPABILITY_INSTANCE_ID);

DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER AFTER
    INSERT OR DELETE
OR UPDATE OF DP_ID, CAPABILITY_ID, CAPABILITY_TYPE, VERSION, STATUS,
       MONITORING_STATUS, REGION, CREATED_TIME, MODIFIED_TIME, CREATED_BY,
       MODIFIED_BY, TAGS, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME,
       CAPABILITY_INSTANCE_DESCRIPTION, RESOURCE_INSTANCE_IDS,
       CAPABILITY_INSTANCE_METADATA
   ON V3_CAPABILITY_INSTANCES
       FOR EACH STATEMENT
       EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_DP_TRIGGER
    AFTER INSERT OR DELETE
OR UPDATE OF NAME, SUBSCRIPTION_ID, DP_ID
   ON V3_DATA_PLANES
       FOR EACH STATEMENT
       EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

-- PCP-23237: Add provisioningMode to V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES.
-- provisioningMode is surfaced inside the CAPABILITIES JSON array so the UI
-- can distinguish DISCOVERED instances from HELM-managed ones.
-- DROP CASCADE removes the unique index and all triggers from 22-up.sql.

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES AS
WITH
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
dp_ns AS (
    SELECT dp_id,
           ARRAY_AGG(namespace_name ORDER BY primary_order) AS namespaces
    FROM   ns_ri
    GROUP  BY dp_id
),
ci_ns AS (
    SELECT DISTINCT ON (CI.CAPABILITY_INSTANCE_ID)
        CI.CAPABILITY_INSTANCE_ID,
        NS.namespace_name
    FROM  V3_CAPABILITY_INSTANCES CI,
          unnest(CI.RESOURCE_INSTANCE_IDS) AS ri_id
    JOIN  ns_ri NS ON NS.resource_instance_id = ri_id
    ORDER BY CI.CAPABILITY_INSTANCE_ID, NS.primary_order
),
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
        CI.CAPABILITY_INSTANCE_METADATA->>'provisioningMode' AS provisioning_mode,
        CR.DISPLAY_NAME,
        CR.CAPABILITY_TYPE,
        cn.namespace_name AS namespace
    FROM  V3_CAPABILITY_INSTANCES CI
    LEFT  JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID, CAPABILITY_TYPE)
    LEFT  JOIN ci_ns cn            USING (CAPABILITY_INSTANCE_ID)
),
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
                       cf.MODIFIED_TIME, cf.MONITORING_STATUS,
                       cf.provisioning_mode
            ) AS ColumnName (
                CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION,
                CAPABILITY_ID, CAPABILITY_NAME, CAPABILITY_TYPE, NAMESPACE,
                VERSION, STATUS, REGION, TAGS, MODIFIED_TIME, MONITORING_STATUS,
                PROVISIONING_MODE
            )
        ))) AS CAPABILITIES
    FROM   ci_flat cf
    GROUP  BY cf.DP_ID
),
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
    DP.CREATED_DATE,
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

CREATE UNIQUE INDEX VIEW_DATA_PLANE_CAPABILITY_INSTANCE_INDEX
    ON V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (DP_ID);

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME, DESCRIPTION,
                                  HOST_CLOUD_TYPE, DP_CONFIG, STATUS,
                                  REGISTERED_REGION, RUNNING_REGION,
                                  CREATED_DATE, MODIFIED_DATE, TAGS,
                                  CONTAINER_REGISTRY_CREDENTIAL,
                                  CONNECTION_DETAILS, RESOURCE_INSTANCE_IDS
    ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME,
                                  CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID,
                                  CAPABILITY_TYPE, VERSION, STATUS, REGION, TAGS,
                                  MODIFIED_TIME, MONITORING_STATUS, RESOURCE_INSTANCE_IDS,
                                  CAPABILITY_INSTANCE_METADATA
    ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_APPS_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_APPS_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, APP_ID, APP_NAME, APP_VERSION,
                                  CAPABILITY_INSTANCE_ID, CAPABILITY_ID,
                                  CAPABILITY_VERSION, STATE, TAGS, MODIFIED_TIME
    ON V3_APPS
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

-- MSGDP-2326: Add EMSMCP as a PLATFORM Capability.
-- EMSMCP previously had no metadata row at all - it was installed silently as an INFRA
-- member of the msg-infra-core bundle. For CP 1.21.0 it becomes a DP-provisionable
-- capability so the CP-side Tessa aggregator can map the active DP-EMSMCP instances.
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('EMSMCP', 'TIBCO Enterprise Message Service™ MCP Server', 'A Model Context Protocol (MCP) server for TIBCO Enterprise Message Service™ that lets TESSA inspect EMS running on a Data Plane for real-time, AI-driven insights and analysis.', 'PLATFORM')
ON CONFLICT DO NOTHING;

-- Update DBCONFIG: rename SSL fields, make SSL Certificate/CA Certificate required, add sslRejectUnauthorized default true (all 4 DB types)
-- Update SEARCHCONFIG: add authType + basicAuthKey, remove sslRejectUnauthorized, make SSL Certificate/CA Certificate required, make apiKey + index optional (both engines)
UPDATE V3_RESOURCES
SET RESOURCE_METADATA = '{"fields":[{"key":"dbms","enum":["rdbms"],"name":"Database Management System","rdbms":{"key":"persistenceType","enum":[{"key":"postgres","name":"PostgreSQL"},{"key":"mysql","name":"MySQL"},{"key":"oracle","name":"Oracle"},{"key":"mssql","name":"MSSQL"}],"name":"Database Type","mysql":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","order":7,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"SSL Client Public Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"true"}],"dataType":"string","postgres":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","order":7,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"SSL Client Public Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"true"}],"oracle":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","order":7,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"SSL Client Public Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"true"}],"mssql":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","order":7,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"SSL Client Public Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"true"}],"required":true,"fieldType":"dropdown"},"dataType":"string","required":true,"fieldType":"dropdown"}]}'
WHERE RESOURCE_ID = 'DBCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

UPDATE V3_RESOURCES
SET RESOURCE_METADATA = '{"fields":[{"key":"engine","enum":["Elasticsearch","OpenSearch"],"name":"Search Engine","dataType":"string","required":true,"fieldType":"dropdown","Elasticsearch":[{"key":"endpoint","name":"Endpoint","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":1},{"key":"port","name":"Port","regex":"","dataType":"string","default":"9200","required":true,"fieldType":"text","maxLength":"255","order":2},{"key":"scheme","enum":["http","https"],"default":"https","name":"Scheme","dataType":"string","required":true,"fieldType":"dropdown","order":3},{"key":"authType","enum":["apiKey","basic"],"default":"apiKey","name":"Authentication Type","dataType":"string","required":false,"fieldType":"dropdown","order":4},{"key":"apiKeySecretName","name":"API Key Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":5},{"key":"apiKeySecretKey","name":"API Key Secret Key","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":6},{"key":"basicAuthKey","name":"Basic Auth Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":7},{"key":"sslEnabled","enum":["false","true"],"default":"false","name":"SSL Enabled","dataType":"string","required":false,"fieldType":"dropdown","order":8},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":9},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":10},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":11},{"key":"sslClientCertSecretKey","name":"SSL Client Public Certificate Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":12},{"key":"index","name":"Index","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":13}],"OpenSearch":[{"key":"endpoint","name":"Endpoint","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":1},{"key":"port","name":"Port","regex":"","dataType":"string","default":"9200","required":true,"fieldType":"text","maxLength":"255","order":2},{"key":"scheme","enum":["http","https"],"default":"https","name":"Scheme","dataType":"string","required":true,"fieldType":"dropdown","order":3},{"key":"authType","enum":["apiKey","basic"],"default":"apiKey","name":"Authentication Type","dataType":"string","required":false,"fieldType":"dropdown","order":4},{"key":"apiKeySecretName","name":"API Key Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":5},{"key":"apiKeySecretKey","name":"API Key Secret Key","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":6},{"key":"basicAuthKey","name":"Basic Auth Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":7},{"key":"sslEnabled","enum":["false","true"],"default":"false","name":"SSL Enabled","dataType":"string","required":false,"fieldType":"dropdown","order":8},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":9},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":10},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":11},{"key":"sslClientCertSecretKey","name":"SSL Client Public Certificate Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":12},{"key":"index","name":"Index","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":13}]}]}'
WHERE RESOURCE_ID = 'SEARCHCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

-- Database schema changes for CP Database Maintenance Mode
-- System-level table to store CP maintenance mode state (no tenant concept, single row)
CREATE TABLE IF NOT EXISTS cp_maintenance_status (
    id                    VARCHAR(36)  NOT NULL DEFAULT 'platform',
    status                VARCHAR(50)  NOT NULL DEFAULT 'ACTIVE',
    status_display_name   VARCHAR(255),
    modified_by           VARCHAR(255),
    modified_time         BIGINT,
    maintenance_message   VARCHAR(500),
    notice                VARCHAR(500),
    CONSTRAINT cp_maintenance_status_pkey PRIMARY KEY (id)
    );

-- Seed the single system-wide row; do nothing if already present
INSERT INTO cp_maintenance_status (id, status, status_display_name, modified_by, modified_time, maintenance_message)
VALUES ('platform', 'ACTIVE', 'Active', 'system', EXTRACT(EPOCH FROM NOW())::BIGINT, 'TIBCO Control Plane is currently in Read-Only maintenance mode.')
    ON CONFLICT (id) DO NOTHING;

-- Append-only audit log; one row per activation/deactivation event.
-- seq is a surrogate PK so rapid back-to-back writes (same epoch second) never collide.
CREATE TABLE IF NOT EXISTS archive_cp_maintenance_status (
    seq                   BIGSERIAL    NOT NULL,
    id                    VARCHAR(36)  NOT NULL,
    modified_time         BIGINT       NOT NULL,
    status                VARCHAR(50)  NOT NULL,
    status_display_name   VARCHAR(255),
    modified_by           VARCHAR(255),
    maintenance_message   VARCHAR(500),
    notice                VARCHAR(500),
    CONSTRAINT archive_cp_maintenance_status_pkey PRIMARY KEY (seq),
    CONSTRAINT archive_cp_maintenance_status_fkey FOREIGN KEY (id) REFERENCES cp_maintenance_status (id)
    );

-- PCP-22606 / PCP-22665: app_id (format bwce-<namespace>-<appname>) is NOT unique across data
-- planes, and one capability_id can have multiple instances on the same data plane. Make the
-- identity of an app the composite key (app_id, dp_id, capability_instance_id) so that the same
-- app_id can coexist for different data planes / capability instances instead of overwriting.

-- V3_ALERT_RULES_TO_APPS is unused — no functional readers/writers in any service (confirmed under
-- PCP-22665) — and its single-column FK to V3_APPS(app_id) is the only thing blocking the composite
-- primary key. Drop the table entirely; CASCADE also removes ALERT_RULES_TO_APPS_FK1.
DROP TABLE IF EXISTS V3_ALERT_RULES_TO_APPS CASCADE;

-- Change the V3_APPS primary key from (app_id) to the composite key.
ALTER TABLE V3_APPS DROP CONSTRAINT IF EXISTS V3_APPS_PKEY;
ALTER TABLE V3_APPS ADD CONSTRAINT V3_APPS_PKEY PRIMARY KEY (APP_ID, DP_ID, CAPABILITY_INSTANCE_ID);

-- Apply the same composite key to V3_ARCHIVED_APPS (also keyed by app_id alone today), so that
-- archiving an app with a colliding app_id does not fail on the single-column primary key.
ALTER TABLE V3_ARCHIVED_APPS DROP CONSTRAINT IF EXISTS V3_ARCHIVED_APPS_PKEY;
ALTER TABLE V3_ARCHIVED_APPS ADD CONSTRAINT V3_ARCHIVED_APPS_PKEY
    PRIMARY KEY (APP_ID, DP_ID, CAPABILITY_INSTANCE_ID);

-- NOTE: TSCUTDB_AUDIT.GET_OBJECT_ID still returns app_id for v3_apps. OBJ_ID is VARCHAR(50); a
-- composite value would overflow it and change the audit-trail format consumed downstream, so the
-- audit key is intentionally left as app_id and tracked separately for an audit redesign.


-- PCP-24907: Clean up duplicate O11Y (O11YV3) resource instances left by the edit bug.
--
-- ============================================================================
-- BEGIN TRANSACTION: Everything from here to COMMIT is atomic.
-- On failure -> automatic ROLLBACK -> no partial state.
-- ============================================================================
BEGIN;
ALTER TABLE v3_resource_instances DISABLE TRIGGER v3_validate_resource_instance_delete_trigger;

-- Part 1: array-internal dedup — keep newest O11YV3 per capability instance, strip the rest
WITH ranked AS (
    SELECT ci.capability_instance_id, ci.dp_id AS dataplane_id, t.linked_ri_id AS ri_id,
           row_number() OVER (PARTITION BY ci.capability_instance_id
              ORDER BY NULLIF(ri.created_time,'')::bigint DESC NULLS LAST,
                       ri.resource_instance_id DESC) AS rn
    FROM v3_capability_instances ci
             CROSS JOIN LATERAL unnest(ci.resource_instance_ids) AS t(linked_ri_id)
    JOIN v3_resource_instances ri ON ri.resource_instance_id = t.linked_ri_id
    AND ri.resource_id = 'O11YV3'
WHERE ci.capability_id = 'O11Y'
    ),
    stale AS (
SELECT capability_instance_id, dataplane_id, ri_id AS stale_ri_id FROM ranked WHERE rn > 1
    ),
    update_cap AS (
UPDATE v3_capability_instances ci
SET resource_instance_ids = ARRAY(
    SELECT elem FROM unnest(ci.resource_instance_ids) AS elem
    WHERE NOT EXISTS (SELECT 1 FROM stale s
    WHERE s.stale_ri_id = elem
    AND s.capability_instance_id = ci.capability_instance_id))
WHERE ci.capability_instance_id IN (SELECT DISTINCT capability_instance_id FROM stale)
    RETURNING ci.dp_id
    ),
    update_dp AS (
UPDATE v3_data_planes dp
SET resource_instance_ids = ARRAY(
    SELECT elem FROM unnest(dp.resource_instance_ids) AS elem
    WHERE NOT EXISTS (SELECT 1 FROM stale s
    WHERE s.stale_ri_id = elem AND s.dataplane_id = dp.dp_id))
WHERE dp.dp_id IN (SELECT DISTINCT dataplane_id FROM stale)
    RETURNING dp.dp_id
    )
DELETE FROM v3_resource_instances
WHERE resource_instance_id IN (SELECT stale_ri_id FROM stale);

-- Part 2: scope-orphan sweep — delete DP-scoped O11YV3 rows in NO array (DP, capability, or app),
--          BUT keep the latest O11YV3 per DP even if it is unlinked
--          (only delete when a newer sibling exists for the same scope_id).
DELETE FROM v3_resource_instances ri
WHERE ri.resource_id = 'O11YV3'
  AND ri.scope       = 'DATAPLANE'
  AND NOT EXISTS (SELECT 1 FROM v3_data_planes dp
                  WHERE dp.dp_id = ri.scope_id
                    AND dp.resource_instance_ids @> ARRAY[ri.resource_instance_id::text])
  AND NOT EXISTS (SELECT 1 FROM v3_capability_instances ci
                  WHERE ci.resource_instance_ids @> ARRAY[ri.resource_instance_id::text])
  AND NOT EXISTS (SELECT 1 FROM v3_apps a
                  WHERE a.resource_instance_ids @> ARRAY[ri.resource_instance_id::text])
  AND EXISTS (SELECT 1 FROM v3_resource_instances ri2                 -- keep-latest guard
              WHERE ri2.resource_id = 'O11YV3'
                AND ri2.scope       = 'DATAPLANE'
                AND ri2.scope_id    = ri.scope_id
                AND ri2.resource_instance_id <> ri.resource_instance_id
                AND ( NULLIF(ri2.created_time,'')::bigint >  NULLIF(ri.created_time,'')::bigint
                     OR (NULLIF(ri2.created_time,'')::bigint =  NULLIF(ri.created_time,'')::bigint
                         AND ri2.resource_instance_id > ri.resource_instance_id) ));

ALTER TABLE v3_resource_instances ENABLE TRIGGER v3_validate_resource_instance_delete_trigger;
COMMIT;

-- Update database schema at the end (earlier version is 1.20.0 i.e. 23)
UPDATE schema_version SET version = 24;
