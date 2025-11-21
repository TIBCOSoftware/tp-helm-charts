-- Database schema changes for 1.1.0

-- Update database schema at the end (earlier version is 1.0.1 i.e. 2)
UPDATE schema_version SET version = 3;

-- update primary key and foreign key from (CAPABILITY_ID, VERSION, CAPABILITY_TYPE) to (CAPABILITY_ID, CAPABILITY_TYPE)
ALTER TABLE V3_CAPABILITY_INSTANCES DROP CONSTRAINT IF EXISTS V3_CAPABILITY_INSTANCES_FK0 ;
ALTER TABLE V3_CAPABILITY_METADATA DROP CONSTRAINT IF EXISTS V3_CAPABILITY_METADATA_PKEY;
ALTER TABLE V3_CAPABILITY_METADATA ADD CONSTRAINT V3_CAPABILITY_METADATA_PKEY PRIMARY KEY (CAPABILITY_ID, CAPABILITY_TYPE);
ALTER TABLE V3_CAPABILITY_INSTANCES ADD CONSTRAINT V3_CAPABILITY_INSTANCES_FK0 FOREIGN KEY (CAPABILITY_ID,CAPABILITY_TYPE) REFERENCES V3_CAPABILITY_METADATA(CAPABILITY_ID,CAPABILITY_TYPE);

-- Drop column Version from V3_CAPABILITY_METADATA
ALTER TABLE V3_CAPABILITY_METADATA DROP COLUMN IF EXISTS VERSION;

-- Drop Column PACKAGE from V3_CAPABILITY_METADATA
ALTER TABLE V3_CAPABILITY_METADATA DROP COLUMN IF EXISTS PACKAGE;

-- Add app_description in V3_APPS table
ALTER TABLE V3_APPS ADD COLUMN IF NOT EXISTS APP_DESCRIPTION  VARCHAR(255);

-- Add unique key for naming app
ALTER TABLE V3_APPS DROP CONSTRAINT IF EXISTS V3_APPS_UNIQUE_NAME;
ALTER TABLE V3_APPS ADD CONSTRAINT V3_APPS_UNIQUE_NAME UNIQUE (DP_ID, NAMESPACE, CAPABILITY_INSTANCE_ID, APP_NAME, APP_VERSION);
--
-- Recreate V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES
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
    DP.CREATED_DATE AS CREATED_TIME,
    DP.MODIFIED_DATE,
    DP.TAGS,
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

-- Add EMS details into capability metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION)
VALUES ('PULSAR','TIBCO® Messaging Quasar - Powered by Apache Pulsar™','TIBCO Messaging Quasar - Powered by Apache Pulsar (Pulsar) combines both streaming and queueing in a single open-source project with enterprise class support.')
ON CONFLICT DO NOTHING;

-- Update PULSAR capability description
UPDATE V3_CAPABILITY_METADATA SET DESCRIPTION='TIBCO® Messaging Quasar - Powered by Apache Pulsar™' WHERE CAPABILITY_ID='PULSAR';

-- drop v2_secret_hash table and its associated Functions and Triggers
DROP FUNCTION IF EXISTS V2_SECRET_HASH_INSERT_CREATED_TIME() CASCADE;
DROP FUNCTION IF EXISTS VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER() CASCADE;
DROP TRIGGER IF EXISTS VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER ON V2_SECRET_HASH;
DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_SECRET_HASH_AUDIT_TRAIL ON V2_SECRET_HASH;
DROP TRIGGER IF EXISTS INSERT_CREATED_TIME ON V2_SECRET_HASH;
DROP TABLE IF EXISTS V2_SECRET_HASH CASCADE;

-- Add new column capability_instance_metadata in capability instance table
ALTER TABLE V3_CAPABILITY_INSTANCES ADD COLUMN IF NOT EXISTS CAPABILITY_INSTANCE_METADATA JSONB NOT NULL DEFAULT '{}';

-- Add new column capability_instance_metadata in V3_ARCHIVED_CAPABILITY_INSTANCES
ALTER TABLE V3_ARCHIVED_CAPABILITY_INSTANCES ADD COLUMN IF NOT EXISTS CAPABILITY_INSTANCE_METADATA JSONB NOT NULL DEFAULT '{}';

--
-- Restructure V3_VIEW_DATA_PLANE_MONITOR_DETAILS to have CAPABILITY_INSTANCE_METADATA
--
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_MONITOR_DETAILS
AS
SELECT
    VDP.SUBSCRIPTION_ID,
    json_agg(row_to_json((
        SELECT ColumnName
        FROM (SELECT VDP.DP_ID, VDP.REGISTERED_REGION, VDP.RUNNING_REGION, VDP.DP_CONFIG, VDP.STATUS, VDP.HOST_CLOUD_TYPE, DPCP.CAPABILITIES)
                 AS ColumnName (DP_ID, REGISTERED_REGION, RUNNING_REGION, DP_CONFIG, DP_STATUS, HOST_CLOUD_TYPE, CAPABILITIES)
    ))) DATAPLANES
FROM V3_DATA_PLANES VDP LEFT JOIN (SELECT DP_ID, json_agg(row_to_json((
    SELECT ColumnName
    FROM (
             SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CI.CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, CI.VERSION, STATUS, REGION, TAGS)
             AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, NAME, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, VERSION, STATUS, REGION, TAGS)
))) CAPABILITIES
                                   FROM (V3_CAPABILITY_INSTANCES CI LEFT JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID,CAPABILITY_TYPE))
                                   GROUP BY DP_ID) DPCP USING(DP_ID)
