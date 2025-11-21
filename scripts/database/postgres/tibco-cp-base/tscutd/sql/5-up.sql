-- Database schema changes for 1.3.0

-- Update database schema at the end (earlier version is 1.2.0 i.e. 4)
UPDATE schema_version SET version = 5;

-- PCP-5658: Add DBCONFIG resource
INSERT INTO v3_resources (resource_id, "name", description, "type", resource_metadata, resource_level, host_cloud_type)
VALUES('DBCONFIG', 'Database Resource', 'Database Resource', 'Database Resource', '{"fields":[{"key":"dbms","enum":["rdbms"],"name":"Database Management System","rdbms":{"key":"persistenceType","enum":[{"key":"postgres","name":"PostgreSQL"},{"key":"mysql","name":"MySQL"}],"name":"Database Type","mysql":[{"key":"dbUser","name":"Database User","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":4},{"key":"secretDbPassword","name":"Database Password","regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255","order":5},{"key":"dbHost","name":"Database Host","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":1},{"key":"dbPort","name":"Database Port","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":2},{"key":"dbName","name":"Database Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":3}],"dataType":"string","postgres":[{"key":"dbUser","name":"Database User","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":4},{"key":"secretDbPassword","name":"Database Password","regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255","order":5},{"key":"dbHost","name":"Database Host","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":1},{"key":"dbPort","name":"Database Port","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":2},{"key":"dbName","name":"Database Name","regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","order":3}],"required":true,"fieldType":"dropdown"},"dataType":"string","required":true,"fieldType":"dropdown"}]}'::jsonb, 'PLATFORM', '{aws,azure}')
ON CONFLICT DO NOTHING;

-- PCP-5890: Add APIM as a PLATFORM Capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('APIM','API Manager','Publish and Secure Application APIs with your API Management Solution','PLATFORM')
ON CONFLICT DO NOTHING;

-- PCP-6024
ALTER TABLE V2_ACCOUNT_USER_DETAILS
ALTER COLUMN TIBCO_AUTHENTICATION_GROUP TYPE TEXT;

-- PCP-6026
UPDATE V2_ACCOUNT_USER_DETAILS
SET TIBCO_AUTHENTICATION_GROUP = (
    SELECT jsonb_object_agg(key, 
        CASE
            WHEN jsonb_typeof(to_jsonb(TIBCO_AUTHENTICATION_GROUP::jsonb->key)) = 'array' THEN TIBCO_AUTHENTICATION_GROUP::jsonb->key
            ELSE to_jsonb(ARRAY[value])
        END
    )
    FROM jsonb_each_text(TIBCO_AUTHENTICATION_GROUP::jsonb)
);

-- PCP-6152: Add HAWKDOMAIN resource
INSERT INTO v3_resources (resource_id, "name", description, "type", resource_metadata, resource_level, host_cloud_type)
VALUES('HAWKDOMAIN', 'Hawk Domain', 'Hawk Domain', 'Control Tower', '{"fields":[{"key":"domainName","name":"Domain Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true},{"key":"transport","enum":["EMS","RV"],"name":"Transport","dataType":"string","required":true,"fieldType":"dropdown","EMS":[{"key":"emsServerUrl","name":"EMS Server URL","dataType":"string","required":true},{"key":"emsUserName","name":"EMS User Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true},{"key":"emsPassword","name":"EMS Password","dataType":"string","required":false},{"key":"emsSslTrusted","name":"EMS SSL Trusted","dataType":"string","required":false},{"key":"emsSslPrivateKey","name":"EMS SSL Private Key","dataType":"string","required":false},{"key":"emsSslIdentity","name":"EMS SSL Identity","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":false},{"key":"emsSslPassword","name":"EMS SSL Password","dataType":"string","required":false},{"key":"emsSslVendor","name":"EMS SSL Vendor","dataType":"string","required":false},{"key":"emsSslExpectedHostname","name":"EMS Ssl Expected Host Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":false},{"key":"emsSslNoVerifyHost","name":"EMS Ssl No Verify Host","dataType":"boolean","required":false},{"key":"emsSslNoVerifyHostname","name":"EMS Ssl No Verify Host Name","dataType":"boolean","required":false}],"RV":[{"key":"rvService","name":"RV Service","dataType":"string","required":true},{"key":"rvNetwork","name":"RV Network","dataType":"string","required":false},{"key":"rvDaemon","name":"RV Daemon","dataType":"string","required":false}]}]}'::jsonb, 'PLATFORM', '{control-tower}')
ON CONFLICT DO NOTHING;

-- PCP-6017: Add HAWKCONSOLE as a INFRA Capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('HAWKCONSOLE', 'Hawk Console', 'Hawk Console', 'INFRA')
ON CONFLICT DO NOTHING;

-- Update v3_resource table's primary key from (resource_id, resource_level) to (resource_id, resource_level, type)
ALTER TABLE v3_resources DROP CONSTRAINT IF EXISTS v3_resources_pkey CASCADE;
ALTER TABLE v3_resources ADD PRIMARY KEY (resource_id, resource_level, type);

