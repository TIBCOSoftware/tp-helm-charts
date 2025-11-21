-- Database schema changes for 1.9.0

-- PCP-12191 [o11y] Update o11yv3 resource template to include the new secondary exporters
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"O11YV3 Resources","name":"O11YV3 Resources","value":{"exporters":{"logsServerUserApps":{"kind":"","instanceId":"","scope":"","enabled":false},"logsServerUserAppsSecondary":{"kind":"","instanceId":"","scope":"","enabled":false},"logsServerServicesSecondary":{"kind":"","instanceId":"","scope":"","enabled":false},"metricsServerSecondary":{"kind":"","instanceId":"","scope":"","enabled":false},"tracesServerSecondary":{"kind":"","instanceId":"","scope":"","enabled":false},"logsServerServices":{"kind":"","instanceId":"","scope":"","enabled":false},"logsServerAuditSafe":{"kind":"","instanceId":"","scope":"","enabled":false},"metricsServer":{"kind":"","instanceId":"","scope":"","enabled":false},"tracesServer":{"kind":"","instanceId":"","scope":"","enabled":false}},"proxies":{"logsServerUserApps":{"kind":"","instanceId":"","scope":"","enabled":false},"logsServerAuditSafe":{"kind":"","instanceId":"","scope":"","enabled":false},"metricsServer":{"kind":"","instanceId":"","scope":"","enabled":false},"tracesServer":{"kind":"","instanceId":"","scope":"","enabled":false}}}}]}'
WHERE RESOURCE_ID = 'O11YV3' AND RESOURCE_LEVEL = 'PLATFORM' AND TYPE = 'Observability';

