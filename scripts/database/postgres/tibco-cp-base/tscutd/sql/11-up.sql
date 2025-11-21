-- Database schema changes for 1.8.0

-- PCP-11796 [CP Backend] Enhance mat view v3_view_apps_on_subscriptions to include more columns
-- Re create V3_VIEW_APPS_ON_SUBSCRIPTIONS view as we have to alter the schema of this.
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
    APPS.APP_LINKS,
    APPS.EULA as app_eula,
    APPS.RESOURCE_INSTANCE_IDS as app_resource_instance_ids,
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
-- Database schema changes for 1.8

-- PCP-11932: Update label FQDN to Default FQDN
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"ingressController","enum":["nginx","kong","traefik","openshiftRouter"],"name":"Ingress Controller","dataType":"string","required":true,"fieldType":"dropdown"},{"key":"ingressClassName","name":"Ingress Class Name","regex":"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$","dataType":"string","required":true,"maxLength":"63"},{"key":"fqdn","name":"Default FQDN","regex":"^[a-z0-9]([-a-z0-9][a-z0-9])?(\\.[a-z0-9]([-a-z0-9][a-z0-9])?)*$","dataType":"string","required":true,"maxLength":"255"},{"key":"annotations","name":"Annotations","dataType":"array","required":false,"maxLength":"255"}]}'
WHERE RESOURCE_ID = 'INGRESS' AND RESOURCE_LEVEL = 'PLATFORM';

-- Update HELMREPO Platform Capability resources to include certificateSecretName
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"default":false,"readOnly":false,"fields":[{"key":"alias","name":"Repository alias","order":1,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255","value":"test-repo-100"},{"key":"url","name":"Registry URL","order":2,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"repo","name":"Repository","order":3,"regex":"","dataType":"string","required":true,"fieldType":"text","maxLength":"255"},{"key":"username","name":"Username","order":4,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"},{"key":"password","name":"Password","order":5,"regex":"","dataType":"string","required":false,"fieldType":"password","maxLength":"255"},{"key":"pullLatestCharts","name":"Provision latest patch version","order":6,"regex":"","dataType":"bool","required":true,"fieldType":"text","maxLength":"255"},{"key":"certificateSecretName","name":"Custom Certificate Secret Name","order":7,"regex":"","dataType":"string","required":false,"fieldType":"text","maxLength":"255"}]}'
WHERE RESOURCE_ID = 'HELMREPO' AND RESOURCE_LEVEL = 'PLATFORM';

--PCP-12282: Remove IC resource instances linked to apps from capability instances
UPDATE V3_CAPABILITY_INSTANCES AS ci
SET resource_instance_ids = (
    SELECT ARRAY(
               SELECT elem
        FROM unnest(ci.resource_instance_ids) WITH ORDINALITY AS t(elem, ord)
        WHERE
            -- KEEP if elem is the first INGRESS
            elem = (
                SELECT ri.resource_instance_id
                FROM V3_RESOURCE_INSTANCES ri
                WHERE ri.resource_id = 'INGRESS'
                  AND ri.resource_instance_id = ANY(ci.resource_instance_ids)
                ORDER BY array_position(ci.resource_instance_ids, ri.resource_instance_id)
                LIMIT 1
            )
            OR
            -- KEEP if NOT in any app linked to same capability
            elem NOT IN (
                SELECT unnest(a.resource_instance_ids)
                FROM v3_apps a
                WHERE a.capability_instance_id = ci.capability_instance_id
            )
    )
)
WHERE ci.capability_id IN ('BWCE', 'FLOGO', 'TIBCOHUB')
  AND EXISTS (
    SELECT 1
    FROM v3_apps a
    WHERE a.capability_instance_id = ci.capability_instance_id
      AND ci.resource_instance_ids && a.resource_instance_ids
);

-- PCP-12342 [CP Backend] Support resource_instance_metadata field filter for UTM call to get RV specific resource instances
DROP FUNCTION IF EXISTS FIELD_EQUALS(TEXT,JSONB,TEXT,TEXT) CASCADE;
CREATE OR REPLACE FUNCTION FIELD_EQUALS(
  resource_id TEXT,
  json_field JSONB,
  target_key TEXT,
  target_value TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  CASE resource_id
    WHEN 'MSGSERVER' THEN
      RETURN EXISTS (
        SELECT 1
        FROM jsonb_array_elements(json_field->'fields') AS field
        WHERE field->>target_key = target_value
      );
    ELSE
      RETURN EXISTS (
        SELECT 1
        FROM jsonb_array_elements(json_field->'fields') AS field
        WHERE field->>'key' = target_key
          AND field->>'value' = target_value
      );
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- Update database schema at the end (earlier version is 1.7.0 i.e. 10)
UPDATE schema_version SET version = 11;