-- Add O11YV3 Capability resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('O11YV3','Observability Resources V3','Observability Resources V3 Name','Observability','{"fields":[{"key":"O11YV3 Resources","name":"O11YV3 Resources","value":{"exporters":{"logsServerUserApps":{"kind":"","instanceId":"","scope":"","enabled":false},"logsServerServices":{"kind":"","instanceId":"","scope":"","enabled":false},"metricsServer":{"kind":"","instanceId":"","scope":"","enabled":false},"tracesServer":{"kind":"","instanceId":"","scope":"","enabled":false}},"proxies":{"logsServerUserApps":{"kind":"","instanceId":"","scope":"","enabled":false},"metricsServer":{"kind":"","instanceId":"","scope":"","enabled":false},"tracesServer":{"kind":"","instanceId":"","scope":"","enabled":false}}}}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-------Logs Server decoupled into exporter(userApps and services) and proxy(userApps)-----------
-- Add O11Y LogsServer Exporter ElasticSearch UserApps Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_UA_ES','Observability LogsServer Exporter UserApps Resources','Observability LogsServer Exporter UserApps Resources','logsExporterUserApps','{"fields":[{"key":"LogsServer Exporter UserApps ElasticSearch","name":"LogsServer Exporter UserApps ElasticSearch","value":{"elasticSearch":{"name":"logsExporterUserAppsElasticSearch","type":"logsServer","label":"ElasticSearch","fields":[{"key":"config.exporter.userApps.elasticSearch.logIndex","name":"LogsServer ElasticSearch Exporter UserApps Log Index","dataType":"string","required":true},{"key":"config.exporter.userApps.enabled","name":"LogsServer ElasticSearch Exporter UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.userApps.kind","name":"LogsServer ElasticSearch Exporter UserApps kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.userApps.elasticSearch.endpoint","name":"LogsServer ElasticSearch Exporter UserApps Endpoint","dataType":"string","required":true},{"key":"config.exporter.userApps.elasticSearch.username","name":"LogsServer ElasticSearch Exporter UserApps Username","dataType":"string","required":false},{"key":"secret.exporter.userApps.elasticSearch.password","name":"LogsServer ElasticSearch Exporter UserApps Password","dataType":"string","required":false},{"key":"secret.exporter.userApps.elasticSearch.headers","name":"LogsServer ElasticSearch Exporter UserApps Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

--  Post 1.3.0 -- Add O11Y LogsServer Exporter OpenSearch UserApps Capability resources
-- INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
-- VALUES ('LOGS_EXP_UA_OS','Observability LogsServer Exporter UserApps Resources','Observability LogsServer Exporter UserApps Resources','logsExporterUserApps','{"fields":[{"key":"LogsServer Exporter UserApps OpenSearch","name":"LogsServer Exporter UserApps OpenSearch","value":{"openSearch":{"name":"logsExporterUserAppsOpenSearch","type":"logsServer","label":"OpenSearch","fields":[{"key":"config.exporter.userApps.logIndex","name":"LogsServer OpenSearch Exporter UserApps Log Index","dataType":"string","required":true},{"key":"config.exporter.userApps.enabled","name":"LogsServer OpenSearch Exporter UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.userApps.kind","name":"LogsServer OpenSearch Exporter UserApps kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.userApps.openSearch.endpoint","name":"LogsServer OpenSearch Exporter UserApps Endpoint","dataType":"string","required":true},{"key":"config.exporter.userApps.openSearch.username","name":"LogsServer OpenSearch Exporter UserApps Username","dataType":"string","required":true},{"key":"secret.exporter.userApps.openSearch.password","name":"LogsServer OpenSearch Exporter UserApps Password","dataType":"string","required":false},{"key":"secret.exporter.userApps.openSearch.headers","name":"LogsServer OpenSearch Exporter UserApps Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
--     ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Exporter Kafka UserApps Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_UA_KAFKA','Observability LogsServer Exporter UserApps Resources','Observability LogsServer Exporter UserApps Resources','logsExporterUserApps','{"fields":[{"key":"LogsServer Exporter UserApps Kafka","name":"LogsServer Exporter UserApps Kafka","value":{"kafka":{"name":"logsExporterUserAppsKafka","type":"logsServer","label":"Kafka","fields":[{"key":"config.exporter.userApps.enabled","name":"LogsServer Kafka Exporter UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.userApps.kind","name":"LogsServer Kafka Exporter UserApps kind","value":"kafka","dataType":"string","required":true},{"key":"config.exporter.userApps.kafka.brokers","name":"LogsServer Kafka Exporter UserApps brokers","dataType":"array","required":true},{"key":"config.exporter.userApps.kafka.topic","name":"LogsServer Kafka Exporter UserApps Topic","dataType":"string","required":true},{"key":"config.exporter.userApps.kafka.protocol_version","name":"LogsServer Kafka Exporter UserApps Protocol Version","dataType":"string","required":true},{"key":"config.exporter.userApps.kafka.username","name":"LogsServer Kafka Exporter UserApps Protocol Version","dataType":"string","required":false},{"key":"secret.exporter.userApps.kafka.password","name":"LogsServer Kafka Exporter UserApps Password","dataType":"string","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Exporter OTLP UserApps Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_UA_OTLP','Observability LogsServer Exporter UserApps Resources','Observability LogsServer Exporter UserApps Resources','logsExporterUserApps','{"fields":[{"key":"LogsServer Exporter UserApps OTLPGRPC","name":"LogsServer Exporter UserApps OTLPGRPC","value":{"otlpgrpc":{"name":"logsExporterUserAppsOtlpgrpc","type":"logsServer","label":"OTLPGRPC","fields":[{"key":"config.exporter.userApps.enabled","name":"LogsServer OTLPGRPC Exporter UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.userApps.kind","name":"LogsServer OTLPGRPC Exporter UserApps kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.userApps.otlpgrpc.endpoint","name":"LogsServer OTLPGRPC Exporter UserApps Endpoint","dataType":"string","required":true},{"key":"config.exporter.userApps.otlpgrpc.endpoint.type","name":"LogsServer OTLPGRPC Exporter UserApps Endpoint Type","dataType":"string","required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Exporter ElasticSearch Services Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_SRV_ES','Observability LogsServer Exporter Services Resources','Observability LogsServer Exporter Services Resources','logsExporterServices','{"fields":[{"key":"LogsServer Exporter Services ElasticSearch","name":"LogsServer Exporter Services ElasticSearch","value":{"elasticSearch":{"name":"logsExporterServicesElasticSearch","type":"logsServer","label":"ElasticSearch","fields":[{"key":"config.exporter.services.elasticSearch.logIndex","name":"LogsServer ElasticSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.exporter.services.enabled","name":"LogsServer ElasticSearch Exporter Services Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.services.kind","name":"LogsServer ElasticSearch Exporter Services kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.services.elasticSearch.endpoint","name":"LogsServer ElasticSearch Exporter Services Endpoint","dataType":"string","required":true},{"key":"config.exporter.services.elasticSearch.username","name":"LogsServer LogsServer LogsServer ElasticSearch Exporter Services Username","dataType":"string","required":false},{"key":"secret.exporter.services.elasticSearch.password","name":"LogsServer ElasticSearch Exporter Services Password","dataType":"string","required":false},{"key":"secret.exporter.services.elasticSearch.headers","name":"LogsServer ElasticSearch Exporter Services Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Post 1.3.0 -- Add O11Y LogsServer Exporter OpenSearch Services Capability resources
-- INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
-- VALUES ('LOGS_EXP_SRV_OS','Observability LogsServer Exporter Services Resources','Observability LogsServer Exporter Services Resources','logsExporterServices','{"fields":[{"key":"LogsServer Exporter Services OpenSearch","name":"LogsServer Exporter Services OpenSearch","value":{"openSearch":{"name":"logsExporterServicesOpenSearch","type":"logsServer","label":"OpenSearch","fields":[{"key":"config.exporter.services.logIndex","name":"LogsServer OpenSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.exporter.services.enabled","name":"LogsServer OpenSearch Exporter Services Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.services.kind","name":"LogsServer OpenSearch Exporter Services kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.services.openSearch.endpoint","name":"LogsServer OpenSearch Exporter Services Endpoint","dataType":"string","required":true},{"key":"config.exporter.services.openSearch.username","name":"LogsServer OpenSearch Exporter Services Username","dataType":"string","required":true},{"key":"secret.exporter.services.openSearch.password","name":"LogsServer OpenSearch Exporter Services Password","dataType":"string","required":false},{"key":"secret.exporter.services.openSearch.headers","name":"LogsServer OpenSearch Exporter Services Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
--     ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Exporter Kafka Services Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_SRV_KAFKA','Observability LogsServer Exporter Services Resources','Observability LogsServer Exporter Services Resources','logsExporterServices','{"fields":[{"key":"LogsServer Exporter Services Kafka","name":"LogsServer Exporter Services Kafka","value":{"kafka":{"name":"logsExporterServicesKafka","type":"logsServer","label":"Kafka","fields":[{"key":"config.exporter.services.enabled","name":"LogsServer Kafka Exporter services Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.services.kind","name":"LogsServer Kafka Exporter Services kind","value":"kafka","dataType":"string","required":true},{"key":"config.exporter.services.kafka.brokers","name":"LogsServer Kafka Exporter Services brokers","dataType":"array","required":true},{"key":"config.exporter.services.kafka.topic","name":"LogsServer Kafka Exporter Services Topic","dataType":"string","required":true},{"key":"config.exporter.services.kafka.protocol_version","name":"LogsServer Kafka Exporter Services Protocol Version","dataType":"string","required":true},{"key":"config.exporter.services.kafka.username","name":"LogsServer Kafka Exporter Services Protocol Version","dataType":"string","required":false},{"key":"secret.exporter.services.kafka.password","name":"LogsServer Kafka Exporter Services Password","dataType":"string","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Exporter OTLP Services Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_EXP_SRV_OTLP','Observability LogsServer Exporter Services Resources','Observability LogsServer Exporter Services Resources','logsExporterServices','{"fields":[{"key":"LogsServer Exporter Services OTLPGRPC","name":"LogsServer Exporter Services OTLPGRPC","value":{"otlpgrpc":{"name":"logsExporterServicesOtlp","type":"logsServer","label":"OTLPGRPC","fields":[{"key":"config.exporter.services.enabled","name":"LogsServer OTLPGRPC Exporter Services Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.services.kind","name":"LogsServer OTLPGRPC Exporter Services kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.services.otlpgrpc.endpoint","name":"LogsServer OTLPGRPC Exporter Services Endpoint","dataType":"string","required":true},{"key":"config.exporter.services.otlpgrpc.endpoint.type","name":"LogsServer OTLPGRPC Exporter Services Endpoint Type","dataType":"string","required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Proxy ElasticSearch UserApps Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_PRX_UA_ES','Observability LogsServer Proxy UserApps Resources','Observability LogsServer Exporter Services Resources','logsProxyUserApps','{"fields":[{"key":"LogsServer Proxy UserApps ElasticSearch","name":"LogsServer Proxy UserApps","value":{"elasticSearch":{"name":"logsProxyUserAppsElasticSearch","type":"logsServer","label":"ElasticSearch","fields":[{"key":"config.proxy.elasticSearch.services.logIndex","name":"LogsServer ElasticSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userApps.enabled","name":"LogsServer ElasticSearch Proxy UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.userApps.kind","name":"LogsServer ElasticSearch Proxy UserApps kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.proxy.userApps.elasticSearch.endpoint","name":"LogsServer ElasticSearch Proxy UserApps Endpoint","dataType":"string","required":true},{"key":"config.proxy.userApps.elasticSearch.username","name":"LogsServer ElasticSearch Proxy UserApps Username","dataType":"string","required":false},{"key":"secret.proxy.userApps.elasticSearch.password","name":"LogsServer ElasticSearch Proxy UserApps Password","dataType":"string","required":false},{"key":"secret.proxy.userApps.elasticSearch.headers","name":"LogsServer ElasticSearch Proxy UserApps Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y LogsServer Proxy OpenSearch UserApps Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGS_PRX_UA_OS','Observability LogsServer Proxy UserApps Resources','Observability LogsServer Exporter Services Resources','logsProxyUserApps','{"fields":[{"key":"LogsServer Proxy UserApps OpenSearch","name":"LogsServer Proxy UserApps","value":{"openSearch":{"name":"logsProxyUserAppsOpenSearch","type":"logsServer","label":"OpenSearch","fields":[{"key":"config.proxy.openSearch.services.logIndex","name":"LogsServer OpenSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userApps.enabled","name":"LogsServer OpenSearch Proxy UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.userApps.kind","name":"LogsServer OpenSearch Proxy UserApps kind","value":"openSearch","dataType":"string","required":true},{"key":"config.proxy.userApps.openSearch.endpoint","name":"LogsServer OpenSearch Proxy UserApps Endpoint","dataType":"string","required":true},{"key":"config.proxy.userApps.openSearch.username","name":"LogsServer OpenSearch Proxy UserApps Username","dataType":"string","required":false},{"key":"secret.proxy.userApps.openSearch.password","name":"LogsServer OpenSearch Proxy UserApps Password","dataType":"string","required":false},{"key":"secret.proxy.userApps.openSearch.headers","name":"LogsServer OpenSearch Proxy UserApps Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-------Metrics Server decoupled into exporter and proxy-----------
-- Add O11Y MetricsServer Exporter Promethus Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('METRICS_EXP_PROM','Observability MetricsServer Exporter Resources','Observability MetricsServer Exporter Resources','metricsExporter','{"fields":[{"key":"MetricsServer Exporter Prometheus","name":"MetricsServer Exporter Prometheus","value":{"prometheus":{"name":"metricsExporterPrometheus","type":"metricsServer","label":"Prometheus","fields":[{"key":"config.exporter.enabled","name":"MetricsServer Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer Prometheus Exporter kind","value":"kafka","dataType":"string","required":true},{"key":"config.exporter.prometheus.endpoint","name":"MetricsServer Prometheus Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.prometheus.username","name":"MetricsServer Prometheus Exporter Protocol Version","dataType":"string","required":false},{"key":"secret.exporter.prometheus.password","name":"MetricsServer Prometheus Exporter Password","dataType":"string","required":false},{"key":"secret.exporter.prometheus.headers","name":"MetricsServer Proxy Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y MetricsServer Exporter Kafka Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('METRICS_EXP_KAFKA','Observability MetricsServer Exporter Resources','Observability MetricsServer Exporter Resources','metricsExporter','{"fields":[{"key":"MetricsServer Exporter Kafka","name":"MetricsServer Exporter Kafka","value":{"kafka":{"name":"metricsExporterKafka","type":"metricsServer","label":"Kafka","fields":[{"key":"config.exporter.enabled","name":"MetricsServer Kafka Exporter Enabled","value":true,"enables":"metricsExporterConfiguration","dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer Kafka Exporter kind","value":"kafka","dataType":"string","required":true},{"key":"config.exporter.kafka.brokers","name":"MetricsServer Kafka Exporter brokers","dataType":"array","required":true},{"key":"config.exporter.kafka.topic","name":"MetricsServer Kafka Exporter Topic","dataType":"string","required":true},{"key":"config.exporter.kafka.protocol_version","name":"MetricsServer Kafka Exporter Protocol Version","dataType":"string","required":true},{"key":"config.exporter.kafka.username","name":"MetricsServer Kafka Exporter Protocol Version","dataType":"string","required":false},{"key":"secret.exporter.kafka.password","name":"MetricsServer Kafka Exporter Password","dataType":"string","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y MetricsServer Exporter OTLP Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('METRICS_EXP_OTLP','Observability MetricsServer Exporter Resources','Observability MetricsServer Exporter Resources','metricsExporter','{"fields":[{"key":"MetricsServer Exporter OTLPGRPC","name":"MetricsServer Exporter OTLPGRPC","value":{"otlpgrpc":{"name":"metricsExporterOTLPGRPC","type":"metricsServer","label":"OTLPGRPC","fields":[{"key":"config.exporter.enabled","name":"MetricsServer OTLPGRPC Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer OTLPGRPC Exporter kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.otlpgrpc.endpoint","name":"MetricsServer OTLPGRPC Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.otlpgrpc.endpoint.type","name":"MetricsServer OTLPGRPC Exporter Endpoint Type","dataType":"bool","required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y MetricsServer Proxy Prometheus Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('METRICS_PRX_PROM','Observability MetricsServer Proxy Resources','Observability MetricsServer Proxy Resources','metricsProxy','{"fields":[{"key":"MetricsServer Proxy Prometheus","name":"MetricsServer Proxy Prometheus","value":{"prometheus":{"name":"metricsProxyPrometheus","type":"metricsServer","label":"Prometheus","fields":[{"key":"config.proxy.kind","name":"MetricsServer Proxy kind","value":"prometheus","dataType":"string","required":true},{"key":"config.proxy.enabled","name":"MetricsServer Proxy Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.prometheus.endpoint","name":"MetricsServer Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.prometheus.username","name":"MetricsServer Proxy Username","dataType":"string","required":false},{"key":"secret.proxy.prometheus.password","name":"MetricsServer Proxy Password","dataType":"string","required":false},{"key":"secret.proxy.prometheus.headers","name":"MetricsServer Proxy Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-------Traces Server decoupled into exporter and proxy-----------
-- Add O11Y Exporter TracesServer Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_EXP_ES','Observability TracesServer Exporter Resources','Observability TracesServer Exporter Resources','tracesExporter','{"fields":[{"key":"TracesServer Exporter ElasticSearch","name":"TracesServer Exporter ElasticSearch","value":{"elasticSearch":{"name":"tracesExporterElasticSearch","type":"tracesServer","label":"ElasticSearch","fields":[{"key":"config.exporter.elasticSearch.logIndex","name":"LogsServer ElasticSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.exporter.kind","name":"TracesServer kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.enabled","name":"TracesServer enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.elasticSearch.endpoint","name":"TracesServer Endpoint","dataType":"string","required":true},{"key":"config.exporter.elasticSearch.username","name":"TracesServer Username","dataType":"string","required":false},{"key":"secret.exporter.elasticSearch.password","name":"TracesServer Password","dataType":"string","required":false},{"key":"secret.exporter.elasticSearch.headers","name":"TracesServer Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y TracesServer Exporter Kafka Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_EXP_KAFKA','Observability TracesServer Exporter Resources','Observability TracesServer Exporter Resources','tracesExporter','{"fields":[{"key":"TracesServer Exporter Kafka","name":"TracesServer Exporter Kafka","value":{"kafka":{"name":"tracesExporterKafka","type":"tracesServer","label":"Kafka","fields":[{"key":"config.exporter.enabled","name":"Kafka Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"TracesServer Kafka Exporter kind","value":"kafka","dataType":"string","required":true},{"key":"config.exporter.kafka.brokers","name":"TracesServer Kafka Exporter brokers","dataType":"array","required":true},{"key":"config.exporter.kafka.topic","name":"TracesServer Kafka Exporter Topic","dataType":"string","required":true},{"key":"config.exporter.kafka.protocol_version","name":"TracesServer Kafka Exporter Protocol Version","dataType":"string","required":true},{"key":"config.exporter.kafka.username","name":"TracesServer Kafka Exporter Protocol Version","dataType":"string","required":false},{"key":"secret.exporter.kafka.password","name":"TracesServer Kafka Exporter Password","dataType":"string","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y TracesServer Exporter OTLP Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_EXP_OTLP','Observability TracesServer Exporter Resources','Observability TracesServer Exporter Resources','tracesExporter','{"fields":[{"key":"TracesServer Exporter OTLPGRPC","name":"TracesServer Exporter OTLPGRPC","value":{"otlpgrpc":{"name":"tracesExporterOTLPGRPC","type":"tracesServer","label":"OTLPGRPC","fields":[{"key":"config.exporter.enabled","name":"TracesServer OTLPGRPC Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"TracesServer OTLPGRPC Exporter kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.otlpgrpc.endpoint","name":"TracesServer OTLPGRPC Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.otlpgrpc.endpoint.type","name":"TracesServer OTLP Exporter Endpoint Type","dataType":"bool","required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y TracesServer Proxy ElasticSearch UserApps Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_PRX_ES','Observability TracesServer Proxy Resources','Observability TracesServer Proxy Resources','tracesProxy','{"fields":[{"key":"TracesServer Proxy Resource","name":"TracesServer Proxy Resource","value":{"elasticSearch":{"name":"tracesProxyElasticSearch","type":"tracesServer","label":"ElasticSearch","fields":[{"key":"config.proxy.enabled","name":"TracesServer ElasticSearch Proxy Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.kind","name":"TracesServer ElasticSearch Proxy kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.proxy.elasticSearch.endpoint","name":"TracesServer ElasticSearch Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.elasticSearch.username","name":"TracesServer ElasticSearch Proxy Username","dataType":"string","required":false},{"key":"secret.proxy.elasticSearch.password","name":"TracesServer ElasticSearch Proxy Password","dataType":"string","required":false},{"key":"secret.proxy.elasticSearch.headers","name":"TracesServer ElasticSearch Proxy Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Add O11Y TracesServer Proxy OpenSearch Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('TRACES_PRX_OS','Observability TracesServer Proxy Resources','Observability TracesServer Proxy Resources','tracesProxy','{"fields":[{"key":"TracesServer Proxy Resource","name":"TracesServer Proxy Resource","value":{"openSearch":{"name":"tracesProxyOpenSearch","type":"tracesServer","label":"OpenSearch","fields":[{"key":"config.proxy.enabled","name":"TracesServer OpenSearch Proxy Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.kind","name":"TracesServer OpenSearch Proxy kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.proxy.openSearch.endpoint","name":"TracesServer OpenSearch Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.openSearch.username","name":"TracesServer OpenSearch Proxy Username","dataType":"string","required":false},{"key":"secret.proxy.openSearch.password","name":"TracesServer OpenSearch Proxy Password","dataType":"string","required":false},{"key":"secret.proxy.openSearch.headers","name":"TracesServer OpenSearch Proxy Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}','{"aws","azure"}','PLATFORM')
    ON CONFLICT DO NOTHING;

-- Update V3_RESOURCE_INSTANCES table to capture resource type
ALTER TABLE V3_RESOURCE_INSTANCES ADD COLUMN IF NOT EXISTS RESOURCE_TYPE VARCHAR(255);

-- PCP-6189: Add BW6TEAAGENT resource
INSERT INTO v3_resources (resource_id, "name", description, "type", resource_metadata, resource_level, host_cloud_type)
VALUES('BW6TEAAGENT', 'BW6 TEA Agent', 'BW6 TEA Agent', 'Control Tower', '{"fields":[{"key":"name","name":"Name","dataType":"string","required":true},{"key":"ip","name":"IP","dataType":"string","required":true},{"key":"path","name":"Path","dataType":"string","required":true}]}'::jsonb, 'PLATFORM', '{control-tower}')
    ON CONFLICT DO NOTHING;

-- Update LOGS_PRX_UA_ES to correct logIndex Key
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"LogsServer Proxy UserApps ElasticSearch","name":"LogsServer Proxy UserApps","value":{"elasticSearch":{"name":"logsProxyUserAppsElasticSearch","type":"logsServer","label":"ElasticSearch","fields":[{"key":"config.proxy.userApps.elasticSearch.logIndex","name":"LogsServer ElasticSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userApps.enabled","name":"LogsServer ElasticSearch Proxy UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.userApps.kind","name":"LogsServer ElasticSearch Proxy UserApps kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.proxy.userApps.elasticSearch.endpoint","name":"LogsServer ElasticSearch Proxy UserApps Endpoint","dataType":"string","required":true},{"key":"config.proxy.userApps.elasticSearch.username","name":"LogsServer ElasticSearch Proxy UserApps Username","dataType":"string","required":false},{"key":"secret.proxy.userApps.elasticSearch.password","name":"LogsServer ElasticSearch Proxy UserApps Password","dataType":"string","required":false},{"key":"secret.proxy.userApps.elasticSearch.headers","name":"LogsServer ElasticSearch Proxy UserApps Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'LOGS_PRX_UA_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update LOGS_PRX_UA_OS to correct logIndex key
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"LogsServer Proxy UserApps OpenSearch","name":"LogsServer Proxy UserApps","value":{"openSearch":{"name":"logsProxyUserAppsOpenSearch","type":"logsServer","label":"OpenSearch","fields":[{"key":"config.proxy.userApps.openSearch.logIndex","name":"LogsServer OpenSearch Exporter Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userApps.enabled","name":"LogsServer OpenSearch Proxy UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.proxy.userApps.kind","name":"LogsServer OpenSearch Proxy UserApps kind","value":"openSearch","dataType":"string","required":true},{"key":"config.proxy.userApps.openSearch.endpoint","name":"LogsServer OpenSearch Proxy UserApps Endpoint","dataType":"string","required":true},{"key":"config.proxy.userApps.openSearch.username","name":"LogsServer OpenSearch Proxy UserApps Username","dataType":"string","required":false},{"key":"secret.proxy.userApps.openSearch.password","name":"LogsServer OpenSearch Proxy UserApps Password","dataType":"string","required":false},{"key":"secret.proxy.userApps.openSearch.headers","name":"LogsServer OpenSearch Proxy UserApps Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'LOGS_PRX_UA_OS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update LOGS_EXP_UA_OTLP to modify OTLP configuration
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"LogsServer Exporter UserApps OTLP","name":"LogsServer Exporter UserApps OTLP","value":{"otlp":{"name":"logsExporterUserAppsOtlpgrpc","type":"logsServer","label":"OTLP","fields":[{"key":"config.exporter.userApps.enabled","name":"LogsServer OTLP Exporter UserApps Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.userApps.kind","name":"LogsServer OTLP Exporter UserApps kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.userApps.otlp.endpoint","name":"LogsServer OTLP Exporter UserApps Endpoint","dataType":"string","required":true},{"key":"config.exporter.userApps.otlp.type","name":"LogsServer OTLP Exporter UserApps Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'LOGS_EXP_UA_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update LOGS_EXP_SRV_OTLP to modify OTLP configuration
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"LogsServer Exporter Services OTLP","name":"LogsServer Exporter Services OTLP","value":{"otlp":{"name":"logsExporterServicesOtlp","type":"logsServer","label":"OTLP","fields":[{"key":"config.exporter.services.enabled","name":"LogsServer OTLP Exporter Services Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.services.kind","name":"LogsServer OTLP Exporter Services kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.services.otlp.endpoint","name":"LogsServer OTLP Exporter Services Endpoint","dataType":"string","required":true},{"key":"config.exporter.services.otlp.type","name":"LogsServer OTLP Exporter Services Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'LOGS_EXP_SRV_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update METRICS_EXP_OTLP to modify OTLP configuration
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"MetricsServer Exporter OTLP","name":"MetricsServer Exporter OTLP","value":{"otlp":{"name":"metricsExporterOTLPGRPC","type":"metricsServer","label":"OTLP","fields":[{"key":"config.exporter.enabled","name":"MetricsServer OTLP Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer OTLP Exporter kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.otlp.endpoint","name":"MetricsServer OTLP Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.otlp.type","name":"MetricsServer OTLP Exporter Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'METRICS_EXP_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update TRACES_EXP_ES to remove logIndex key
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"TracesServer Exporter ElasticSearch","name":"TracesServer Exporter ElasticSearch","value":{"elasticSearch":{"name":"tracesExporterElasticSearch","type":"tracesServer","label":"ElasticSearch","fields":[{"key":"config.exporter.kind","name":"TracesServer kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.exporter.enabled","name":"TracesServer enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.elasticSearch.endpoint","name":"TracesServer Endpoint","dataType":"string","required":true},{"key":"config.exporter.elasticSearch.username","name":"TracesServer Username","dataType":"string","required":false},{"key":"secret.exporter.elasticSearch.password","name":"TracesServer Password","dataType":"string","required":false},{"key":"secret.exporter.elasticSearch.headers","name":"TracesServer Headers","dataType":"map","required":false}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'TRACES_EXP_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update TRACES_EXP_OTLP to modify OTLP configuration
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"TracesServer Exporter OTLP","name":"TracesServer Exporter OTLP","value":{"otlp":{"name":"tracesExporterOTLPGRPC","type":"tracesServer","label":"OTLP","fields":[{"key":"config.exporter.enabled","name":"TracesServer OTLP Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"TracesServer OTLP Exporter kind","value":"otlp","dataType":"string","required":true},{"key":"config.exporter.otlp.endpoint","name":"TracesServer OTLP Exporter Endpoint","dataType":"string","required":true},{"key":"config.exporter.otlp.type","name":"TracesServer OTLP Exporter Endpoint Type","dataType":"string","enum":["http","grpc"],"required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'TRACES_EXP_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update METRICS_EXP_PROM to remove not required fields for Prometheus configuration
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"MetricsServer Exporter Prometheus","name":"MetricsServer Exporter Prometheus","value":{"prometheus":{"name":"metricsExporterPrometheus","type":"metricsServer","label":"Prometheus","fields":[{"key":"config.exporter.enabled","name":"MetricsServer Exporter Enabled","value":true,"dataType":"boolean","required":true},{"key":"config.exporter.kind","name":"MetricsServer Prometheus Exporter kind","value":"prometheus","dataType":"string","required":true}],"allowMultipleInstances":false}},"dataType":"map","required":false,"configVersion":"1.3.0"}]}'
WHERE RESOURCE_ID = 'METRICS_EXP_PROM' AND RESOURCE_LEVEL = 'PLATFORM';

--
-- Restructure V3_VIEW_DATA_PLANE_MONITOR_DETAILS to have HAWKDOMAIN and BW6TEAAGENT Resource Instances
--

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS CASCADE;

CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_MONITOR_DETAILS
AS
SELECT
    VDP.SUBSCRIPTION_ID,
    json_agg(row_to_json((
        SELECT ColumnName
        FROM (SELECT VDP.DP_ID, VDP.REGISTERED_REGION, VDP.RUNNING_REGION, VDP.DP_CONFIG, VDP.STATUS, VDP.HOST_CLOUD_TYPE, VDP.NAMESPACES, DPCP.CAPABILITIES, VRI.RESOURCE_INSTANCES)
                 AS ColumnName (DP_ID, REGISTERED_REGION, RUNNING_REGION, DP_CONFIG, DP_STATUS, HOST_CLOUD_TYPE, NAMESPACES, CAPABILITIES, RESOURCE_INSTANCES)
    ))) DATAPLANES
FROM V3_DATA_PLANES VDP LEFT JOIN (SELECT DP_ID, json_agg(row_to_json((
    SELECT ColumnName
    FROM (
             SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CI.CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, CI.VERSION, STATUS, REGION, TAGS)
             AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, NAME, CAPABILITY_TYPE, CAPABILITY_INSTANCE_METADATA, NAMESPACE, VERSION, STATUS, REGION, TAGS)
))) CAPABILITIES
                                   FROM (V3_CAPABILITY_INSTANCES CI LEFT JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID,CAPABILITY_TYPE))
                                   GROUP BY DP_ID) DPCP ON VDP.DP_ID = DPCP.DP_ID LEFT JOIN  (SELECT SCOPE_ID, json_agg(row_to_json((SELECT ColumnName
                                                                                                                          FROM (SELECT RESOURCE_ID, RESOURCE_INSTANCE_METADATA)
                                                                                                                              AS ColumnName (RESOURCE_ID, RESOURCE_INSTANCE_METADATA)
                                                                                                                        ))) AS RESOURCE_INSTANCES FROM V3_RESOURCE_INSTANCES
                                                                                  WHERE  SCOPE = 'DATAPLANE' AND (RESOURCE_ID = 'HAWKDOMAIN' OR RESOURCE_ID = 'BW6TEAAGENT')
                                                                                  GROUP BY SCOPE_ID) VRI ON VDP.DP_ID = VRI.SCOPE_ID
GROUP BY VDP.SUBSCRIPTION_ID
    WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_DATA_PLANE_MONITOR_DETAILS_INDEX ON V3_VIEW_DATA_PLANE_MONITOR_DETAILS (SUBSCRIPTION_ID);

-- Add host_cloud_type 'control-tower' for resource LOGS_EXP_UA_OTLP
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_EXP_UA_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource  LOGS_EXP_UA_ES
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_EXP_UA_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource LOGS_EXP_UA_KAFKA
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_EXP_UA_KAFKA' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource LOGS_EXP_SRV_ES
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_EXP_SRV_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource LOGS_EXP_SRV_KAFKA
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_EXP_SRV_KAFKA' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource LOGS_EXP_SRV_OTLP
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_EXP_SRV_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource LOGS_PRX_UA_OS
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_PRX_UA_OS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource LOGS_PRX_UA_ES
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'LOGS_PRX_UA_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource METRICS_EXP_KAFKA
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'METRICS_EXP_KAFKA' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource METRICS_PRX_PROM
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'METRICS_PRX_PROM' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource METRICS_EXP_OTLP
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'METRICS_EXP_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource METRICS_EXP_PROM
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'METRICS_EXP_PROM' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource TRACES_EXP_KAFKA
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'TRACES_EXP_KAFKA' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource TRACES_EXP_ES
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'TRACES_EXP_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource TRACES_EXP_OTLP
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'TRACES_EXP_OTLP' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource TRACES_PRX_ES
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'TRACES_PRX_ES' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource TRACES_PRX_OS
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'TRACES_PRX_OS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add host_cloud_type 'control-tower' for resource O11YV3
UPDATE V3_RESOURCES SET HOST_CLOUD_TYPE = '{"aws","azure","control-tower"}' WHERE RESOURCE_ID = 'O11YV3' AND RESOURCE_LEVEL = 'PLATFORM';

--
-- Restructure V3_VIEW_DATA_PLANE_MONITOR_DETAILS to have dataplane's name in the response
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
                                                                                              WHERE  SCOPE = 'DATAPLANE' AND (RESOURCE_ID = 'HAWKDOMAIN' OR RESOURCE_ID = 'BW6TEAAGENT' OR RESOURCE_ID='BETEAAGENT')
                                                                                              GROUP BY SCOPE_ID) VRI ON VDP.DP_ID = VRI.SCOPE_ID
GROUP BY VDP.SUBSCRIPTION_ID
    WITH DATA;
CREATE UNIQUE INDEX V3_VIEW_DATA_PLANE_MONITOR_DETAILS_INDEX ON V3_VIEW_DATA_PLANE_MONITOR_DETAILS (SUBSCRIPTION_ID);

-- PCP-6763: Update BWDI to DI as a PLATFORM Capability
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'BWDI' AND CAPABILITY_TYPE = 'PLATFORM';

INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('DI','TIBCO Data Integration','TIBCO Data Integration (powered by Apache Beam and Apache Flink) integrates multiple data sources enabling use cases focused around cleansing and restructuring to provide a unified dataset that facilitates Data Replication, Analytics and beyond.','PLATFORM')
ON CONFLICT DO NOTHING;


-- PCP-6478: Add a new container_registry_credential column to v3_data_planes table
ALTER TABLE V3_DATA_PLANES ADD COLUMN IF NOT EXISTS CONTAINER_REGISTRY_CREDENTIAL jsonb;

-- PCP-6434: Update INGRESS resource metadata to have traefik in 'ingressController' field's valid values UI dropdown hint/enum
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"ingressController","enum":["nginx","kong","traefik"],"name":"Ingress Controller","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"ingressClassName","name":"Ingress Class Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"fqdn","name":"FQDN","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"}]}'
WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';

-- PCP-6017: Add BWADAPTER as a INFRA Capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('BWADAPTER', 'BW Adapter', 'BW Adapter', 'INFRA')
ON CONFLICT DO NOTHING;

-- PCP-6541: Update INGRESS resource metadata to support annotations
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"ingressController","enum":["nginx","kong","traefik"],"name":"Ingress Controller","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"ingressClassName","name":"Ingress Class Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"fqdn","name":"FQDN","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"annotations","name":"Annotations","dataType":"array","required":false,"maxLength":"255"}]}'
WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Correct Database Username field name from Database User to Database Username
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"dbms","enum":["rdbms"],"name":"Database Management System","rdbms":{"key":"persistenceType","enum":[{"key":"postgres","name":"PostgreSQL"},{"key":"mysql","name":"MySQL"}],"name":"Database Type","mysql":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"}],"dataType":"string","postgres":[{"key":"dbUser","name":"Database Username","order":4,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"secretDbPassword","name":"Database Password","order":5,"regex":"","dataType":"string","required":true,"fieldType":"password","maxLength":"255"},{"key":"dbHost","name":"Database Host","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbPort","name":"Database Port","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"dbName","name":"Database Name","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"}],"required":true,"fieldType":"dropdown"},"dataType":"string","required":true,"fieldType":"dropdown"}]}'
WHERE RESOURCE_ID = 'DBCONFIG' AND RESOURCE_LEVEL = 'PLATFORM';
