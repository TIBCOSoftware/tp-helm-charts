-- Database schema changes for 1.2.0

-- Update database schema at the end (earlier version is 1.1.0 i.e. 3)
UPDATE schema_version SET version = 4;

-- Update O11Y Resource config to make all fields optional
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"logsServers","name":"O11Y logsServers","value":{"servers":[{"kind":"elasticSearch","name":"ES-Log-Server","type":"logsServer","label":"Elastic Search","fields":[{"key":"kind","name":"logsServer kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.userapp.logindex","name":"User App Log Index","dataType":"string","required":true},{"key":"config.services.logindex","name":"Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.endpoint","name":"Proxy User App Log Index Endpoint","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.username","name":"config.Proxy User App Log Index Username","dataType":"string","required":false},{"key":"config.exporter.userapp.logindex.endpoint","name":"Exporter User App LogINdex Endpoint","dataType":"string","required":true},{"key":"config.exporter.userapp.logindex.username","name":"Exporter User App Log Index Username","dataType":"string","required":false},{"key":"config.exporter.services.logindex.username","name":"Exporter Services Log Index Username","dataType":"string","required":false},{"key":"config.exporter.services.logindex.endpoint","name":"Exporter Services Log Index Endpoint","dataType":"string","required":true},{"key":"secret.proxy.userapp.logindex.password","name":"User App Proxy Password","dataType":"string","required":false},{"key":"secret.exporter.userapp.logindex.password","name":"Exporter User App Log Index Password","dataType":"string","required":false},{"key":"secret.exporter.services.logindex.password","name":"Services Exporter Password","dataType":"string","required":false}]}]},"dataType":"map","required":false},{"key":"tracesServers","name":"O11Y tracesServers","value":{"servers":[{"kind":"jaeger","name":"Jaeger-Traces-Server","type":"tracesServer","label":"Jaeger","fields":[{"key":"kind","name":"tracesServer kind","value":"jaeger","dataType":"string","required":true},{"key":"config.es.endpoint","name":"Jaeger Endpoint","dataType":"string","required":true},{"key":"config.es.username","name":"Jaeger Username","dataType":"string","required":false},{"key":"secret.es.password","name":"Jaeger Password","dataType":"string","required":false}]}]},"dataType":"map","required":false},{"key":"metricsServers","name":"O11Y metricsServers","value":{"servers":[{"kind":"prometheus","name":"Prometheus-Metrics-Server","type":"metricsServer","label":"Prometheus","fields":[{"key":"kind","name":"metricsServer kind","value":"prometheus","dataType":"string","required":true},{"key":"config.proxy.endpoint","name":"Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.username","name":"Proxy Username","dataType":"string","required":false},{"key":"config.exporter.endpoint","name":"Exporter Endpoint","dataType":"string","required":false},{"key":"secret.proxy.password","name":"Proxy Password","dataType":"string","required":false},{"key":"secret.exporter.token","name":"Exporter Token","dataType":"string","required":false}]}]},"dataType":"map","required":false}]}'
WHERE RESOURCE_ID = 'O11Y' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add RESOURCE_INSTANCE_IDS in V3_APPS table
ALTER TABLE V3_APPS ADD COLUMN IF NOT EXISTS RESOURCE_INSTANCE_IDS TEXT[];

-- create V3_VALIDATE_INGRESS_CONTROLLER_INSTANCE_ID func to validate RESOURCE_INSTANCE_IDS being added to V3_APPS table
DROP FUNCTION IF EXISTS V3_VALIDATE_APPS_RESOURCE_INSTANCE_ID() CASCADE;
CREATE FUNCTION V3_VALIDATE_APPS_RESOURCE_INSTANCE_ID()
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
$FUNCTION$
;

DROP TRIGGER IF EXISTS V3_VALIDATE_INGRESS_CONTROLLER_INSTANCE_ID_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VALIDATE_INGRESS_CONTROLLER_INSTANCE_ID_TRIGGER BEFORE INSERT OR UPDATE ON V3_APPS FOR EACH ROW EXECUTE PROCEDURE V3_VALIDATE_APPS_RESOURCE_INSTANCE_ID();

-- Add comment in V2_ACCOUNTS table
ALTER TABLE V2_ACCOUNTS ADD COLUMN IF NOT EXISTS COMMENT VARCHAR(255);

