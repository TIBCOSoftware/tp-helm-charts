-- Database schema changes for 1.13.0

--
-- PCP-13562 [USM] Store license file blob against a subscriptionId
--

-- For setup constrain on V3_DATA_PLANE_LICENSE_ACTIVATIONS
ALTER TABLE V2_SUBSCRIPTIONS DROP CONSTRAINT IF EXISTS V2_SUBSCRIPTIONS_SUBSCRIPTION_ID_KEY CASCADE;
ALTER TABLE V2_SUBSCRIPTIONS ADD CONSTRAINT V2_SUBSCRIPTIONS_SUBSCRIPTION_ID_KEY UNIQUE (SUBSCRIPTION_ID);

-- Add LICENSEFILE as an internal capability to v3_capability_metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES ('LICENSEFILE', 'License File Loader', 'License File capability that enables each data plane to load its corresponding license file', 'INFRA')
    ON CONFLICT DO NOTHING;

--
-- Set up license table
--
-- Add table to track license usage for data planes
CREATE TABLE IF NOT EXISTS V3_DATA_PLANE_LICENSE_ACTIVATIONS (
                                                                 DP_ID VARCHAR(255) NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255) not NULL,
    LICENSE_TYPE VARCHAR(255) NOT null DEFAULT 'NONE',
    CREATED_BY VARCHAR(255),
    CREATED_DATE BIGINT,
    MODIFIED_DATE BIGINT,
    MODIFIED_BY VARCHAR(255),

    PRIMARY KEY (DP_ID),
    CONSTRAINT fk_dp FOREIGN KEY (DP_ID) REFERENCES V3_DATA_PLANES(DP_ID) ON DELETE cascade,
    CONSTRAINT fk_subscription FOREIGN KEY (SUBSCRIPTION_ID) REFERENCES V2_SUBSCRIPTIONS(SUBSCRIPTION_ID) ON DELETE CASCADE
    );
DROP TRIGGER IF EXISTS UPDATE_CREATED_DATE_OF_V3_DATA_PLANE_LICENSE_ACTIVATIONS ON V3_DATA_PLANE_LICENSE_ACTIVATIONS;
CREATE TRIGGER UPDATE_CREATED_DATE_OF_V3_DATA_PLANE_LICENSE_ACTIVATIONS BEFORE INSERT ON V3_DATA_PLANE_LICENSE_ACTIVATIONS FOR EACH ROW EXECUTE FUNCTION  INSERT_DATES();
DROP TRIGGER IF EXISTS UPDATE_MODIFIED_DATE_OF_V3_DATA_PLANE_LICENSE_ACTIVATIONS ON V3_DATA_PLANE_LICENSE_ACTIVATIONS;
CREATE TRIGGER UPDATE_MODIFIED_DATE_OF_V3_DATA_PLANE_LICENSE_ACTIVATIONS BEFORE UPDATE ON V3_DATA_PLANE_LICENSE_ACTIVATIONS FOR EACH ROW EXECUTE FUNCTION  UPDATE_DATE();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY_OF_V3_DATA_PLANE_LICENSE_ACTIVATIONS ON V3_DATA_PLANE_LICENSE_ACTIVATIONS;
CREATE TRIGGER SET_MODIFIED_BY_OF_V3_DATA_PLANE_LICENSE_ACTIVATIONS BEFORE INSERT OR UPDATE ON V3_DATA_PLANE_LICENSE_ACTIVATIONS FOR EACH ROW EXECUTE FUNCTION TRIGGER_SET_MODIFIER();

CREATE OR REPLACE FUNCTION notify_dp_license_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
payload TEXT;
  licenseChanged BOOLEAN := false;
BEGIN
  -- Detect license change
  IF TG_OP = 'UPDATE' AND OLD.license_type IS DISTINCT FROM NEW.license_type THEN
    licenseChanged := true;
END IF;

  -- Always true on INSERT (new license record)
  IF TG_OP = 'INSERT' THEN
    licenseChanged := true;
END IF;

  -- If nothing changed worth tracking
  IF TG_OP = 'UPDATE' AND NOT licenseChanged THEN
    RETURN NEW;
