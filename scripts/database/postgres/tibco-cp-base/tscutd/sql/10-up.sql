-- Database schema changes for 1.7

-- PCP-10740 User Subscriptions Management: Add DB tables schema
INSERT INTO v3_resources (RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('EMAIL_RECEIVER', 'EMAIL RECEIVER Resource', 'EMAIL RECEIVER Resource', 'alerts_receiver', '{"fields": [ { "key": "enabled", "name": "Enabled", "value": true, "dataType": "boolean", "required": true }, { "key": "email", "name": "Email", "dataType": "array", "required": true }, { "key": "type", "name": "Type", "dataType": "string", "required": true } ] }', '{"k8s"}', 'PLATFORM')
    ON CONFLICT DO NOTHING;

INSERT INTO v3_resources (RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('ALERT_RULE', 'ALERT RULE Resource', 'ALERT RULE Resource', 'alerts_rule', '{"fields": [ { "key": "enabled", "name": "Enabled", "value": true, "dataType": "boolean", "required": true }, { "key": "timeIntervalForSituationToPersist", "name": "Time Interval For Situation To Persist", "value": true, "dataType": "string", "required": true }, { "key": "evaluationInterval", "name": "Evaluation Interval", "dataType": "string", "required": true }, { "key": "thresholdValue", "name": "Threshold Value", "dataType": "string", "required": true }, { "key": "severity", "name": "Severity", "dataType": "string", "required": true }, { "key": "summary", "name": "Summary", "dataType": "string", "required": false }, { "key": "capability", "name": "Capability", "dataType": "string", "required": true }, { "key": "ruleCategory", "name": "Rule Category", "dataType": "string", "required": true }, { "key": "operator", "name": "Operator", "dataType": "string", "required": true }, { "key": "dpId", "name": "Dataplane Id", "dataType": "string", "required": true }, { "key": "description", "name": "Description", "dataType": "string", "required": false }, { "key": "apps", "name": "App Ids", "dataType": "array", "required": false } ] }', '{"k8s"}', 'PLATFORM')
    ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS V3_ALERT_RULES_TO_APPS (
    rule_id VARCHAR(255) NOT NULL,
    app_id VARCHAR(255) NOT NULL,
    PRIMARY KEY (rule_id, app_id),
    CONSTRAINT ALERT_RULES_TO_APPS_FK0 FOREIGN KEY (rule_id) REFERENCES v3_resource_instances(resource_instance_id),
    CONSTRAINT ALERT_RULES_TO_APPS_FK1 FOREIGN KEY (app_id) REFERENCES v3_apps(app_id)
    );

CREATE TABLE IF NOT EXISTS V3_ALERT_RULES_TO_RECEIVERS (
    rule_id VARCHAR(255) NOT NULL,
    receiver_id VARCHAR(255) NOT NULL,
    PRIMARY KEY (rule_id, receiver_id),
    CONSTRAINT ALERT_RULES_TO_RECEIVERS_FK0 FOREIGN KEY (rule_id) REFERENCES v3_resource_instances(resource_instance_id),
    CONSTRAINT ALERT_RULES_TO_RECEIVERS_FK1 FOREIGN KEY (receiver_id) REFERENCES v3_resource_instances(resource_instance_id)
    );

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
    AR.RESOURCE_INSTANCE_METADATA, AR.SCOPE, AR.REGION, AR.SCOPE_ID,
    ER.RESOURCE_INSTANCE_ID, ER.RESOURCE_INSTANCE_NAME, ER.RESOURCE_INSTANCE_DESCRIPTION, ER.RESOURCE_INSTANCE_METADATA;

CREATE UNIQUE INDEX V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_INDEX
    ON V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER USING btree (RESOURCE_INSTANCE_ID, EMAIL_RECEIVER_ID);

DROP FUNCTION IF EXISTS V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH() CASCADE;
-- Step 1: Create the refresh function
CREATE FUNCTION V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Refresh the materialized view
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER;
    RETURN NULL;
END;
$$;

-- Step 2: Create triggers for V3_RESOURCE_INSTANCES
DROP TRIGGER IF EXISTS V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
                ON V3_RESOURCE_INSTANCES
                    FOR EACH STATEMENT
                    EXECUTE PROCEDURE V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH();

-- Step 3: Create triggers for V3_ALERT_RULES_TO_RECEIVERS
DROP TRIGGER IF EXISTS V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_ALERT_RULE_TO_RECEIVER_TRIGGER ON V3_ALERT_RULES_TO_RECEIVERS;
CREATE TRIGGER V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_ALERT_RULE_TO_RECEIVER_TRIGGER
    AFTER INSERT OR UPDATE OR DELETE
                    ON V3_ALERT_RULES_TO_RECEIVERS
                        FOR EACH STATEMENT
                        EXECUTE PROCEDURE V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH();

-- Step 3: Create triggers for V3_DATA_PLANES
DROP TRIGGER IF EXISTS V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_DATA_PLANES_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_DATA_PLANES_TRIGGER
    AFTER INSERT OR UPDATE OR DELETE
                    ON V3_DATA_PLANES
                        FOR EACH STATEMENT
                        EXECUTE PROCEDURE V3_VIEW_ALERT_RULE_WITH_EMAIL_RECEIVER_REFRESH();


-- Materialized view for list of email receiver with linked alert rule details
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE;
CREATE MATERIALIZED VIEW V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE
AS
SELECT
    ER.RESOURCE_INSTANCE_ID AS RESOURCE_INSTANCE_ID,
    ER.RESOURCE_ID AS RESOURCE_ID,
    ER.RESOURCE_INSTANCE_NAME AS RESOURCE_INSTANCE_NAME,
    ER.RESOURCE_INSTANCE_DESCRIPTION AS RESOURCE_INSTANCE_DESCRIPTION,
    ER.RESOURCE_INSTANCE_METADATA AS RESOURCE_INSTANCE_METADATA,
    ER.SCOPE AS SCOPE,
    ER.SCOPE_ID AS SUBSCRIPTION_ID,
    ER.REGION AS REGION,
    CASE
        WHEN COUNT(AR.RESOURCE_INSTANCE_ID) = 0 THEN NULL
        ELSE json_agg(
                json_build_object(
                        'alert_rule_id', AR.RESOURCE_INSTANCE_ID,
                        'alert_rule_name', AR.RESOURCE_INSTANCE_NAME,
                        'alert_rule_description', AR.RESOURCE_INSTANCE_DESCRIPTION,
                        'alert_rule_metadata', AR.RESOURCE_INSTANCE_METADATA,
                        'scope', AR.SCOPE,
                        'region', AR.REGION,
                        'subscription_id', AR.SCOPE_ID
                )
             )
        END AS ALERT_RULE_DETAILS
FROM
    V3_RESOURCE_INSTANCES ER
        LEFT JOIN
    V3_ALERT_RULES_TO_RECEIVERS ARR
    ON ER.RESOURCE_INSTANCE_ID = ARR.RECEIVER_ID
        LEFT JOIN
    V3_RESOURCE_INSTANCES AR
    ON ARR.RULE_ID = AR.RESOURCE_INSTANCE_ID
WHERE
    ER.RESOURCE_ID = 'EMAIL_RECEIVER'
GROUP BY
    ER.RESOURCE_INSTANCE_ID, ER.RESOURCE_INSTANCE_NAME, ER.RESOURCE_INSTANCE_DESCRIPTION,
    ER.RESOURCE_INSTANCE_METADATA, ER.SCOPE, ER.SCOPE_ID, ER.REGION;

CREATE UNIQUE INDEX V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_INDEX
    ON V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE USING btree (RESOURCE_INSTANCE_ID);

-- Step 1: Create the refresh function
DROP FUNCTION IF EXISTS V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
-- Refresh the materialized view
REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE;
RETURN NULL;
END;
$$;

-- Step 2: Create triggers for V3_RESOURCE_INSTANCES
DROP TRIGGER IF EXISTS V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT
                  EXECUTE PROCEDURE V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_REFRESH();

-- Step 3: Create triggers for V3_ALERT_RULES_TO_RECEIVERS
DROP TRIGGER IF EXISTS V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_ALERT_RULE_TO_RECEIVER_TRIGGER ON V3_ALERT_RULES_TO_RECEIVERS;
CREATE TRIGGER V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_ALERT_RULE_TO_RECEIVER_TRIGGER
    AFTER INSERT OR UPDATE OR DELETE
                    ON V3_ALERT_RULES_TO_RECEIVERS
                        FOR EACH STATEMENT
                        EXECUTE PROCEDURE V3_VIEW_EMAIL_RECEIVER_WITH_ALERT_RULE_REFRESH();

-- PCP-11402[CP Backend] API to get alert rules with support to sort/filter/pagination
CREATE OR REPLACE FUNCTION get_alert_metadata_value(metadata JSONB, key TEXT)
RETURNS TEXT LANGUAGE SQL IMMUTABLE AS $$
SELECT field->>'value'
FROM jsonb_array_elements(metadata->'fields') AS field
WHERE field->>'key' = key
LIMIT 1
$$;

UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"ingressController","enum":["nginx","kong","traefik","openshiftRouter"],"name":"Ingress Controller","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"ingressClassName","name":"Ingress Class Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"fqdn","name":"FQDN","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"annotations","name":"Annotations","dataType":"array","required":false,"maxLength":"255"}]}'
WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update database schema at the end (earlier version is 1.6.0 i.e. 8)
UPDATE schema_version SET version = 10;