-- Refresh materialized view V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
DROP FUNCTION IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH()
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
    INSERT OR UPDATE OR DELETE
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

-- Create Materialized view V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
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

-- Refresh materialized view V3_VIEW_TAGS_DATA_PLANES
DROP FUNCTION IF EXISTS V3_VIEW_TAGS_DATA_PLANES_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_TAGS_DATA_PLANES_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
	AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_TAGS_DATA_PLANES;
RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_DATA_PLANES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_TAGS_DATA_PLANES_DP_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_DATA_PLANES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_DATA_PLANES_REFRESH();


DROP TRIGGER IF EXISTS V3_VIEW_TAGS_DATA_PLANES_APP_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_TAGS_DATA_PLANES_APP_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_APPS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_DATA_PLANES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_TAGS_DATA_PLANES_CI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_DATA_PLANES_REFRESH();

-- create Materialized view to get tags of the data-planes
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_TAGS_DATA_PLANES CASCADE;

CREATE MATERIALIZED VIEW V3_VIEW_TAGS_DATA_PLANES
AS
SELECT
    DP.DP_ID,
    DP.TAGS AS DP_TAGS,
    DP.SUBSCRIPTION_ID,
    (SELECT ARRAY(SELECT DISTINCT unnest(tags) FROM V3_APPS AA WHERE AA.dp_id = DP.DP_ID) AS APPS_TAGS),
    (SELECT ARRAY(SELECT DISTINCT unnest(tags) FROM V3_CAPABILITY_INSTANCES CI WHERE CI.dp_id = DP.DP_ID) AS CAPABILITY_INSTNACES_TAGS)
FROM V3_DATA_PLANES DP
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_TAGS_DATA_PLANES_INDEX ON V3_VIEW_TAGS_DATA_PLANES (DP_ID);


-- Refresh materialized view V3_VIEW_TAGS_CAPABILITY_INSTANCES
DROP FUNCTION IF EXISTS V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
	AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_TAGS_CAPABILITY_INSTANCES;
RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_CAPABILITY_INSTANCES_APP_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_TAGS_CAPABILITY_INSTANCES_APP_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_APPS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_CAPABILITY_INSTANCES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_TAGS_CAPABILITY_INSTANCES_CI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH();

-- create Materialized view to get tags of the CAPABILITIES INSTANCES
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_TAGS_CAPABILITY_INSTANCES CASCADE;

CREATE MATERIALIZED VIEW V3_VIEW_TAGS_CAPABILITY_INSTANCES
AS
SELECT
    CI.CAPABILITY_INSTANCE_ID,
    CI.TAGS AS CAPABILITY_INSTANCES_TAGS,
    (SELECT ARRAY(SELECT DISTINCT unnest(tags) FROM V3_APPS AA WHERE AA.CAPABILITY_INSTANCE_ID = CI.CAPABILITY_INSTANCE_ID) AS APPS_TAGS)
FROM V3_CAPABILITY_INSTANCES CI
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_TAGS_CAPABILITY_INSTANCES_INDEX ON V3_VIEW_TAGS_CAPABILITY_INSTANCES(CAPABILITY_INSTANCE_ID);

-- PCP-4440: Update INGRESS resource metadata to have kong in 'ingressController' field's valid values UI dropdown hint/enum, add 'regex' and 'maxLength' keys to 'ingressClassName' and 'fqdn' fields
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"ingressController","enum":["nginx","kong"],"name":"Ingress Controller","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"ingressClassName","name":"Ingress Class Name","dataType":"string","required":true,"regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","maxLength":"63"},{"key":"fqdn","name":"FQDN","dataType":"string","required":true,"regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","maxLength":"255"}]}'
WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';


