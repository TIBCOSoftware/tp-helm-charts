-- Database schema changes for 1.5.0

-- PCP-7282: Add MSGSERVER resource
INSERT INTO v3_resources (resource_id, "name", description, "type", resource_metadata, resource_level, host_cloud_type)
VALUES('MSGSERVER', 'Messaging', 'Messaging Server Group', 'Control Tower', '{}'::jsonb, 'PLATFORM', '{control-tower}')
    ON CONFLICT DO NOTHING;

--
-- Restructure V3_VIEW_DATA_PLANE_MONITOR_DETAILS to have MSGSERVER resources.
--

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS CASCADE;

CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_MONITOR_DETAILS
AS
SELECT
    VDP.SUBSCRIPTION_ID,
    json_agg(row_to_json((
        SELECT ColumnName
        FROM (SELECT VDP.DP_ID, VDP.NAME, VDP.REGISTERED_REGION, VDP.RUNNING_REGION, VDP.DP_CONFIG, VDP.STATUS, VDP.HOST_CLOUD_TYPE, VDP.NAMESPACES, DPCP.CAPABILITIES, VRI.RESOURCE_INSTANCES)
                 AS ColumnName (DP_ID, NAME, REGISTERED_REGION, RUNNING_REGION, DP_CONFIG, DP_STATUS, HOST_CLOUD_TYPE, NAMESPACES, CAPABILITIES, RESOURCE_INSTANCES)
    ))) DATAPLANES