-- Add O11Y LogsServer Exporter ElasticSearch AuditSafe Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_AS_ES','Observability LogsServer Exporter AuditSafe Resources','Observability LogsServer Exporter AuditSafe Resources','logsExporterAuditSafe','{"fields":[{"key":"LogsServer Exporter AuditSafe ElasticSearch","name":"LogsServer Exporter AuditSafe ElasticSearch","value":{"elasticSearch":{"name":"logsExporterAuditSafeElasticSearch","type":"logsServer","label":"ElasticSearch","fields":[{"key":"config.exporter.auditSafe.elasticSearch.logIndex","name":"LogsServer ElasticSearch Exporter AuditSafe Log Index","dataType":"string","required":true},{"key":"config.exporter.auditSafe.enabled","name":"LogsServer ElasticSearch Exporter AuditSafe Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.auditSafe.kind","name":"LogsServer ElasticSearch Exporter AuditSafe kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.auditSafe.elasticSearch.endpoint","name":"LogsServer ElasticSearch Exporter AuditSafe Endpoint","dataType":"string","required":true},{"key":"config.exporter.auditSafe.elasticSearch.username","name":"LogsServer ElasticSearch Exporter AuditSafe Username","dataType":"string","required":false},{"key":"secret.exporter.auditSafe.elasticSearch.password","name":"LogsServer ElasticSearch Exporter AuditSafe Password","dataType":"string","required":false},{"key":"secret.exporter.auditSafe.elasticSearch.headers","name":"LogsServer ElasticSearch Exporter AuditSafe Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure","control-tower"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Proxy ElasticSearch AuditSafe Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_PRX_AS_ES','Observability LogsServer Proxy AuditSafe Resources','Observability LogsServer Proxy AuditSafe Resources','logsProxyAuditSafe','{"fields":[{"key":"LogsServer Proxy AuditSafe ElasticSearch","name":"LogsServer Proxy AuditSafe ElasticSearch","value":{"elasticSearch":{"name":"logsProxyAuditSafeElasticSearch","type":"logsServer","label":"ElasticSearch","fields":[{"key":"config.proxy.auditSafe.elasticSearch.logIndex","name":"LogsServer ElasticSearch Proxy AuditSafe Log Index","dataType":"string","required":true},{"key":"config.proxy.auditSafe.enabled","name":"LogsServer ElasticSearch Proxy AuditSafe Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.auditSafe.kind","name":"LogsServer ElasticSearch Proxy AuditSafe kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.proxy.auditSafe.elasticSearch.endpoint","name":"LogsServer ElasticSearch Proxy AuditSafe Endpoint","dataType":"string","required":true},{"key":"config.proxy.auditSafe.elasticSearch.username","name":"LogsServer ElasticSearch Proxy AuditSafe Username","dataType":"string","required":false},{"key":"secret.proxy.auditSafe.elasticSearch.password","name":"LogsServer ElasticSearch Proxy AuditSafe Password","dataType":"string","required":false},{"key":"secret.proxy.auditSafe.elasticSearch.headers","name":"LogsServer ElasticSearch Proxy AuditSafe Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure","control-tower"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- PCP-12448: [CP Backend] Need to have a System User in v2_users table
INSERT INTO V2_USERS (USER_ENTITY_ID,EMAIL,FIRSTNAME,LASTNAME,CREATED_BY,MODIFIED_BY,ACTIVATION_URL)
VALUES ('tp-cp-system-user','tp-cp-system-user@cloud.com','System','','tp-cp-system-user','tp-cp-system-user','')
    ON CONFLICT DO NOTHING;

-- PCP-11753 CP DB: Add ACTIVATION_SERVER resource
INSERT INTO v3_resources (RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('ACTIVATION_SERVER', 'ACTIVATION_SERVER Resource', 'ACTIVATION_SERVER Resource', 'activation_server', '{"fields": [ { "key": "url", "name": "url", "dataType": "string", "required": true }, { "key": "version", "name": "version", "value": "1.0.0", "dataType": "string", "required": false } ] }', '{"k8s","control-tower"}', 'PLATFORM')
    ON CONFLICT DO NOTHING;

-- Updating DB to include new capability MSGCORE
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('MSGCORE', 'Msg Core', 'Msg Core', 'INFRA')
    ON CONFLICT DO NOTHING;

-- PCP-12713 regression in ems health reporting
-- Refresh materialized view V3_VIEW_DATA_PLANE_MONITOR_DETAILS
DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- PCP-11625 [CP Backend] Enhance mat view V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER to include dp_name columns to allow sorting

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER;
    CREATE MATERIALIZED VIEW V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER
    AS
SELECT
    AR.RESOURCE_INSTANCE_ID AS RESOURCE_INSTANCE_ID,
    AR.RESOURCE_ID AS RESOURCE_ID,
    AR.RESOURCE_INSTANCE_NAME AS RESOURCE_INSTANCE_NAME,
    AR.RESOURCE_INSTANCE_DESCRIPTION AS RESOURCE_INSTANCE_DESCRIPTION,
    AR.RESOURCE_INSTANCE_METADATA AS RESOURCE_INSTANCE_METADATA,
    AR.SCOPE AS SCOPE,
    AR.REGION AS REGION,
    AR.SCOPE_ID AS SUBSCRIPTION_ID,
    ER.RESOURCE_INSTANCE_ID AS EMAIL_RECEIVER_ID,
    ER.RESOURCE_INSTANCE_NAME AS EMAIL_RECEIVER_NAME,
    ER.RESOURCE_INSTANCE_DESCRIPTION AS EMAIL_RECEIVER_DESCRIPTION,
    ER.RESOURCE_INSTANCE_METADATA AS EMAIL_RECEIVER_METADATA,
    DP.NAME AS DP_NAME,
    CASE
        WHEN COUNT(DP.DP_ID) = 0 THEN NULL
        ELSE json_agg(
                json_build_object(
                        'dp_id', DP.DP_ID,
                        'name', DP.NAME,
                        'description', DP.DESCRIPTION,
                        'registered_region',DP.REGISTERED_REGION,
                        'running_region',DP.RUNNING_REGION
                )
             )
        END AS DP_DETAILS
FROM
    V3_RESOURCE_INSTANCES AR
        JOIN
    V3_ALERT_RULES_TO_RECEIVERS ARR
    ON AR.RESOURCE_INSTANCE_ID = ARR.RULE_ID
        JOIN
    V3_RESOURCE_INSTANCES ER
    ON ARR.RECEIVER_ID = ER.RESOURCE_INSTANCE_ID
        LEFT JOIN V3_DATA_PLANES DP
                  ON DP.DP_ID = (
                      SELECT value->>'value'
FROM jsonb_array_elements(AR.RESOURCE_INSTANCE_METADATA->'fields') AS fields
WHERE fields->>'key' = 'dpId'
    )
WHERE
    AR.RESOURCE_ID = 'ALERT_RULE'
  AND ER.RESOURCE_ID = 'EMAIL_RECEIVER'
GROUP BY
    AR.RESOURCE_INSTANCE_ID, AR.RESOURCE_ID, AR.RESOURCE_INSTANCE_NAME, AR.RESOURCE_INSTANCE_DESCRIPTION,
    AR.RESOURCE_INSTANCE_METADATA, AR.SCOPE, AR.REGION, AR.SCOPE_ID, DP.NAME,
    ER.RESOURCE_INSTANCE_ID, ER.RESOURCE_INSTANCE_NAME, ER.RESOURCE_INSTANCE_DESCRIPTION, ER.RESOURCE_INSTANCE_METADATA;

CREATE UNIQUE INDEX V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_INDEX
    ON V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER USING btree (RESOURCE_INSTANCE_ID, EMAIL_RECEIVER_ID);

-- Update database schema at the end (earlier version is 1.8.0 i.e. 11)
UPDATE schema_version SET version = 12;