--
-- Restructure V3_VIEW_DATA_PLANE_MONITOR_DETAILS to have namespaces
--
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_MONITOR_DETAILS
AS
SELECT
    VDP.SUBSCRIPTION_ID,
    json_agg(row_to_json((
        SELECT ColumnName
        FROM (SELECT VDP.DP_ID, VDP.REGISTERED_REGION, VDP.RUNNING_REGION, VDP.DP_CONFIG, VDP.STATUS, VDP.HOST_CLOUD_TYPE, VDP.NAMESPACES, DPCP.CAPABILITIES)
                 AS ColumnName (DP_ID, REGISTERED_REGION, RUNNING_REGION, DP_CONFIG, DP_STATUS, HOST_CLOUD_TYPE, NAMESPACES, CAPABILITIES)
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

-- PCP-4828 Update PULSAR Capability description
UPDATE V3_CAPABILITY_METADATA
SET DESCRIPTION = 'TIBCO Messaging Quasar - Powered by Apache Pulsar combines both streaming and queueing in a single open-source project with enterprise class support.'
WHERE CAPABILITY_ID = 'PULSAR' AND CAPABILITY_TYPE = 'PLATFORM';

--
-- Update O11Y resources to support custom headers and disabled exporters
--
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"logsServers","name":"O11Y logsServers","value":{"servers":[{"kind":"elasticSearch","name":"ES-Log-Server","type":"logsServer","label":"Elastic Search/OpenSearch","fields":[{"key":"kind","name":"logsServer kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.proxy.userapp.enabled","name":"LogsServer Exporter User App Enabled","value":false,"enables":"logsProxyUserAppConfiguration","dataType":"boolean","required":true},{"key":"config.exporter.userapp.enabled","name":"LogsServer Exporter User App Enabled","value":true,"enables":"logsExporterUserAppConfiguration","dataType":"boolean","required":true},{"key":"config.exporter.services.enabled","name":"LogsServer Exporter Services Enabled","value":true,"enables":"logsExporterUserAppConfiguration","dataType":"boolean","required":true},{"key":"config.userapp.logindex","name":"User App Log Index","dataType":"string","required":true},{"key":"config.services.logindex","name":"Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.endpoint","name":"Proxy User App Log Index Endpoint","dataType":"string","required":true,"enabledBy":"logsProxyUserAppConfiguration"},{"key":"config.proxy.userapp.logindex.username","name":"config.Proxy User App Log Index Username","dataType":"string","required":false,"enabledBy":"logsProxyUserAppConfiguration"},{"key":"config.exporter.userapp.logindex.endpoint","name":"Exporter User App LogINdex Endpoint","dataType":"string","required":true,"enabledBy":"logsExporterUserAppConfiguration"},{"key":"config.exporter.userapp.logindex.username","name":"Exporter User App Log Index Username","dataType":"string","required":false,"enabledBy":"logsExporterUserAppConfiguration"},{"key":"config.exporter.services.logindex.username","name":"Exporter Services Log Index Username","dataType":"string","required":false,"enabledBy":"logsExporterServicesConfiguration"},{"key":"config.exporter.services.logindex.endpoint","name":"Exporter Services Log Index Endpoint","dataType":"string","required":true,"enabledBy":"logsExporterServicesConfiguration"},{"key":"secret.proxy.userapp.logindex.password","name":"User App Proxy Password","dataType":"string","required":false,"enabledBy":"logsProxyUserAppConfiguration"},{"key":"secret.exporter.userapp.logindex.password","name":"Exporter User App Log Index Password","dataType":"string","required":false,"enabledBy":"logsExporterUserAppConfiguration"},{"key":"secret.exporter.services.logindex.password","name":"Services Exporter Password","dataType":"string","required":false,"enabledBy":"logsExporterServicesConfiguration"},{"key":"secret.exporter.services.headers","name":"Exporter Services Custom Headers","dataType":"map","required":false,"enabledBy":"logsExporterServicesConfiguration"},{"key":"secret.exporter.userapp.headers","name":"Exporter User App Custom Headers","dataType":"map","required":false,"enabledBy":"logsExporterUserAppConfiguration"},{"key":"secret.proxy.userapp.headers","name":"Proxy User App Custom Headers","dataType":"map","required":false,"enabledBy":"logsProxyUserAppConfiguration"}]}]},"dataType":"map","required":false,"enableFlags":{"logsProxyUserAppConfiguration":true,"logsExporterUserAppConfiguration":true,"logsExporterServicesConfiguration":true}},{"key":"tracesServers","name":"O11Y tracesServers","value":{"servers":[{"kind":"jaeger","name":"Jaeger-Traces-Server","type":"tracesServer","label":"Jaeger","fields":[{"key":"kind","name":"tracesServer kind","value":"jaeger","dataType":"string","required":true},{"key":"enabled","name":"TracesServer enabled","value":true,"enables":"tracesServerConfiguration","dataType":"boolean","required":true},{"key":"config.es.endpoint","name":"Jaeger Endpoint","dataType":"string","required":true,"enabledBy":"tracesServerConfiguration"},{"key":"config.es.username","name":"Jaeger Username","dataType":"string","required":false,"enabledBy":"tracesServerConfiguration"},{"key":"secret.es.password","name":"Jaeger Password","dataType":"string","required":false,"enabledBy":"tracesServerConfiguration"},{"key":"secret.es.headers","name":"Traces Custom Headers","dataType":"map","required":false,"enabledBy":"tracesServerConfiguration"}]}]},"dataType":"map","required":false,"enableFlags":{"tracesServerConfiguration":true}},{"key":"metricsServers","name":"O11Y metricsServers","value":{"servers":[{"kind":"prometheus","name":"Prometheus-Metrics-Server","type":"metricsServer","label":"Prometheus/VictoriaMetrics","fields":[{"key":"kind","name":"metricsServer kind","value":"prometheus","dataType":"string","required":true},{"key":"config.proxy.enabled","name":"MetricsServer Proxy Enabled","value":true,"enables":"metricsProxyConfiguration","dataType":"boolean","required":true},{"key":"config.proxy.endpoint","name":"Proxy Endpoint","dataType":"string","required":true,"enabledBy":"metricsProxyConfiguration"},{"key":"config.proxy.username","name":"Proxy Username","dataType":"string","required":false,"enabledBy":"metricsProxyConfiguration"},{"key":"secret.proxy.password","name":"Proxy Password","dataType":"string","required":false,"enabledBy":"metricsProxyConfiguration"},{"key":"secret.proxy.headers","name":"Metrics Proxy Custom Headers","dataType":"map","required":false,"enabledBy":"metricsProxyConfiguration"}]}]},"dataType":"map","required":false,"enableFlags":{"metricsProxyConfiguration":true}}]}'
WHERE RESOURCE_ID = 'O11Y' AND RESOURCE_LEVEL = 'PLATFORM';

