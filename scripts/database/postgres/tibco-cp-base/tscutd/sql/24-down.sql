-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback database schema changes for 1.21.0 (reverse of 24-up.sql)

-- ============================================================================
-- PCP-20702: Restore synchronous materialized-view refresh (reverse of the
-- async queue added in 24-up.sql).
-- ============================================================================

CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_ACCOUNT_ALLOWED_RESOURCE;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_DATA_PLANE_MONITOR_DETAILS;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_RESOURCE_SCOPE_HIERARCHY_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW V3_VIEW_RESOURCE_SCOPE_HIERARCHY;
    RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_APPS_ON_SUBSCRIPTIONS;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_TAGS_DATA_PLANES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_TAGS_DATA_PLANES;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_TAGS_CAPABILITY_INSTANCES;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V4_VIEW_DATA_PLANE_MONITOR_DETAILS;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE;
    RETURN NULL;
END; $$;

CREATE OR REPLACE FUNCTION V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES;
    RETURN NULL;
END; $$;

DROP FUNCTION IF EXISTS V3_ENQUEUE_MV_REFRESH(TEXT);
DROP TABLE IF EXISTS V3_MV_REFRESH_QUEUE;

-- ACE-10777: Remove BPM as a PLATFORM Capability
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'BPM' AND CAPABILITY_TYPE = 'PLATFORM';

-- PCP-21310: Remove BPMGATEWAY INFRA capability
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'BPMGATEWAY' AND CAPABILITY_TYPE = 'INFRA';

-- MSGDP-2326: Remove EMSMCP as a PLATFORM Capability. Pre-24 EMSMCP had no metadata
-- row (it shipped inside the msg-infra-core INFRA bundle), so this deletes rather than
-- reverting to an INFRA row. Fails if capability instances still reference it, which is
-- the correct safety behavior - delete the instances first, then re-run.
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'EMSMCP' AND CAPABILITY_TYPE = 'PLATFORM';

-- Revert DBCONFIG and SEARCHCONFIG to 23-up.sql baseline (old SSL field names, required:false for SSL cert fields, sslRejectUnauthorized default false; SEARCHCONFIG reverts to 12-field structure without authType/basicAuthKey)
UPDATE V3_RESOURCES
SET RESOURCE_METADATA = '{"fields":[{"key":"dbms","enum":["rdbms"],"name":"Database Management System","rdbms":{"key":"persistenceType","enum":[{"key":"postgres","name":"PostgreSQL"},{"key":"mysql","name":"MySQL"},{"key":"oracle","name":"Oracle"},{"key":"mssql","name":"MSSQL"}],"name":"Database Type","mysql":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Cert Secret Name","order":7,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"Client Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"}],"dataType":"string","postgres":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Cert Secret Name","order":7,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"Client Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"}],"oracle":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Cert Secret Name","order":7,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"Client Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"}],"mssql":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"sslEnabled","name":"Enable SSL","order":6,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"},{"key":"sslCertSecretName","name":"SSL Cert Secret Name","order":7,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslCACertSecretKey","name":"CA Certificate Secret Key","order":8,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientPrivateKeySecretKey","name":"Client Private Key Secret Key","order":9,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslClientCertSecretKey","name":"Client Certificate Secret Key","order":10,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"sslRejectUnauthorized","name":"Reject Unauthorized","order":11,"dataType":"string","required":false,"fieldType":"dropdown","enum":["false","true"],"default":"false"}],"required":true,"fieldType":"dropdown"},"dataType":"string","required":true,"fieldType":"dropdown"}]}'
WHERE RESOURCE_ID = 'DBCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