GROUP BY VDP.SUBSCRIPTION_ID
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_DATA_PLANE_MONITOR_DETAILS_INDEX ON V3_VIEW_DATA_PLANE_MONITOR_DETAILS (SUBSCRIPTION_ID);


--
-- Restructure V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES to have CAPABILITY_INSTANCE_METADATA
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
    DP.CREATED_DATE AS CREATED_TIME,
    DP.MODIFIED_DATE,
    DP.TAGS,
    CI.CAPABILITIES,
    AA.APPS,
    RI.RESOURCE_INSTANCE_METADATA
FROM ((
    V3_DATA_PLANES DP
        LEFT JOIN (
        SELECT DP_ID, json_agg(row_to_json((
            SELECT ColumnName
            FROM (SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CR.CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, CI.VERSION, STATUS, REGION, TAGS, CI.MODIFIED_TIME)
                     AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, CAPABILITY_NAME, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, VERSION, STATUS, REGION, TAGS, MODIFIED_TIME)
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

--Update O11Y resource_metadata to make metrics-exporter endpoint as optional bit
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"logsServers","name":"O11Y logsServers","value":{"servers":[{"kind":"elasticSearch","name":"ES-Log-Server","label":"Elastic Search","type":"logsServer","fields":[{"key":"kind","name":"logsServer kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.userapp.logindex","name":"User App Log Index","dataType":"string","required":true},{"key":"config.services.logindex","name":"Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.endpoint","name":"Proxy User App Log Index Endpoint","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.username","name":"config.Proxy User App Log Index Username","dataType":"string","required":false},{"key":"config.exporter.userapp.logindex.endpoint","name":"Exporter User App LogINdex Endpoint","dataType":"string","required":true},{"key":"config.exporter.userapp.logindex.username","name":"Exporter User App Log Index Username","dataType":"string","required":false},{"key":"config.exporter.services.logindex.username","name":"Exporter Services Log Index Username","dataType":"string","required":false},{"key":"config.exporter.services.logindex.endpoint","name":"Exporter Services Log Index Endpoint","dataType":"string","required":true},{"key":"secret.proxy.userapp.logindex.password","name":"User App Proxy Password","dataType":"string","required":false},{"key":"secret.exporter.userapp.logindex.password","name":"Exporter User App Log Index Password","dataType":"string","required":false},{"key":"secret.exporter.services.logindex.password","name":"Services Exporter Password","dataType":"string","required":false}]}]},"dataType":"map","required":true},{"key":"tracesServers","name":"O11Y tracesServers","value":{"servers":[{"kind":"jaeger","name":"Jaeger-Traces-Server","label":"Jaeger","type":"tracesServer","fields":[{"key":"kind","name":"tracesServer kind","value":"jaeger","dataType":"string","required":true},{"key":"config.es.endpoint","name":"Jaeger Endpoint","dataType":"string","required":true},{"key":"config.es.username","name":"Jaeger Username","dataType":"string","required":false},{"key":"secret.es.password","name":"Jaeger Password","dataType":"string","required":false}]}]},"dataType":"map","required":true},{"key":"metricsServers","name":"O11Y metricsServers","value":{"servers":[{"kind":"prometheus","name":"Prometheus-Metrics-Server","label":"Prometheus","type":"metricsServer","fields":[{"key":"kind","name":"metricsServer kind","value":"prometheus","dataType":"string","required":true},{"key":"config.proxy.endpoint","name":"Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.username","name":"Proxy Username","dataType":"string","required":false},{"key":"config.exporter.endpoint","name":"Exporter Endpoint","dataType":"string","required":false},{"key":"secret.proxy.password","name":"Proxy Password","dataType":"string","required":false},{"key":"secret.exporter.token","name":"Exporter Token","dataType":"string","required":false}]}]},"dataType":"map","required":true}]}'
WHERE RESOURCE_ID = 'O11Y' AND RESOURCE_LEVEL = 'PLATFORM';

--Re create V3_VIEW_APPS_ON_SUBSCRIPTIONS view as we have to alter the schema of this.
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
    CI.NAMESPACE as capability_instance_namespace,
    CI.STATUS as capability_instance_status,
    CI.TAGS as capability_instance_tags,
    CI.VERSION as capability_instance_version,
    APPS.APP_ID,
    APPS.APP_NAME,
    APPS.APP_DESCRIPTION,
    APPS.APP_VERSION,
    APPS.STATE as app_state,
    APPS.TAGS as app_tags,
    APPS.CREATED_TIME,
    APPS.MODIFIED_TIME,
    APPS.NAMESPACE as app_namespace,
    (select CONCAT(U.firstname || ' ',lastname) from v2_users U where U.USER_ENTITY_ID = APPS.MODIFIED_BY)
        as modified_by,
    (select CONCAT(U.firstname|| ' ',lastname) from v2_users U where U.USER_ENTITY_ID = APPS.CREATED_BY)
        as CREATED_by
FROM V2_SUBSCRIPTIONS SUB JOIN V3_DATA_PLANES DP ON SUB.SUBSCRIPTION_ID = DP.SUBSCRIPTION_ID
                          JOIN V3_CAPABILITY_INSTANCES CI ON DP.DP_ID = CI.DP_ID
                          JOIN V3_APPS APPS ON CI.CAPABILITY_INSTANCE_ID = APPS.CAPABILITY_INSTANCE_ID
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_APPS_ON_SUBSCRIPTIONS_INDEX ON V3_VIEW_APPS_ON_SUBSCRIPTIONS (SUBSCRIPTION_ID,REGISTERED_REGION,DP_ID,CAPABILITY_INSTANCE_ID,APP_ID);