-- PCP-5139 Disable all triggers populating data in tscutdb_audit.v3_events table
ALTER TABLE V2_ACCOUNTS DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V2_ACCOUNTS_AUDIT_TRAIL;
ALTER TABLE V2_EULA_STATUS DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V2_EULA_STATUS_AUDIT_TRAIL;
ALTER TABLE V2_EXTERNAL_ACCOUNTS DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V2_EXTERNAL_ACCOUNTS_AUDIT_TRAIL;
ALTER TABLE V2_SUBSCRIPTIONS DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V2_SUBSCRIPTIONS_AUDIT_TRAIL;
ALTER TABLE V2_USERS DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V2_USERS_AUDIT_TRAIL;
ALTER TABLE V3_DATA_PLANES DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V3_DATA_PLANES_AUDIT_TRAIL;
ALTER TABLE V3_CAPABILITY_INSTANCES DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V3_CAPABILITY_INSTANCES_AUDIT_TRAIL;
ALTER TABLE V3_APPS DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V3_APPS_AUDIT_TRAIL;
ALTER TABLE V3_RESOURCE_INSTANCES DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V3_RESOURCE_INSTANCES_AUDIT_TRAIL;
ALTER TABLE V3_RESOURCE_SCOPES DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V3_RESOURCE_SCOPES_AUDIT_TRAIL;
ALTER TABLE V3_RESOURCES DISABLE TRIGGER V3_EVENTS_AUDIT_SET_V3_RESOURCES_AUDIT_TRAIL;

-- PCP-5236: Update Flogo capability's display_name
UPDATE V3_CAPABILITY_METADATA SET DISPLAY_NAME = 'TIBCO Flogo® Enterprise' WHERE CAPABILITY_ID = 'FLOGO' AND CAPABILITY_TYPE = 'PLATFORM';

-- PCP-5641: Remove TETRIS row from v3_capability_metadata table
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'TETRIS' AND CAPABILITY_TYPE = 'PLATFORM';