END IF;

  -- Build JSON payload
  payload := json_build_object(
    'msgId', nextval('utd_notification_msg_id_seq'),
    'event', 'dp_license_type_changed',
    'operation', TG_OP,
    'modifiedDate', COALESCE(NEW.modified_date, EXTRACT(EPOCH FROM now())::BIGINT),
    'modifiedBy', NEW.modified_by,
    'data', json_build_object(
      'dpId', NEW.dp_id,
      'subscriptionId', NEW.subscription_id,
      'oldLicenseType', COALESCE(OLD.license_type,'NONE'),
      'newLicenseType', COALESCE(NEW.license_type,'NONE')
    )
  )::text;

  -- Send async notification
  PERFORM pg_notify('utd_notification_channel', payload);

RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_dp_license_change ON V3_DATA_PLANE_LICENSE_ACTIVATIONS;

CREATE TRIGGER trg_notify_dp_license_change
    AFTER INSERT OR UPDATE or DELETE ON V3_DATA_PLANE_LICENSE_ACTIVATIONS
    FOR EACH ROW
    EXECUTE FUNCTION notify_dp_license_change();

-- Add table to store license
CREATE TABLE IF NOT EXISTS V3_LICENSES (
                                           SCOPE VARCHAR(16) NOT NULL,
    SCOPE_ID VARCHAR(255) not NULL,
    LICENSE_FILE JSONB NOT NULL,
    CREATED_BY VARCHAR(255),
    CREATED_DATE BIGINT,
    MODIFIED_DATE BIGINT,
    MODIFIED_BY VARCHAR(255),

    PRIMARY KEY (SCOPE, SCOPE_ID)
    );
DROP TRIGGER IF EXISTS UPDATE_CREATED_DATE_OF_V3_LICENSES ON V3_LICENSES;
CREATE TRIGGER UPDATE_CREATED_DATE_OF_V3_LICENSES BEFORE INSERT ON V3_LICENSES FOR EACH ROW EXECUTE FUNCTION  INSERT_DATES();
DROP TRIGGER IF EXISTS UPDATE_MODIFIED_DATE_OF_V3_LICENSES ON V3_LICENSES;
CREATE TRIGGER UPDATE_MODIFIED_DATE_OF_V3_LICENSES BEFORE UPDATE ON V3_LICENSES FOR EACH ROW EXECUTE FUNCTION  UPDATE_DATE();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY_OF_V3_LICENSES ON V3_LICENSES;
CREATE TRIGGER SET_MODIFIED_BY_OF_V3_LICENSES BEFORE INSERT OR UPDATE ON V3_LICENSES FOR EACH ROW EXECUTE FUNCTION TRIGGER_SET_MODIFIER();

-- Cleanup license table
CREATE OR REPLACE FUNCTION cleanup_dp_license()
RETURNS TRIGGER
LANGUAGE plpgsql AS
$$
BEGIN
    IF TG_TABLE_NAME = 'v2_subscriptions' THEN
DELETE FROM v3_licenses
WHERE scope = 'SUBSCRIPTION'
  AND scope_id = OLD.subscription_id;

DELETE FROM v3_data_plane_license_activations
WHERE subscription_id = OLD.subscription_id;

ELSIF TG_TABLE_NAME = 'v3_data_planes' THEN
DELETE FROM v3_licenses
WHERE scope = 'DATAPLANE'
  AND scope_id = OLD.dp_id;

DELETE FROM v3_data_plane_license_activations
WHERE dp_id = OLD.dp_id;
END IF;

RETURN OLD;
END;
$$;

-- ON V2_SUBSCRIPTIONS
DROP TRIGGER IF EXISTS CLEANUP_DP_LICENSE_SUB ON V2_SUBSCRIPTIONS;

CREATE TRIGGER CLEANUP_DP_LICENSE_SUB
    AFTER DELETE ON V2_SUBSCRIPTIONS
    FOR EACH ROW
    EXECUTE FUNCTION CLEANUP_DP_LICENSE();


-- ON V3_DATA_PLANES
DROP TRIGGER IF EXISTS CLEANUP_DP_LICENSE_DP ON V3_DATA_PLANES;

CREATE TRIGGER CLEANUP_DP_LICENSE_DP
    AFTER DELETE ON V3_DATA_PLANES
    FOR EACH ROW
    EXECUTE FUNCTION CLEANUP_DP_LICENSE();

--
-- Set up notification jobs table
--
-- Table to store the id of processed notification jobs
CREATE TABLE IF NOT EXISTS v3_notification_jobs (
                                                    job_id       BIGINT       NOT NULL,
                                                    region       VARCHAR(255) NOT NULL,
    channel_id   TEXT         NOT NULL,
    event        VARCHAR(255) NOT NULL,
    operation    VARCHAR(16)  NOT NULL,
    processed_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (region, job_id)
    );
