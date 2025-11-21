-- Database schema changes for 1.10.0

-- PCP-13080 [Control Plane] Need a new UTM filer function for filtering resource instances by one filed attribute with field value
DROP FUNCTION IF EXISTS FIELD_EQUALS_2(JSONB,TEXT,TEXT,TEXT) CASCADE;
CREATE OR REPLACE FUNCTION FIELD_EQUALS_2(
  json_data JSONB,
  attr_key TEXT,
  attr_value TEXT,
  field_value TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  IF json_data IS NULL
     OR jsonb_typeof(json_data->'fields') IS DISTINCT FROM 'array' THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM jsonb_array_elements(json_data->'fields') AS field
    WHERE field->>attr_key = attr_value AND field->>'value' = field_value
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS FIELD_EQUALS(TEXT,JSONB,TEXT,TEXT) CASCADE;
CREATE OR REPLACE FUNCTION FIELD_EQUALS(
  resource_id TEXT,
  json_field JSONB,
  target_key TEXT,
  target_value TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  IF json_field IS NULL
     OR jsonb_typeof(json_field->'fields') IS DISTINCT FROM 'array' THEN
    RETURN FALSE;
  END IF;

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

-- PCP-11989 Add BW5CE capability ID in them DB
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('BW5CE','TIBCO BusinessWorks™ 5 Container Edition','TIBCO BusinessWorks 5 integration platform enables organizations to rapidly integrate systems and automate processes across hybrid environments.','PLATFORM')
    ON CONFLICT DO NOTHING;

-- PCP-13406 [CP Backend] Update capability name in CP UTD DB
UPDATE V3_CAPABILITY_METADATA SET DISPLAY_NAME = 'TIBCO BusinessWorks™ 6 (Containers)' WHERE CAPABILITY_ID = 'BWCE' AND CAPABILITY_TYPE = 'PLATFORM';

UPDATE V3_CAPABILITY_METADATA SET DISPLAY_NAME = 'TIBCO BusinessWorks™ 5 (Containers)' WHERE CAPABILITY_ID = 'BW5CE' AND CAPABILITY_TYPE = 'PLATFORM';

--PCP-13514 Update BWCE capability metadata description
UPDATE V3_CAPABILITY_METADATA SET DESCRIPTION = 'TIBCO BusinessWorks 6 integrates enterprise apps and orchestrates web services across hybrid environments.' WHERE CAPABILITY_ID = 'BWCE' AND CAPABILITY_TYPE = 'PLATFORM';

-- Update database schema at the end (earlier version is 1.9.0 i.e. 12)
UPDATE schema_version SET version = 13;
