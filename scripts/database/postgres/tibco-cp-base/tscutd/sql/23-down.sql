-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Rollback database schema changes for 1.20.0 (reverse of 23-up.sql)

-- PCP-21580: MFTADAPTER as an INFRA Capability for Control Tower data planes
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'MFTADAPTER' AND CAPABILITY_TYPE = 'INFRA';

-- PCP-21666: Remove MFTSERVER resource type
DELETE FROM v3_resources WHERE resource_id = 'MFTSERVER';

-- PCP-21666: Recreate V3_VIEW_DATA_PLANE_MONITOR_DETAILS without MFTSERVER (restore version-22 state).
-- DROP CASCADE removes the index and all triggers; all are recreated below.
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

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER AFTER
    INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME, RESOURCE_INSTANCE_METADATA,
                 RESOURCE_ID, SCOPE, SCOPE_ID
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- PCP-21666: Recreate V4_VIEW_DATA_PLANE_MONITOR_DETAILS without MFTSERVER (restore version-22 state).
-- DROP CASCADE removes the index and all triggers; all are recreated below.
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
    INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME, RESOURCE_INSTANCE_METADATA,
                 RESOURCE_ID, SCOPE, SCOPE_ID
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

DROP TRIGGER IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER ON V3_CAPABILITY_METADATA;
CREATE TRIGGER V4_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_METADATA
                  FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- PCP-20474 : REDISCONFIG resource template
DELETE FROM V3_RESOURCES WHERE RESOURCE_ID = 'REDISCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

-- Remove SEARCHCONFIG resource
DELETE FROM V3_RESOURCES WHERE RESOURCE_ID = 'SEARCHCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

-- Revert DBCONFIG: remove Oracle, MSSQL and SSL secret-reference fields, restore postgres and mysql only
UPDATE V3_RESOURCES
SET RESOURCE_METADATA = '{"fields":[{"key":"dbms","enum":["rdbms"],"name":"Database Management System","rdbms":{"key":"persistenceType","enum":[{"key":"postgres","name":"PostgreSQL"},{"key":"mysql","name":"MySQL"}],"name":"Database Type","mysql":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"}],"dataType":"string","postgres":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"}],"required":true,"fieldType":"dropdown"},"dataType":"string","required":true,"fieldType":"dropdown"}]}'
WHERE RESOURCE_ID = 'DBCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';

-- PCP-21499: Rollback OTLP exporter headers to the O11Y OTLP exporter resources.
-- Rollback LOGS_EXP_UA_OTLP metadata
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"LogsServer Exporter UserApps OTLP","name":"LogsServer Exporter UserApps OTLP","value":{"otlp":{"name":"logsExporterUserAppsOtlpgrpc","type":"logsServer","label":"OTLP","fields":[{"key":"config.exporter.userApps.enabled","name":"LogsServer OTLP Exporter UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.userApps.kind","name":"LogsServer OTLP Exporter UserApps kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.userApps.otlp.endpoint","name":"LogsServer OTLP Exporter UserApps Endpoint","dataType":"string","required":true},{"key":"config.exporter.userApps.otlp.type","name":"LogsServer OTLP Exporter UserApps Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'LOGS_EXP_UA_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Rollback LOGS_EXP_SRV_OTLP metadata
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"LogsServer Exporter Services OTLP","name":"LogsServer Exporter Services OTLP","value":{"otlp":{"name":"logsExporterServicesOtlp","type":"logsServer","label":"OTLP","fields":[{"key":"config.exporter.services.enabled","name":"LogsServer OTLP Exporter Services Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.services.kind","name":"LogsServer OTLP Exporter Services kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.services.otlp.endpoint","name":"LogsServer OTLP Exporter Services Endpoint","dataType":"string","required":true},{"key":"config.exporter.services.otlp.type","name":"LogsServer OTLP Exporter Services Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'LOGS_EXP_SRV_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Rollback METRICS_EXP_OTLP metadata
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"MetricsServer Exporter OTLP","name":"MetricsServer Exporter OTLP","value":{"otlp":{"name":"metricsExporterOTLPGRPC","type":"metricsServer","label":"OTLP","fields":[{"key":"config.exporter.enabled","name":"MetricsServer OTLP Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer OTLP Exporter kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.otlp.endpoint","name":"MetricsServer OTLP Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.otlp.type","name":"MetricsServer OTLP Exporter Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'METRICS_EXP_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Rollback TRACES_EXP_OTLP metadata
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"TracesServer Exporter OTLP","name":"TracesServer Exporter OTLP","value":{"otlp":{"name":"tracesExporterOTLPGRPC","type":"tracesServer","label":"OTLP","fields":[{"key":"config.exporter.enabled","name":"TracesServer OTLP Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"TracesServer OTLP Exporter kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.otlp.endpoint","name":"TracesServer OTLP Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.otlp.type","name":"TracesServer OTLP Exporter Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'TRACES_EXP_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- ============================================================================
-- PHASE 5: Restore schema version back to 22 (1.19.0)
-- ============================================================================
UPDATE schema_version SET version = 22;