delete from v3_notification_jobs;

CREATE OR REPLACE FUNCTION purge_v3_notification_jobs_rows()
RETURNS TRIGGER AS $$
DECLARE
keep_limit CONSTANT BIGINT := 1000;
BEGIN
    -- Use the inserted row's job_id directly
DELETE FROM v3_notification_jobs
WHERE job_id < NEW.job_id - keep_limit;

RETURN NEW;  -- Pass the inserted row onward
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS v3_notification_jobs_purge_trigger ON v3_notification_jobs;
CREATE TRIGGER v3_notification_jobs_purge_trigger
    AFTER INSERT ON v3_notification_jobs
    FOR EACH ROW
    EXECUTE FUNCTION purge_v3_notification_jobs_rows();
-- Unique job_id
CREATE SEQUENCE IF NOT EXISTS utd_notification_msg_id_seq START WITH 1 INCREMENT BY 1;

--
-- Set up notification channel for license change
--
-- Function that sends a JSON payload when license_file changes
CREATE OR REPLACE FUNCTION notify_subscription_license_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
payload TEXT;
BEGIN

  -- On UPDATE, only notify if license file actually changed
  IF TG_OP = 'UPDATE' AND OLD.license_file IS NOT DISTINCT FROM NEW.license_file THEN
    RETURN NEW;
END IF;

  payload := json_build_object(
    'msgId', nextval('utd_notification_msg_id_seq'), -- reuse your sequence
    'event', 'subscription_license_changed',
    'operation', TG_OP,
    'modifiedDate', COALESCE(NEW.modified_date, OLD.modified_date),
    'modifiedBy', COALESCE(NEW.modified_by, OLD.modified_by),
    'data', json_build_object(
      'scope', COALESCE(NEW.scope, OLD.scope),
      'scopeId', COALESCE(NEW.scope_id, OLD.scope_id)
    )
  )::text;

  PERFORM pg_notify('utd_notification_channel', payload);
RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS notify_subscription_license_change
ON V3_LICENSES;

CREATE TRIGGER notify_subscription_license_change
    AFTER INSERT OR DELETE OR UPDATE OF license_file
ON V3_LICENSES
FOR EACH ROW
EXECUTE FUNCTION notify_subscription_license_change();


--
-- Set up notification channel for dp namespace change
--
-- Function that sends a JSON payload when namespaces changes
CREATE OR REPLACE FUNCTION notify_dp_namespaces_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
payload text;
BEGIN
  -- On UPDATE, only notify if namespaces actually changed
  IF TG_OP = 'UPDATE' AND OLD.namespaces IS NOT DISTINCT FROM NEW.namespaces THEN
    RETURN NEW;
END IF;

  payload := json_build_object(
      'msgId', nextval('utd_notification_msg_id_seq'),
      'event', 'dp_namespaces_changed',
      'operation', TG_OP,  -- INSERT | UPDATE | DELETE
      'modifiedDate', COALESCE(NEW.modified_date, OLD.modified_date),
      'modifiedBy', COALESCE(NEW.modified_by, OLD.modified_by),
      'data', json_build_object(
        'dpId', COALESCE(NEW.dp_id, OLD.dp_id),
        'subscriptionId', COALESCE(NEW.subscription_id, OLD.subscription_id),
        'region', COALESCE(NEW.registered_region, OLD.registered_region),
        'oldNamespaces', COALESCE(OLD.namespaces, ARRAY[]::text[]),
        'newNamespaces', COALESCE(NEW.namespaces, ARRAY[]::text[])
      )
    )::text;

  PERFORM pg_notify('utd_notification_channel', payload);

  -- Return correct row type
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
ELSE
    RETURN NEW;
END IF;
END;
$$;

DROP TRIGGER IF EXISTS notify_dp_namespaces_change ON v3_data_planes;

CREATE TRIGGER notify_dp_namespaces_change
    AFTER INSERT OR UPDATE OR DELETE
                    ON v3_data_planes
                        FOR EACH ROW
                        EXECUTE FUNCTION notify_dp_namespaces_change();


-- Update database schema at the end (earlier version is 1.12.0 i.e. 15)
UPDATE schema_version SET version = 16;