FROM V3_DATA_PLANES VDP LEFT JOIN (SELECT DP_ID, json_agg(row_to_json((
    SELECT ColumnName
    FROM (
             SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CI.CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, CI.VERSION, STATUS, REGION, TAGS)
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

--
-- PCP-7313 Add new column CONTAINER_REGISTRY_CREDENTIAL to V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES
--

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES
AS
SELECT
    DP.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAMESPACES,
    DP.NAME,
    DP.DESCRIPTION,
    DP.HOST_CLOUD_TYPE,
    DP.DP_CONFIG,
    DP.STATUS,
    DP.REGISTERED_REGION,
    DP.RUNNING_REGION,
    DP.MODIFIED_DATE,
    DP.TAGS,
    DP.CONTAINER_REGISTRY_CREDENTIAL,
    CI.CAPABILITIES,
    AA.APPS,
    RI.RESOURCE_INSTANCE_METADATA
FROM ((
    V3_DATA_PLANES DP
        LEFT JOIN (
        SELECT DP_ID, json_agg(row_to_json((
            SELECT ColumnName
            FROM (SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CR.CAPABILITY_TYPE, NAMESPACE, CI.VERSION, STATUS, REGION, TAGS, CI.MODIFIED_TIME)
                     AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, CAPABILITY_NAME, CAPABILITY_TYPE, NAMESPACE, VERSION, STATUS, REGION, TAGS, MODIFIED_TIME)
        ))) CAPABILITIES
        FROM (V3_CAPABILITY_INSTANCES CI LEFT JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID, CAPABILITY_TYPE))
        GROUP BY DP_ID) CI USING (DP_ID)
        LEFT JOIN (
        SELECT DP_ID, json_agg(row_to_json((
            SELECT ColumnName
            FROM (SELECT APP_ID, APP_NAME, APP_VERSION, CAPABILITY_INSTANCE_ID, CAPABILITY_ID, CAPABILITY_VERSION, STATE, TAGS, A.MODIFIED_TIME)
                     AS ColumnName (APP_ID, APP_NAME, APP_VERSION, CAPABILITY_INSTANCE_ID, CAPABILITY_ID, CAPABILITY_VERSION, STATE, TAGS, MODIFIED_TIME)
        ))) APPS
        FROM V3_APPS A
        GROUP BY DP_ID) AA USING (DP_ID)
    ))
         LEFT JOIN V3_RESOURCE_INSTANCES RI ON RI.SCOPE='DATAPLANE' AND RI.SCOPE_ID=DP.DP_ID AND RI.RESOURCE_ID='SERVICEACCOUNT' AND RESOURCE_LEVEL='INFRA'
    WITH DATA;

CREATE UNIQUE INDEX VIEW_DATA_PLANE_CAPABILITY_INSTANCE_INDEX ON V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (DP_ID);

REFRESH MATERIALIZED VIEW V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES;

-- PCP-5363: Augment v3_apps table schema to include app_links column (JSONB)
ALTER TABLE V3_APPS ADD COLUMN IF NOT EXISTS app_links JSONB;

-- Adding a new Resource TRACES_EXP_LS to v3_resources table
INSERT INTO v3_resources(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_EXP_LS','Observability TracesServer Exporter Resources','Observability TracesServer Exporter Resources','tracesExporter','{"fields":[{"configVersion":"1.5.0","dataType":"map","key":"TracesServer Exporter Resource","name":"TracesServer Exporter Resource","required":false,"value":{"localStore":{"allowMultipleInstances":false,"fields":[{"dataType":"string","key":"config.exporter.kind","name":"TracesServer kind","required":true,"value":"localStore"},{"dataType":"boolean","key":"config.exporter.enabled","name":"TracesServer enabled","required":true,"value":true},{"dataType":"boolean","key":"config.exporter.readonly","name":"TracesServer Exporter Read Only","required":false,"value":false}],"label":"LocalStore","name":"tracesExporterLocalStore","type":"tracesServer"}}}]}','{"k8s"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- -- Adding a new Resource TRACES_PRX_LS to v3_resources table
INSERT INTO v3_resources(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_PRX_LS','Observability TracesServer Proxy Resources','Observability TracesServer Proxy Resources','tracesProxy','{"fields":[{"configVersion":"1.5.0","dataType":"map","key":"TracesServer Proxy Resource","name":"TracesServer Proxy Resource","required":false,"value":{"localStore":{"allowMultipleInstances":false,"fields":[{"dataType":"boolean","key":"config.proxy.enabled","name":"TracesServer LocalStore Proxy Enabled","required":true,"value":true},{"dataType":"string","key":"config.proxy.kind","name":"TracesServer LocalStore Proxy kind","required":true,"value":"localStore"},{"dataType":"boolean","key":"config.proxy.readonly","name":"TracesServer LocalStore Proxy Read Only","required":false,"value":false}],"label":"LocalStore","name":"tracesProxyLocalStore","type":"tracesServer"}}}]}','{"k8s"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Updating METRICS_EXP_PROM to include readonly flag
UPDATE v3_resources SET resource_metadata = '{"fields":[{"key":"MetricsServer Exporter Prometheus","name":"MetricsServer Exporter Prometheus","value":{"prometheus":{"name":"metricsExporterPrometheus","type":"metricsServer","label":"Prometheus","fields":[{"key":"config.exporter.enabled","name":"MetricsServer Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer Prometheus Exporter kind","value":"prometheus","dataType":"string","required":true},{"key":"config.exporter.readonly","name":"MetricsServer Exporter Read Only","value":false,"dataType":"boolean","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.5.0"}]}' WHERE resource_id = 'METRICS_EXP_PROM' AND resource_level = 'PLATFORM';

-- Updating METRICS_PRX_PROM to include readonly flag
UPDATE v3_resources SET resource_metadata = '{"fields":[{"key":"MetricsServer Proxy Prometheus","name":"MetricsServer Proxy Prometheus","value":{"prometheus":{"name":"metricsProxyPrometheus","type":"metricsServer","label":"Prometheus","fields":[{"key":"config.proxy.kind","name":"MetricsServer Proxy kind","value":"prometheus","dataType":"string","required":true},{"key":"config.proxy.enabled","name":"MetricsServer Proxy Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.prometheus.endpoint","name":"MetricsServer Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.prometheus.username","name":"MetricsServer Proxy Username","dataType":"string","required":false},{"key":"secret.proxy.prometheus.password","name":"MetricsServer Proxy Password","dataType":"string","required":false},{"key":"secret.proxy.prometheus.headers","name":"MetricsServer Proxy Headers","dataType":"map","required":false},{"key":"config.proxy.readonly","name":"MetricsServer Proxy Read Only","value":false,"dataType":"boolean","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.5.0"}]}' WHERE resource_id = 'METRICS_PRX_PROM' AND resource_level = 'PLATFORM';

-- PCP-7805: Increase column length and add validation on host_prefix field
-- Need to drop and recreate V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES since it uses HOST_PREFIX
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES CASCADE;

ALTER TABLE V2_ACCOUNTS ALTER COLUMN HOST_PREFIX TYPE VARCHAR(63);
ALTER TABLE V2_ACCOUNTS DROP CONSTRAINT IF EXISTS host_prefix_valid_check;
ALTER TABLE V2_ACCOUNTS ADD CONSTRAINT host_prefix_valid_check CHECK (host_prefix ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$') NOT VALID;

-- Now recreate V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
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
    A.comment as ACCOUNT_COMMENT,
    S.SUBSCRIPTION_ID,
    S.EXTERNAL_SUBSCRIPTION_ID,
    S.TSC_ACCOUNT_ID,
    S.SUBSCRIPTION_TYPE,
    S.STATUS,
    (SELECT count(*) from v3_data_planes where subscription_id = S.subscription_id) as DP_COUNT,
    (SELECT coalesce(v2arq.soft_limit, v2r.soft_limit)) as dp_soft_limit,
    DP.DATA_PLANES
FROM ((
    V2_SUBSCRIPTIONS S
        LEFT JOIN (
        SELECT SUBSCRIPTION_ID, json_agg(row_to_json((
            SELECT ColumnName
            FROM (SELECT DP_ID, NAME, DESCRIPTION, HOST_CLOUD_TYPE, STATUS, REGISTERED_REGION,RUNNING_REGION,CREATED_DATE,MODIFIED_DATE,CREATED_BY,MODIFIED_BY,TAGS,NAMESPACES,RESOURCE_INSTANCE_IDS,DP_CONFIG,EULA)
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

-- Update database schema at the end (earlier version is 1.4.0 i.e. 6)
UPDATE schema_version SET version = 7;