UPDATE V3_RESOURCES
SET RESOURCE_METADATA = '{"fields":[{"key":"engine","enum":["Elasticsearch","OpenSearch"],"name":"Search Engine","dataType":"string","required":true,"fieldType":"dropdown","Elasticsearch":[{"key":"endpoint","name":"Endpoint","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":1},{"key":"port","name":"Port","regex":"","dataType":"string","default":"9200","required":true,"fieldType":"text","maxLength":"255","order":2},{"key":"scheme","enum":["http","https"],"default":"https","name":"Scheme","dataType":"string","required":true,"fieldType":"dropdown","order":3},{"key":"apiKeySecretName","name":"API Key Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":4},{"key":"apiKeySecretKey","name":"API Key Secret Key","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":5},{"key":"sslEnabled","enum":["false","true"],"default":"false","name":"SSL Enabled","dataType":"string","required":false,"fieldType":"dropdown","order":6},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":7},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":8},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":9},{"key":"sslClientCertSecretKey","name":"SSL Client Certificate Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":10},{"key":"sslRejectUnauthorized","enum":["false","true"],"default":"false","name":"SSL Reject Unauthorized","dataType":"string","required":false,"fieldType":"dropdown","order":11},{"key":"index","name":"Index","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":12}],"OpenSearch":[{"key":"endpoint","name":"Endpoint","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":1},{"key":"port","name":"Port","regex":"","dataType":"string","default":"9200","required":true,"fieldType":"text","maxLength":"255","order":2},{"key":"scheme","enum":["http","https"],"default":"https","name":"Scheme","dataType":"string","required":true,"fieldType":"dropdown","order":3},{"key":"apiKeySecretName","name":"API Key Secret Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":4},{"key":"apiKeySecretKey","name":"API Key Secret Key","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":5},{"key":"sslEnabled","enum":["false","true"],"default":"false","name":"SSL Enabled","dataType":"string","required":false,"fieldType":"dropdown","order":6},{"key":"sslCertSecretName","name":"SSL Certificate Secret Name","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":7},{"key":"sslCACertSecretKey","name":"SSL CA Certificate Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":8},{"key":"sslClientPrivateKeySecretKey","name":"SSL Client Private Key Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":9},{"key":"sslClientCertSecretKey","name":"SSL Client Certificate Secret Key","regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255","order":10},{"key":"sslRejectUnauthorized","enum":["false","true"],"default":"false","name":"SSL Reject Unauthorized","dataType":"string","required":false,"fieldType":"dropdown","order":11},{"key":"index","name":"Index","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":12}]}]}'
WHERE RESOURCE_ID = 'SEARCHCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

-- Restores V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE to its 22-up.sql definition
-- (without the PROVISIONING_MODE column).

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
    CI.CAPABILITY_TYPE
FROM V3_CAPABILITY_INSTANCES CI
         LEFT JOIN ci_ns cn         USING (CAPABILITY_INSTANCE_ID)
         LEFT JOIN V3_DATA_PLANES DP USING (DP_ID)
    WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_INDEX ON V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
    (SUBSCRIPTION_ID, DP_ID, CAPABILITY_INSTANCE_ID);

DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER AFTER
    INSERT OR DELETE
OR UPDATE OF DP_ID, CAPABILITY_ID, CAPABILITY_TYPE, VERSION, STATUS,
       MONITORING_STATUS, REGION, CREATED_TIME, MODIFIED_TIME, CREATED_BY,
       MODIFIED_BY, TAGS, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME,
       CAPABILITY_INSTANCE_DESCRIPTION, RESOURCE_INSTANCE_IDS
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

-- Restore V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES to its 22-up.sql definition
-- (without provisioningMode in the CAPABILITIES JSON array).

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
                                  MODIFIED_TIME, MONITORING_STATUS, RESOURCE_INSTANCE_IDS
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

DROP TABLE IF EXISTS archive_cp_maintenance_status;
DROP TABLE IF EXISTS cp_maintenance_status;

-- PCP-22606 / PCP-22665: revert the composite keys and recreate the dropped v3_alert_rules_to_apps.
-- NOTE: this rollback only succeeds while no colliding rows exist yet (same app_id on multiple
-- data planes / capability instances) -- such rows are exactly what the up-migration enables.
ALTER TABLE V3_ARCHIVED_APPS DROP CONSTRAINT IF EXISTS V3_ARCHIVED_APPS_PKEY;
ALTER TABLE V3_ARCHIVED_APPS ADD CONSTRAINT V3_ARCHIVED_APPS_PKEY PRIMARY KEY (APP_ID);

ALTER TABLE V3_APPS DROP CONSTRAINT IF EXISTS V3_APPS_PKEY;
ALTER TABLE V3_APPS ADD CONSTRAINT V3_APPS_PKEY PRIMARY KEY (APP_ID);

-- Recreate v3_alert_rules_to_apps as originally defined (10-up.sql).
CREATE TABLE IF NOT EXISTS V3_ALERT_RULES_TO_APPS (
    rule_id VARCHAR(255) NOT NULL,
    app_id VARCHAR(255) NOT NULL,
    PRIMARY KEY (rule_id, app_id),
    CONSTRAINT ALERT_RULES_TO_APPS_FK0 FOREIGN KEY (rule_id) REFERENCES v3_resource_instances(resource_instance_id),
    CONSTRAINT ALERT_RULES_TO_APPS_FK1 FOREIGN KEY (app_id) REFERENCES v3_apps(app_id)
    );

-- Update database schema at the end (rolling back to 1.20.0 i.e. 23)
UPDATE schema_version SET version = 23;
