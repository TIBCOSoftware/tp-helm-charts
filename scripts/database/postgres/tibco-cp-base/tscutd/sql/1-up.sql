
-------------------------------------------------------------------------------
-- Database (tscutdb, tscutdb_audit) schema for cp 1.0.0 - based on tsc 2.51.0
-------------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS tscutdb_audit;

-- Returns OBJECT_TYPE for specified TABLE_NAME in parameters
DROP FUNCTION IF EXISTS GET_OBJECT_TYPE(TABLE_NAME TEXT) CASCADE;
CREATE FUNCTION GET_OBJECT_TYPE(TABLE_NAME TEXT)
    RETURNS TEXT
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    OBJ_TYPE VARCHAR(100);
BEGIN
    IF (TABLE_NAME = 'v2_account_user_roles') THEN OBJ_TYPE='Account user Roles: User Entity Id';
    ELSEIF(TABLE_NAME='v2_accounts') THEN OBJ_TYPE='Accounts: Tsc Account Id';
    ELSEIF(TABLE_NAME='v2_eula_status') THEN OBJ_TYPE='EULA Status: User Entity Id';
    ELSEIF(TABLE_NAME='v2_external_accounts') THEN OBJ_TYPE='External Accounts: Tsc Account Id';
    ELSEIF(TABLE_NAME='v2_subscriptions') THEN OBJ_TYPE='Subscriptions: Subscription Id';
    ELSEIF(TABLE_NAME='v2_tenant_users_roles') THEN OBJ_TYPE='Tenant User Roles: User Entity Id';
    ELSEIF(TABLE_NAME='v2_users') THEN OBJ_TYPE='Users: User Entity Id';
    ELSEIF(TABLE_NAME='v2_secret_hash') THEN OBJ_TYPE='Secret Hash: Subscription Id';
    ELSEIF(TABLE_NAME='v3_data_planes') THEN OBJ_TYPE='Dataplanes: Dp Id';
    ELSEIF(TABLE_NAME='v3_capability_instances') THEN OBJ_TYPE='Capability Instances: Capability Instance Id';
    ELSEIF(TABLE_NAME='v3_apps') THEN OBJ_TYPE='Apps: App Id';
    ELSEIF(TABLE_NAME='v3_resource_instances') THEN OBJ_TYPE='Resounces Instances: Resource Instance Id';
    ELSEIF(TABLE_NAME='v3_resources') THEN OBJ_TYPE='Resources: Resource Id';
    END IF;
    RETURN OBJ_TYPE;
END
$FUNCTION$;

-- returns OBJECT_ID for specified TABLE_NAME from ENTRY specified in parameters
DROP FUNCTION IF EXISTS TSCUTDB_AUDIT.GET_OBJECT_ID(TABLE_NAME TEXT,  ENTRY RECORD) CASCADE;
CREATE FUNCTION TSCUTDB_AUDIT.GET_OBJECT_ID(TABLE_NAME TEXT, ENTRY RECORD)
    RETURNS TEXT
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    OBJ_ID VARCHAR(50);
BEGIN
    IF (TABLE_NAME = 'v2_account_user_roles') THEN OBJ_ID=ENTRY.user_entity_id;
    ELSEIF(TABLE_NAME='v2_accounts') THEN OBJ_ID=ENTRY.tsc_account_id;
    ELSEIF(TABLE_NAME='v2_eula_status') THEN OBJ_ID=ENTRY.user_entity_id;
    ELSEIF(TABLE_NAME='v2_external_accounts') THEN OBJ_ID=ENTRY.tsc_account_id;
    ELSEIF(TABLE_NAME='v2_subscriptions') THEN OBJ_ID=ENTRY.subscription_id;
    ELSEIF(TABLE_NAME='v2_tenant_users_roles') THEN OBJ_ID=ENTRY.user_entity_id;
    ELSEIF(TABLE_NAME='v2_users') THEN OBJ_ID=ENTRY.user_entity_id;
    ELSEIF(TABLE_NAME='v2_secret_hash') THEN OBJ_ID=ENTRY.subscription_id;
    ELSEIF(TABLE_NAME='v3_data_planes') THEN OBJ_ID=ENTRY.dp_id;
    ELSEIF(TABLE_NAME='v3_capability_instances') THEN OBJ_ID=ENTRY.capability_instance_id;
    ELSEIF(TABLE_NAME='v3_apps') THEN OBJ_ID=ENTRY.app_id;
    ELSEIF(TABLE_NAME='v3_resource_instances') THEN OBJ_ID=ENTRY.resource_instance_id;
    ELSEIF(TABLE_NAME='v3_resources') THEN OBJ_ID=ENTRY.resource_id;
    END IF;
    RETURN OBJ_ID;
END
$FUNCTION$;

-- TRIGGER FUNCTION TSCUTDB_AUDIT.V3_EVENTS_UPDATE_TIME()
DROP FUNCTION IF EXISTS TSCUTDB_AUDIT.V3_EVENTS_UPDATE_TIME() CASCADE;
CREATE FUNCTION TSCUTDB_AUDIT.V3_EVENTS_UPDATE_TIME()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $FUNCTION$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        NEW.CREATED_TIME = TIMEZONE('UTC', NOW());
        NEW.MODIFIED_TIME = TIMEZONE('UTC', NOW());
    ELSEIF (TG_OP = 'UPDATE') THEN
        NEW.MODIFIED_TIME = TIMEZONE('UTC', NOW());
    END IF;
    RETURN NEW;
END;
$FUNCTION$;

-- TRIGGER FUNCTION TSCUTDB_AUDIT.V3_EVENTS() FOR AUDIT TRAILING
DROP FUNCTION IF EXISTS  TSCUTDB_AUDIT.V3_EVENTS_AUDIT() CASCADE;
CREATE FUNCTION TSCUTDB_AUDIT.V3_EVENTS_AUDIT()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    SUB_ID	VARCHAR(255);
    UID	VARCHAR(255);
    DESCR VARCHAR(255);
    OBJ_ID VARCHAR(50);
    OBJ_TYPE VARCHAR(100);
    UPDATED_DATA	JSONB;
    EXISTING_DATA	JSONB;
BEGIN
    UID := (select coalesce(current_setting('cp.userId', true), 'platform-default'));
    SUB_ID := (select coalesce(current_setting('cp.subscriptionId', true), 'platform-internal-subscription'));
    OBJ_TYPE := GET_OBJECT_TYPE(TG_TABLE_NAME);
    -- CREATE
    IF (TG_OP = 'INSERT') then
        OBJ_ID := TSCUTDB_AUDIT.GET_OBJECT_ID(TG_TABLE_NAME, NEW.*);
        DESCR := (SELECT concat('CREATE'));
        UPDATED_DATA = to_jsonb(NEW.*)::JSONB;
        INSERT INTO tscutdb_audit.V3_EVENTS(SUBSCRIPTION_ID, USER_ENTITY_ID, DESCRIPTION, OBJECT_ID, OBJECT_TYPE, NEW_DATA)
        VALUES (SUB_ID, UID, DESCR, OBJ_ID, OBJ_TYPE, UPDATED_DATA);
        -- UPDATE
    ELSEIF (TG_OP = 'UPDATE') then
        OBJ_ID := TSCUTDB_AUDIT.GET_OBJECT_ID(TG_TABLE_NAME, OLD.*);
        DESCR := (SELECT concat('UPDATE'));
        EXISTING_DATA = to_jsonb(OLD.*)::JSONB;
        UPDATED_DATA = to_jsonb(NEW.*)::JSONB;
        IF EXISTS(
            SELECT 1
            FROM jsonb_each(to_jsonb(OLD)) AS pre,
                 jsonb_each(to_jsonb(NEW)) AS post
            WHERE pre.key = post.key
              AND pre.value IS DISTINCT FROM post.value
        ) THEN
            INSERT INTO tscutdb_audit.V3_EVENTS(SUBSCRIPTION_ID, USER_ENTITY_ID, DESCRIPTION, OBJECT_ID, OBJECT_TYPE, NEW_DATA, OLD_DATA)
            VALUES (SUB_ID, UID, DESCR,  OBJ_ID, OBJ_TYPE, UPDATED_DATA, EXISTING_DATA);        END IF;
        -- DELETE
    ELSEIF (TG_OP = 'DELETE') THEN
        OBJ_ID := TSCUTDB_AUDIT.GET_OBJECT_ID(TG_TABLE_NAME, OLD.*);
        DESCR := (SELECT concat('DELETE'));
        EXISTING_DATA = to_jsonb(OLD.*)::JSONB;

        INSERT INTO tscutdb_audit.V3_EVENTS(SUBSCRIPTION_ID, USER_ENTITY_ID, DESCRIPTION, OBJECT_ID, OBJECT_TYPE, NEW_DATA)
        VALUES (SUB_ID, UID, DESCR, OBJ_ID, OBJ_TYPE, UPDATED_DATA);
    END IF;
    RETURN NULL;
end
$FUNCTION$;


-- Create table TSCUTDB_AUDIT.V3_EVENTS for audit trailing
CREATE TABLE IF NOT EXISTS TSCUTDB_AUDIT.V3_EVENTS (
                                                       EVENT_ID BIGSERIAL NOT NULL PRIMARY KEY,
                                                       SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
                                                       CREATED_TIME TIMESTAMP WITHOUT TIME ZONE NOT NULL,
                                                       USER_ENTITY_ID VARCHAR(255) NOT NULL,
                                                       DESCRIPTION TEXT,
                                                       OBJECT_ID VARCHAR(50) NOT NULL,
                                                       OBJECT_TYPE VARCHAR(100) NOT NULL,
                                                       NEW_DATA JSONB,
                                                       OLD_DATA JSONB,
                                                       MODIFIED_TIME TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

DROP TRIGGER IF EXISTS V3_EVENTS_SET_MODIFIED_TIME ON tscutdb_audit.V3_EVENTS;
CREATE TRIGGER V3_EVENTS_SET_MODIFIED_TIME BEFORE INSERT ON tscutdb_audit.V3_EVENTS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_UPDATE_TIME();


--
-- 1. Name: tscutdb_audit.V2_EXTERNAL_LDAPS_AUDIT
--

CREATE TABLE IF NOT EXISTS tscutdb_audit.V2_EXTERNAL_LDAPS_AUDIT (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    DOMAIN_NAME VARCHAR(255) NOT NULL,
    TYPE VARCHAR(255) NOT NULL,
    REQUESTER VARCHAR(255) NOT NULL,
    ACTOR VARCHAR(255) NOT NULL,
    ACTION_TIME BIGINT NOT NULL,
    DB_OPERATION VARCHAR(20) NOT NULL,
    COMMENT VARCHAR(255),
    DOMAIN_VERIFICATION_METHOD VARCHAR(255),
    DOMAIN_VERIFICATION_CODE VARCHAR(255),
    LEGALLY_ACCEPTED_BY VARCHAR(255)
);

--
-- 2. Name: tscutdb_audit.V2_CINDEX_UTD_AUDIT
--

CREATE TABLE IF NOT EXISTS tscutdb_audit.V2_CINDEX_UTD_AUDIT (
    ID BIGSERIAL NOT NULL PRIMARY KEY,
    TABLE_NAME VARCHAR(50) NOT NULL,
    DATA JSONB NOT NULL,
    OLD_DATA JSONB,
    QUERY TEXT NOT NULL,
    OPERATION VARCHAR(20) NOT NULL,
    CREATED_AT TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    STATUS VARCHAR(20) DEFAULT 'created'::VARCHAR NOT NULL,
    LAST_MODIFIED_AT TIMESTAMP WITHOUT TIME ZONE
);

-------- Giving required privileges to tscscheduleruser needed for performing scheduler ops

-- \set scheduleruser 'tscscheduleruser'
-- \set scheduleruserwithprefix :DBPREFIX:scheduleruser
-- prevent tscscheduleruser from touching main tscutdb schema
-- REVOKE ALL ON SCHEMA :PGDATABASE FROM :scheduleruserwithprefix;
-- GRANT CONNECT ON DATABASE :PGDATABASE TO :scheduleruserwithprefix;

-- allow tscscheduleruser to use tscutdb_audit schema, but not create any objects
-- REVOKE CREATE ON SCHEMA TSCUTDB_AUDIT FROM :scheduleruserwithprefix;
-- GRANT USAGE ON SCHEMA TSCUTDB_AUDIT TO :scheduleruserwithprefix;

-- allow tscscheduleruser to read the row, and update only the status column in v2_utd_audit_cindex table
-- GRANT SELECT ON TABLE tscutdb_audit.V2_CINDEX_UTD_AUDIT TO :scheduleruserwithprefix;
-- GRANT UPDATE (STATUS) ON TABLE tscutdb_audit.V2_CINDEX_UTD_AUDIT TO :scheduleruserwithprefix;

--------------------------------------------------------------------------------------------------------

-- tscutdb_audit.V2_CINDEX_UTD_AUDIT_UPDATE_LAST_MODIFIED_TIMESTAMP()

DROP FUNCTION IF EXISTS tscutdb_audit.V2_CINDEX_UTD_AUDIT_UPDATE_LAST_MODIFIED_TIMESTAMP() CASCADE;
CREATE FUNCTION tscutdb_audit.V2_CINDEX_UTD_AUDIT_UPDATE_LAST_MODIFIED_TIMESTAMP()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        NEW.last_modified_at = timezone('utc', now());
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS UPDATE_LAST_MODIFIED_TIMESTAMP ON tscutdb_audit.V2_CINDEX_UTD_AUDIT;
CREATE TRIGGER UPDATE_LAST_MODIFIED_TIMESTAMP BEFORE UPDATE ON tscutdb_audit.V2_CINDEX_UTD_AUDIT FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_AUDIT_UPDATE_LAST_MODIFIED_TIMESTAMP();

-- CPS-1934: remove created_time, modified_time, created_by, modified_by, comment columns from the notification sent to pg_notify
-- for v2_external_accounts table events

DROP FUNCTION IF EXISTS tscutdb_audit.V2_CINDEX_UTD_AUDIT_NOTIFY_EVENT() CASCADE;
CREATE FUNCTION tscutdb_audit.V2_CINDEX_UTD_AUDIT_NOTIFY_EVENT()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
DECLARE
    data            JSON;
    id              TEXT;
    action          TEXT;
    objectName      TEXT;
    objectToSend    JSON;
    notification    JSON;
    columnsToRemove TEXT[];
    col             TEXT;
BEGIN
    data = to_json(NEW.data);
    -- CPS-1934: remove created_time, modified_time, created_by, modified_by, comment columns from the notification sent to pg_notify
    -- for v2_external_accounts table events
    IF (NEW.table_name = 'v2_external_accounts') THEN
        columnsToRemove = ARRAY ['created_time','modified_time','created_by','modified_by','comment'];
        FOREACH col IN ARRAY columnsToRemove
            LOOP
                data = data::jsonb - col;
            END LOOP;
    END IF;
    IF (NEW.operation = 'INSERT') THEN
        action = 'CREATE';
    ELSE
        action = NEW.operation;
    END IF;
    IF (NEW.table_name = 'v2_users' OR NEW.table_name = 'v2_account_user_details') THEN
        objectName = 'tsc_account_owners';
    ELSE
        objectName = concat('tsc', SUBSTRING(NEW.table_name, 3));
    END IF;

    objectToSend = json_build_object(objectName, data);
    notification =
            json_build_object('Data', objectToSend, 'id', NEW.id::TEXT, 'action', action, 'timestamp', NEW.created_at);

    -- CPS-1588: Notify only if the size is less than 8K, else the record will remain in 'created' state
    -- and will be picked up within 5 mins by the cp-cronjobs CIndexAuditDataNotiferJob periodically
    IF octet_length(notification::TEXT) < 8000 THEN
        -- Execute pg_notify(channel, notification)
        PERFORM pg_notify('v2_cindex_utd_audit_events', notification::TEXT);

        -- update the state to 'notified'
        UPDATE tscutdb_audit.v2_cindex_utd_audit SET status = 'notified' WHERE v2_cindex_utd_audit.id = NEW.id;
    END IF;

    -- Result is ignored since this is an AFTER trigger
    RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS V2_CINDEX_UTD_AUDIT_EVENT_NOTIFIER ON tscutdb_audit.V2_CINDEX_UTD_AUDIT;
CREATE TRIGGER V2_CINDEX_UTD_AUDIT_EVENT_NOTIFIER AFTER INSERT ON tscutdb_audit.V2_CINDEX_UTD_AUDIT FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V2_CINDEX_UTD_AUDIT_NOTIFY_EVENT();

--

DROP FUNCTION IF EXISTS tscutdb_audit.V2_CINDEX_UTD_USERS_AUDIT() CASCADE;
CREATE FUNCTION tscutdb_audit.V2_CINDEX_UTD_USERS_AUDIT()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $function$
DECLARE
    account_ids   JSONB;
    user_data     JSONB;
    old_user_data JSONB;
BEGIN
    IF (tg_op = 'UPDATE') THEN
        account_ids = (SELECT jsonb_agg(tsc_account_id)
                       FROM v2_account_user_details v2au
                       WHERE v2au.user_entity_id = NEW.user_entity_id
                         AND v2au.role_id = 'owner')::JSONB;
        IF (jsonb_array_length(account_ids) > 0) THEN
            user_data = jsonb_build_object('tsc_account_id', account_ids, 'role_id', 'owner', 'user_entity_id',
                                           NEW.user_entity_id, 'email', NEW.email, 'created_date', NEW.created_date,
                                           'modified_date', NEW.modified_date);
            old_user_data = jsonb_build_object('tsc_account_id', account_ids, 'role_id', 'owner', 'user_entity_id',
                                               OLD.user_entity_id, 'email', OLD.email, 'created_date', OLD.created_date,
                                               'modified_date', OLD.modified_date);
            INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, old_data, query, operation, created_at)
            VALUES (tg_table_name, user_data, old_user_data, current_query(), TG_OP, timezone('utc', now()));
        END IF;
    ELSEIF (tg_op = 'DELETE') THEN
        user_data = json_build_object('email', OLD.email, 'user_entity_id', OLD.user_entity_id, 'created_date',
                                      OLD.created_date, 'modified_date', OLD.modified_date);
        INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, query, operation, created_at)
        VALUES (tg_table_name, user_data, current_query(), TG_OP, timezone('utc', now()));
    END IF;
    RETURN NULL;
END;
$function$;

-- CPS-1934: remove created_time, modified_time, created_by, modified_by, comment columns from being
--  saved to tscutdb_audit.v2_cindex_utd_audit table for v2_external_accounts table events

DROP FUNCTION IF EXISTS tscutdb_audit.V2_CINDEX_UTD_AUDIT() CASCADE;
CREATE FUNCTION tscutdb_audit.V2_CINDEX_UTD_AUDIT()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
DECLARE
    columns_to_ignore TEXT[] := ARRAY ['seat_usage_modified_time',
        'grace_period_notification_time',
        'expiry_notification_time',
        'last_login_date'];
    NewDataColumnsRemoved   JSON;
    OldDataColumnsRemoved   JSON;
    columnsToRemove 	    TEXT[];
    col             	    TEXT;
BEGIN
    -- NEW holds new database row for INSERT/UPDATE and is null for DELETE
    IF (TG_OP = 'INSERT' or TG_OP = 'UPDATE') THEN
        NewDataColumnsRemoved = to_jsonb(NEW.*);
    END IF;
    -- OLD holds old database row for UPDATE/DELETE and is null for INSERT
    IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
        OldDataColumnsRemoved = to_jsonb(OLD.*);
    END IF;
    -- CPS-1934: remove created_time, modified_time, created_by, modified_by, comment columns from being
    -- saved to tscutdb_audit.v2_cindex_utd_audit table for v2_external_accounts table events
    IF (TG_TABLE_NAME = 'v2_external_accounts') THEN
        columnsToRemove = ARRAY ['created_time','modified_time','created_by','modified_by','comment'];
        FOREACH col IN ARRAY columnsToRemove
            LOOP
                IF (TG_OP = 'INSERT' or TG_OP = 'UPDATE') THEN
                    NewDataColumnsRemoved = NewDataColumnsRemoved::jsonb - col;
                END IF;
                IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
                    OldDataColumnsRemoved = OldDataColumnsRemoved::jsonb - col;
                END IF;
            END LOOP;
    END IF;
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, query, operation, created_at)
        VALUES (TG_TABLE_NAME, NewDataColumnsRemoved, current_query(), TG_OP, timezone('utc', now()));

        -- insert the updated row only if the data that has changed is not limited to columns_to_ignore
    ELSIF (TG_OP = 'UPDATE') THEN
        IF EXISTS(
                SELECT 1
                FROM jsonb_each(to_jsonb(OLD)) AS pre,
                     jsonb_each(to_jsonb(NEW)) AS post
                WHERE pre.key = post.key
                  AND pre.value IS DISTINCT FROM post.value
                  AND NOT (pre.key = ANY (columns_to_ignore))
            ) THEN
            INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, old_data, query, operation, created_at)
            VALUES (TG_TABLE_NAME, NewDataColumnsRemoved, to_jsonb(old.*), current_query(), TG_OP, timezone('utc', now()));
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, query, operation, created_at)
        VALUES (TG_TABLE_NAME, OldDataColumnsRemoved, current_query(), TG_OP, timezone('utc', now()));
    END IF;
    RETURN NULL; -- result is ignored since this is an AFTER trigger
END;
$function$;

-- tscutdb_audit.V2_CINDEX_UTD_ACCOUNT_USER_ROLES_AUDIT()

DROP FUNCTION IF EXISTS tscutdb_audit.V2_CINDEX_UTD_ACCOUNT_USER_ROLES_AUDIT() CASCADE;
CREATE FUNCTION tscutdb_audit.V2_CINDEX_UTD_ACCOUNT_USER_ROLES_AUDIT()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
DECLARE
    account_data      JSONB;
    user_data         JSONB;
    old_account_data  JSONB;
    columns_to_ignore TEXT[] := ARRAY ['last_login_date'];
BEGIN
    IF (TG_OP = 'INSERT') THEN
        account_data = json_build_object('tsc_account_id', jsonb_build_array(NEW.tsc_account_id), 'role_id',
                                         NEW.role_id::TEXT);
        --get user data and store this into a json object
        user_data = (SELECT row_to_json(rows)
                     FROM (SELECT email, user_entity_id, created_date, modified_date
                           FROM v2_users
                           WHERE user_entity_id = NEW.user_entity_id) AS rows)::JSONB;
        account_data = account_data || user_data;
        INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, query, operation, created_at)
        VALUES (tg_table_name, account_data, current_query(), TG_OP, timezone('utc', now()));
    ELSEIF (tg_op = 'UPDATE') THEN
        -- insert the updated row only if the data that has changed is not limited to columns_to_ignore
        IF EXISTS(
                SELECT 1
                FROM jsonb_each(to_jsonb(OLD)) AS pre,
                     jsonb_each(to_jsonb(NEW)) AS post
                WHERE pre.KEY = post.KEY
                  AND pre.value IS DISTINCT FROM post.value
                  AND NOT (pre.KEY = ANY (columns_to_ignore))
            ) THEN
            account_data = jsonb_build_object('tsc_account_id', jsonb_build_array(new.tsc_account_id), 'role_id',
                                              new.role_id::TEXT);
            old_account_data = jsonb_build_object('tsc_account_id', jsonb_build_array(old.tsc_account_id), 'role_id',
                                                  old.role_id::TEXT);
            --get user data and store this into a json object
            user_data = (SELECT row_to_json(rows)
                         FROM (SELECT email, user_entity_id, created_date, modified_date
                               FROM v2_users
                               WHERE user_entity_id = OLD.user_entity_id) AS rows)::JSONB;
            account_data = account_data || user_data;
            old_account_data = old_account_data || user_data;
            INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, old_data, query, operation, created_at)
            VALUES (tg_table_name, account_data, old_account_data, current_query(), TG_OP, timezone('utc', now()));
        END IF;
    ELSEIF (tg_op = 'DELETE') THEN
        account_data = jsonb_build_object('tsc_account_id', jsonb_build_array(old.tsc_account_id), 'role_id',
                                          OLD.role_id::TEXT);
        --get user data and store this into a json object
        user_data = (SELECT row_to_json(rows)
                     FROM (SELECT email, user_entity_id, created_date, modified_date
                           FROM v2_users
                           WHERE user_entity_id = OLD.user_entity_id) AS rows)::JSONB;
        account_data = account_data || user_data;
        INSERT INTO tscutdb_audit.v2_cindex_utd_audit(table_name, data, query, operation, created_at)
        VALUES (tg_table_name, account_data, current_query(), TG_OP, timezone('utc', now()));
    END IF;
    RETURN NULL;
END;
$function$;


-- ----------------------
--     tscutdb
-- ----------------------

--
-- 37. Name: V3_DATA_PLANES
--

CREATE TABLE IF NOT EXISTS V3_DATA_PLANES (
	DP_ID VARCHAR(255) NOT NULL PRIMARY KEY,
	NAME VARCHAR(255) NOT NULL,
	DESCRIPTION VARCHAR(255),
	HOST_CLOUD_TYPE VARCHAR(255) NOT NULL,
	STATUS VARCHAR(255) NOT NULL,
	REGISTERED_REGION VARCHAR(255),
    RUNNING_REGION VARCHAR(255),
    CREATED_DATE BIGINT,
	MODIFIED_DATE BIGINT,
	CREATED_BY VARCHAR(255),
	MODIFIED_BY VARCHAR(255),
	TAGS TEXT[],
	NAMESPACES TEXT[],
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    RESOURCE_INSTANCE_IDS TEXT[],
    DP_CONFIG JSONB,
    EULA BOOLEAN
    );

CREATE INDEX IF NOT EXISTS TAGS_INDEX ON V3_DATA_PLANES USING GIN (TAGS);

-- Insert created_date and modified_date on v3_data_planes by trigger

DROP FUNCTION IF EXISTS INSERT_DATES() CASCADE;
CREATE FUNCTION INSERT_DATES()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
BEGIN
    NEW.CREATED_DATE = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    NEW.MODIFIED_DATE = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    return NEW;
END;
$function$;

DROP TRIGGER IF EXISTS INSERT_DATES_OF_V3_DATA_PLANES ON V3_DATA_PLANES;
CREATE TRIGGER INSERT_DATES_OF_V3_DATA_PLANES BEFORE INSERT ON V3_DATA_PLANES FOR EACH ROW EXECUTE PROCEDURE INSERT_DATES();

-- Update modified_date on v3_data_planes by trigger

DROP FUNCTION IF EXISTS UPDATE_DATE() CASCADE;
CREATE FUNCTION UPDATE_DATE()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
BEGIN
    NEW.MODIFIED_DATE = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    return NEW;
END;
$function$;

DROP TRIGGER IF EXISTS UPDATE_MODIFIED_DATE_OF_V3_DATA_PLANES ON V3_DATA_PLANES;
CREATE TRIGGER UPDATE_MODIFIED_DATE_OF_V3_DATA_PLANES BEFORE UPDATE ON V3_DATA_PLANES FOR EACH ROW EXECUTE PROCEDURE UPDATE_DATE();

-- Refresh materialized view V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES

DROP FUNCTION IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH()
	RETURNS TRIGGER 
	LANGUAGE plpgsql 
	AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V3_DATA_PLANES 
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

-- Refresh materialized view V3_VIEW_ACCOUNT_ALLOWED_RESOURCE

DROP FUNCTION IF EXISTS V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_REFRESH()
	RETURNS TRIGGER 
	LANGUAGE plpgsql 
	AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_ACCOUNT_ALLOWED_RESOURCE;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_DP_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V3_DATA_PLANES 
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_REFRESH();

--
-- 3. Name: V2_ROLES
--

CREATE TABLE IF NOT EXISTS V2_ROLES (
    ROLE_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    DISPLAY_NAME VARCHAR(255),
    DESCRIPTION VARCHAR(255)
);

--
-- 4. Name: V2_STATUS
--

CREATE TABLE IF NOT EXISTS V2_STATUS (
    STATUS VARCHAR(255) NOT NULL PRIMARY KEY,
    DISPLAY_NAME VARCHAR(255),
    DESCRIPTION VARCHAR(255)
);

--
-- 5. Name: V2_ACCOUNTS
--

CREATE TABLE IF NOT EXISTS V2_ACCOUNTS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    DISPLAY_NAME VARCHAR(255),
    DESCRIPTION VARCHAR(255),
    ACCOUNT_SETTINGS JSONB DEFAULT '{"syncUser": false, "childLimit": 0, "ownerLimit": 20, "accountType": "REGULAR", "siblingLimit": 0, "syncSubscription": false}'::JSONB NOT NULL,
    CREATED_TIME BIGINT DEFAULT 0 NOT NULL,
    MODIFIED_TIME BIGINT DEFAULT 0 NOT NULL,
	TAGS TEXT[],
    HOST_PREFIX VARCHAR(16) UNIQUE NULL,
    PREFIX_ID VARCHAR(4) UNIQUE NULL
);

CREATE INDEX IF NOT EXISTS TAGS_INDEX ON V2_ACCOUNTS USING GIN (TAGS);


DROP TRIGGER IF EXISTS z_v2_cindex_audit_accounts ON V2_ACCOUNTS;
CREATE TRIGGER z_v2_cindex_audit_accounts AFTER INSERT OR DELETE OR UPDATE ON V2_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_AUDIT();

--
-- 3. Name: V2_USERS
--

CREATE TABLE IF NOT EXISTS V2_USERS (
    USER_ENTITY_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL,
    FIRSTNAME VARCHAR(255),
    LASTNAME VARCHAR(255),
    CREATED_DATE BIGINT,
    MODIFIED_DATE BIGINT,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    ACTIVATION_URL BYTEA
);
    
DROP TRIGGER IF EXISTS INSERT_DATES_OF_V2_USERS ON V2_USERS;
CREATE TRIGGER INSERT_DATES_OF_V2_USERS BEFORE INSERT ON V2_USERS FOR EACH ROW EXECUTE PROCEDURE INSERT_DATES();

DROP TRIGGER IF EXISTS UPDATE_MODIFIED_DATE_OF_V2_USERS ON V2_USERS;
CREATE TRIGGER UPDATE_MODIFIED_DATE_OF_V2_USERS BEFORE UPDATE ON V2_USERS FOR EACH ROW EXECUTE PROCEDURE UPDATE_DATE();

DROP TRIGGER IF EXISTS Z_V2_CINDEX_AUDIT_USERS_UPDATE_DELETE ON V2_USERS;
--CREATE TRIGGER Z_V2_CINDEX_AUDIT_USERS_UPDATE_DELETE AFTER DELETE OR UPDATE ON V2_USERS FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_USERS_AUDIT();

--
-- 8. Name: V2_ACCOUNT_USER_DETAILS
--

CREATE TABLE IF NOT EXISTS V2_ACCOUNT_USER_DETAILS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    USER_ENTITY_ID VARCHAR(255) NOT NULL,
    EXTERNAL_ID VARCHAR(255),
    ALLOW_TIBCO_AUTHENTICATION BOOLEAN,
    TIBCO_AUTHENTICATION_GROUP VARCHAR(255),
    USER_SETTINGS JSONB DEFAULT '{"theme": "dark"}'::JSONB NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    TIME_STAMP BIGINT,
    LAST_LOGIN_DATE BIGINT,

    PRIMARY KEY (TSC_ACCOUNT_ID, USER_ENTITY_ID),
    CONSTRAINT ACCOUNT_USER_ROLES_FK3 FOREIGN KEY (STATUS) REFERENCES V2_STATUS(STATUS),
    CONSTRAINT ACCOUNT_USER_ROLES_FK0 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    CONSTRAINT ACCOUNT_USER_ROLES_FK2 FOREIGN KEY (USER_ENTITY_ID) REFERENCES V2_USERS(USER_ENTITY_ID)
);

-- account user roles have separate triggers for insert,update and delete because we only intend to capture 'owner' related ops

DROP TRIGGER IF EXISTS Z_V2_CINDEX_ACCOUNT_USER_ROLES_DELETE ON V2_ACCOUNT_USER_DETAILS;
--CREATE TRIGGER Z_V2_CINDEX_ACCOUNT_USER_ROLES_DELETE AFTER DELETE ON V2_ACCOUNT_USER_DETAILS FOR EACH ROW WHEN (((OLD.ROLE_ID)::TEXT = 'owner'::TEXT)) EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_ACCOUNT_USER_ROLES_AUDIT();

DROP TRIGGER IF EXISTS Z_V2_CINDEX_ACCOUNT_USER_ROLES_INSERT ON V2_ACCOUNT_USER_DETAILS;
--CREATE TRIGGER Z_V2_CINDEX_ACCOUNT_USER_ROLES_INSERT AFTER INSERT ON V2_ACCOUNT_USER_DETAILS FOR EACH ROW WHEN (((NEW.ROLE_ID)::TEXT = 'owner'::TEXT)) EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_ACCOUNT_USER_ROLES_AUDIT();

DROP TRIGGER IF EXISTS Z_V2_CINDEX_ACCOUNT_USER_ROLES_UPDATE ON V2_ACCOUNT_USER_DETAILS;
--CREATE TRIGGER Z_V2_CINDEX_ACCOUNT_USER_ROLES_UPDATE AFTER UPDATE OF ROLE_ID, STATUS ON V2_ACCOUNT_USER_DETAILS FOR EACH ROW WHEN ((((OLD.ROLE_ID)::TEXT = 'owner'::TEXT) OR ((NEW.ROLE_ID)::TEXT = 'owner'::TEXT))) EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_ACCOUNT_USER_ROLES_AUDIT();

--
-- 9. Name: V2_ACCOUNTS_RESOURCES_QUOTA
--

CREATE TABLE IF NOT EXISTS V2_ACCOUNTS_RESOURCES_QUOTA (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255) NOT NULL,
    REGION VARCHAR(255),
    ID INTEGER NOT NULL,
    SOFT_LIMIT INTEGER NOT NULL,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255),

    CONSTRAINT V2_ACCOUNTS_RESOURCES_QUOTA_PK UNIQUE (TSC_ACCOUNT_ID, SUBSCRIPTION_ID, TENANT_ID, ID, REGION)
);

-- TRIGGER_SET_MODIFIED_TIME()

DROP FUNCTION IF EXISTS TRIGGER_SET_MODIFIED_TIME() CASCADE;
CREATE FUNCTION TRIGGER_SET_MODIFIED_TIME()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    NEW.MODIFIED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS UPDATE_MODIFIED_TIME_OF_V2_ACCOUNTS_RESOURCES_QUOTA ON V2_ACCOUNTS_RESOURCES_QUOTA;
CREATE TRIGGER UPDATE_MODIFIED_TIME_OF_V2_ACCOUNTS_RESOURCES_QUOTA BEFORE UPDATE ON V2_ACCOUNTS_RESOURCES_QUOTA FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

--
-- 10. Name: V2_ARCHIVED_INVITE_HISTORY
--

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_INVITE_HISTORY (
    INVITE_ID VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    RECEIVER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    SENDER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    REVOKED_TIME_STAMP BIGINT,
    PERMISSIONS JSONB NOT NULL,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP),

    CONSTRAINT V2_ARCHIVED_INVITE_HISTORY_PKEY1 PRIMARY KEY (INVITE_ID)
    );

--
-- 11. Name: V2_ARCHIVED_RAW_SUBSCRIPTIONS
--

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_RAW_SUBSCRIPTIONS (
    ID VARCHAR(255) NOT NULL,
    RAW_PAYLOAD JSON NOT NULL,
    EMAIL VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255),
    SUBSCRIPTION_ID VARCHAR(255),
    REGION VARCHAR(255),
    IAAS_VENDOR VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    LOGS TEXT,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    CATEGORY VARCHAR(255) NOT NULL,
    ACTIVATION_URL TEXT,
    START_DATE BIGINT,
    IT_NOTIFICATION_RESPONSE JSONB,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP),
    ORIGINAL_CATEGORY VARCHAR(255)
);

--
-- 12. Name: V2_ARCHIVED_RAW_USERS
--

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_RAW_USERS (
    ID VARCHAR(255) NOT NULL,
    EMAIL VARCHAR(255) NOT NULL,
    FIRSTNAME VARCHAR(255) NOT NULL,
    LASTNAME VARCHAR(255) NOT NULL,
    COMPANYNAME VARCHAR(255),
    STATE VARCHAR(255),
    COUNTRY VARCHAR(255),
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP)
);

--
-- 13. Name: V2_ARCHIVED_SUBSCRIPTION_REQUESTS
--

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_SUBSCRIPTION_REQUESTS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    REQUESTER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    REGION VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT NOT NULL,
    TSD_TICKET_URL TEXT,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP)
);

--
-- 14. Name: V2_ARCHIVED_SUBSCRIPTIONS
--

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_SUBSCRIPTIONS (
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    TENANT_PLAN_ID VARCHAR(255) NOT NULL,
    SEATS TEXT NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    BUY_TIME BIGINT,
    EXPIRY_TIME BIGINT,
    EXPIRY_NOTIFICATION_TIME BIGINT,
    GRACE_PERIOD_NOTIFICATION_TIME BIGINT,
    EXTERNAL_SUBSCRIPTION_ID VARCHAR(255),
    MODIFIED_TIME BIGINT NOT NULL,
    CAPABILITIES VARCHAR(999) NOT NULL,
    CREATED_BY VARCHAR(255) DEFAULT 'system'::VARCHAR NOT NULL,
    MODIFIED_BY VARCHAR(255) DEFAULT 'system'::VARCHAR NOT NULL,
    CREATED_FOR VARCHAR(255) DEFAULT 'system'::VARCHAR NOT NULL,
    MODIFIED_FOR VARCHAR(255) DEFAULT 'system'::VARCHAR NOT NULL,
    PARENT_SUBSCRIPTION_ID VARCHAR(255) DEFAULT NULL::VARCHAR,
    END_OF_CONTRACT_TIME BIGINT,
    COMMENT VARCHAR(255),
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP),
    SUBSCRIPTION_SOURCE VARCHAR(255),
    START_OF_CONTRACT_TIME BIGINT,
    RESOURCE_INSTANCE_IDS TEXT[],
    CONTAINER_REGISTRY_CREDENTIAL JSONB
    );

--
-- 15. Name: V2_TENANTS
--

CREATE TABLE IF NOT EXISTS V2_TENANTS (
    TENANT_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    DISPLAY_NAME VARCHAR(255) NOT NULL,
    DESCRIPTION VARCHAR(255),
    EULA_LINK VARCHAR(255) DEFAULT 'https://terms.tibco.com/posts/860956-end-user-license-agreement'::VARCHAR,
    EULA_TEXT VARCHAR(255) DEFAULT 'The TIBCO<sup>&reg;</sup> End User License Agreement and Privacy Policy have been updated. Please acknowledge your acceptance by checking the boxes below and clicking “ACCEPT” to continue.'::VARCHAR,
    SUPPORT_FORM_METADATA TEXT
);

DROP TRIGGER IF EXISTS Z_V2_CINDEX_AUDIT_TENANTS ON V2_TENANTS;
CREATE TRIGGER Z_V2_CINDEX_AUDIT_TENANTS AFTER INSERT OR DELETE OR UPDATE ON V2_TENANTS FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_AUDIT();

--
-- 16. Name: V2_EULA_STATUS
--

CREATE TABLE IF NOT EXISTS V2_EULA_STATUS (
    USER_ENTITY_ID VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255) NOT NULL,
    TIME_STAMP BIGINT NOT NULL,

    CONSTRAINT V2_EULA_STATUS_PKEY PRIMARY KEY (USER_ENTITY_ID, TENANT_ID),
    CONSTRAINT v2_eula_status_fk0 FOREIGN KEY (USER_ENTITY_ID) REFERENCES V2_USERS(USER_ENTITY_ID),
    CONSTRAINT V2_EULA_STATUS_FK1 FOREIGN KEY (TENANT_ID) REFERENCES V2_TENANTS(TENANT_ID)
);

--
-- 17. Name: V2_EXTERNAL_ACCOUNT_TYPES
--

CREATE TABLE IF NOT EXISTS V2_EXTERNAL_ACCOUNT_TYPES (
    EXTERNAL_ACCOUNT_TYPE VARCHAR(255) NOT NULL PRIMARY KEY,
    DISPLAY_NAME VARCHAR(255),
    DESCRIPTION VARCHAR(255)
);

--
-- 18. Name: V2_EXTERNAL_ACCOUNTS
--

CREATE TABLE IF NOT EXISTS V2_EXTERNAL_ACCOUNTS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    EXTERNAL_ACCOUNT_TYPE VARCHAR(255) NOT NULL,
    EXTERNAL_ACCOUNT_ID VARCHAR(255) NOT NULL,
    CREATED_TIME BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    COMMENT VARCHAR(255),

    PRIMARY KEY (TSC_ACCOUNT_ID, EXTERNAL_ACCOUNT_TYPE),
    CONSTRAINT EXTERNAL_ACCOUNTS_FK0 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    CONSTRAINT EXTERNAL_ACCOUNTS_FK1 FOREIGN KEY (EXTERNAL_ACCOUNT_TYPE) REFERENCES V2_EXTERNAL_ACCOUNT_TYPES(EXTERNAL_ACCOUNT_TYPE)
);

-- TRIGGER_SET_CREATED_TIME()

DROP FUNCTION IF EXISTS TRIGGER_SET_CREATED_TIME() CASCADE;
CREATE FUNCTION TRIGGER_SET_CREATED_TIME()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    NEW.CREATED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    NEW.MODIFIED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_EXTERNAL_ACCOUNTS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_EXTERNAL_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_EXTERNAL_ACCOUNTS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_EXTERNAL_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

DROP TRIGGER IF EXISTS Z_V2_CINDEX_AUDIT_EXTERNAL_ACCOUNTS ON V2_EXTERNAL_ACCOUNTS;
CREATE TRIGGER Z_V2_CINDEX_AUDIT_EXTERNAL_ACCOUNTS AFTER INSERT OR DELETE OR UPDATE ON V2_EXTERNAL_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_AUDIT();

--
-- 19. Name: V2_EXTERNAL_LDAPS
--

CREATE TABLE IF NOT EXISTS V2_EXTERNAL_LDAPS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    LAST_MODIFIED_TIME BIGINT NOT NULL,
    DOMAIN_NAME VARCHAR(255) NOT NULL,
    TYPE VARCHAR(5) NOT NULL,
    REQUESTER VARCHAR(255) NOT NULL,
    ACTOR VARCHAR(255),
    DB_OPERATION VARCHAR(20),
    COMMENT VARCHAR(255),
    DOMAIN_VERIFICATION_METHOD VARCHAR(255) DEFAULT 'MANUAL'::VARCHAR,
    DOMAIN_VERIFICATION_CODE VARCHAR(255),
    LEGALLY_ACCEPTED_BY VARCHAR(255),

    PRIMARY KEY (TSC_ACCOUNT_ID, REQUESTER, TYPE),
    CONSTRAINT EXTERNAL_LDAPS_FK0 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    CONSTRAINT V2_EXTERNAL_LDAPS_FK0 FOREIGN KEY (REQUESTER) REFERENCES V2_USERS(USER_ENTITY_ID),
    CONSTRAINT V2_EXTERNAL_LDAPS_FK1 FOREIGN KEY (LEGALLY_ACCEPTED_BY) REFERENCES V2_USERS(USER_ENTITY_ID)
);

CREATE INDEX IF NOT EXISTS V2_EXTERNAL_LDAPS_LOWER_IDX ON V2_EXTERNAL_LDAPS USING BTREE (LOWER((DOMAIN_NAME)::TEXT));

-- V2_EXTERNAL_LDAPS_AUDIT()

DROP FUNCTION IF EXISTS V2_EXTERNAL_LDAPS_AUDIT() CASCADE;
CREATE FUNCTION V2_EXTERNAL_LDAPS_AUDIT()
	RETURNS TRIGGER
    LANGUAGE plpgsql
	AS $function$
BEGIN
    if (tg_op = 'DELETE')then
        Insert into tscutdb_audit.v2_external_ldaps_audit(
          tsc_account_id, status, domain_name,
          type, requester, actor, action_time,
          db_operation, comment, domain_verification_method,
          domain_verification_code, legally_accepted_by
        )
        values
          (
            old.tsc_account_id, old.status, old.domain_name,
            old.type, old.requester, old.actor,
            old.last_modified_time, 'DELETE',
            old.comment, old.domain_verification_method,
            old.domain_verification_code, old.legally_accepted_by
          );
    else
        if (new.db_operation <>'SOFT_DELETE') then
            Insert into tscutdb_audit.v2_external_ldaps_audit(
              tsc_account_id, status, domain_name,
              type, requester, actor, action_time,
              db_operation, comment, domain_verification_method,
              domain_verification_code, legally_accepted_by
            )
            values
              (
                new.tsc_account_id, new.status, new.domain_name,
                new.type, new.requester, new.actor,
                new.last_modified_time, new.db_operation,
                new.comment, new.domain_verification_method,
                new.domain_verification_code, new.legally_accepted_by
              );
        end if;
    end if;

    return null;
END;
$function$;

DROP TRIGGER IF EXISTS AUDIT_TRIGGER_FOR_EXTERNAL_LDAP ON V2_EXTERNAL_LDAPS;
CREATE TRIGGER AUDIT_TRIGGER_FOR_EXTERNAL_LDAP AFTER INSERT OR DELETE OR UPDATE ON V2_EXTERNAL_LDAPS FOR EACH ROW EXECUTE PROCEDURE V2_EXTERNAL_LDAPS_AUDIT();

--
-- 20. Name: V2_GLOBAL_ACCOUNT_MIGRATION_DATA
--

CREATE TABLE IF NOT EXISTS V2_GLOBAL_ACCOUNT_MIGRATION_DATA (
    REGION VARCHAR(255) NOT NULL,
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    GLOBAL_TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,

    UNIQUE (REGION, TSC_ACCOUNT_ID, GLOBAL_TSC_ACCOUNT_ID)
);

--
-- 21. Name: V2_GLOBAL_SUBSCRIPTION_MIGRATION_DATA
--

CREATE TABLE IF NOT EXISTS V2_GLOBAL_SUBSCRIPTION_MIGRATION_DATA (
    REGION VARCHAR(255) NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    GLOBAL_SUBSCRIPTION_ID VARCHAR(255) NOT NULL,

    UNIQUE (REGION, SUBSCRIPTION_ID, GLOBAL_SUBSCRIPTION_ID)
);

--
-- 22. Name: V2_GLOBAL_USER_MIGRATION_DATA
--

CREATE TABLE IF NOT EXISTS V2_GLOBAL_USER_MIGRATION_DATA (
    REGION VARCHAR(255) NOT NULL,
    USER_ENTITY_ID VARCHAR(255) NOT NULL,
    GLOBAL_USER_ENTITY_ID VARCHAR(255) NOT NULL,

    UNIQUE (REGION, USER_ENTITY_ID, GLOBAL_USER_ENTITY_ID)
);

--
-- 23. Name: V2_INVITE_HISTORY
--

CREATE TABLE IF NOT EXISTS V2_INVITE_HISTORY (
    INVITE_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    STATUS VARCHAR(255) NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    RECEIVER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    SENDER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    REVOKED_TIME_STAMP BIGINT,
    PERMISSIONS JSONB NOT NULL,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,

    CONSTRAINT INVITE_HISTORY_FK0 FOREIGN KEY (STATUS) REFERENCES V2_STATUS(STATUS),
    CONSTRAINT INVITE_HISTORY_FK1 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    CONSTRAINT INVITE_HISTORY_FK2 FOREIGN KEY (RECEIVER_USER_ENTITY_ID) REFERENCES V2_USERS(USER_ENTITY_ID)
    );

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_INVITE_HISTORY;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_INVITE_HISTORY FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

--
-- 24. Name: V2_PUBLISHED_API_ACCESS
--

CREATE TABLE IF NOT EXISTS V2_PUBLISHED_API_ACCESS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    STATUS VARCHAR(255) NOT NULL,
    ACTION_TIME BIGINT,

    CONSTRAINT PUBLISHED_API_ACCESS_FK0 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    CONSTRAINT PUBLISHED_API_ACCESS_FK1 FOREIGN KEY (STATUS) REFERENCES V2_STATUS(STATUS)
);

-- UPDATE_ACTION_TIME()

CREATE
    OR REPLACE FUNCTION UPDATE_ACTION_TIME()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    new.action_time
        = (SELECT CAST(EXTRACT(EPOCH FROM NOW()) AS BIGINT));
    RETURN new;
END;
$function$;

DROP TRIGGER IF EXISTS UPDATE_ACTION_TIME ON V2_PUBLISHED_API_ACCESS;
CREATE TRIGGER UPDATE_ACTION_TIME BEFORE INSERT OR UPDATE ON V2_PUBLISHED_API_ACCESS FOR EACH ROW EXECUTE PROCEDURE UPDATE_ACTION_TIME();

--
-- 25. Name: V2_RAW_SUBSCRIPTIONS
--

CREATE TABLE IF NOT EXISTS V2_RAW_SUBSCRIPTIONS (
    ID VARCHAR(255) NOT NULL PRIMARY KEY,
    RAW_PAYLOAD JSON NOT NULL,
    EMAIL VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255),
    SUBSCRIPTION_ID VARCHAR(255),
    REGION VARCHAR(255),
    IAAS_VENDOR VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    LOGS TEXT,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    CATEGORY VARCHAR(255) NOT NULL,
    ACTIVATION_URL TEXT,
    START_DATE BIGINT,
    IT_NOTIFICATION_RESPONSE JSONB,
    ORIGINAL_CATEGORY VARCHAR(255),

    CONSTRAINT V2_RAW_SUBSCRIPTIONS_FK1 FOREIGN KEY (SUBSCRIPTION_TYPE) REFERENCES V2_EXTERNAL_ACCOUNT_TYPES(EXTERNAL_ACCOUNT_TYPE)
);

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_RAW_SUBSCRIPTIONS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_RAW_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- validates the new records before insertion
-- check if there is an existing record which have same (email,tenant-id,category) to
-- prevent duplicate records for dpl_check and controlled_trial

DROP FUNCTION IF EXISTS VALIDATE_RAW_SUBSCRIPTION() CASCADE;
CREATE FUNCTION VALIDATE_RAW_SUBSCRIPTION()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
BEGIN
    PERFORM *
    FROM v2_raw_subscriptions
    WHERE tenant_id = new.tenant_id
      AND category = new.category
      AND email = new.email
      AND new.category IN ('DPL_CHECK', 'CONTROLLED_TRIAL');
    IF FOUND THEN
        RAISE 'Violates unique constraint for category %',new.category USING ERRCODE = 'unique_violation';
    END IF;
    NEW.CREATED_TIME = (SELECT cast(EXTRACT(EPOCH FROM NOW()) AS BIGINT));
    NEW.MODIFIED_TIME = (SELECT cast(EXTRACT(EPOCH FROM NOW()) AS BIGINT));
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS VALIDATE_RAW_SUBSCRIPTION_INSERT ON V2_RAW_SUBSCRIPTIONS;
CREATE TRIGGER VALIDATE_RAW_SUBSCRIPTION_INSERT BEFORE INSERT ON V2_RAW_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE VALIDATE_RAW_SUBSCRIPTION();

--
-- 25. NAME: V2_RAW_USERS
--

CREATE TABLE IF NOT EXISTS V2_RAW_USERS (
    ID VARCHAR(255) NOT NULL PRIMARY KEY,
    EMAIL VARCHAR(255) NOT NULL UNIQUE,
    FIRSTNAME VARCHAR(255) NOT NULL,
    LASTNAME VARCHAR(255) NOT NULL,
    COMPANYNAME VARCHAR(255),
    STATE VARCHAR(255),
    COUNTRY VARCHAR(255),
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL
);

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_RAW_USERS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_RAW_USERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON OAUTH2_USER_CONSENTS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_RAW_USERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

--
-- 26. Name: V2_RESOURCES
--

CREATE TABLE IF NOT EXISTS V2_RESOURCES (
    ID SERIAL NOT NULL,
    TENANT_ID VARCHAR(255) NOT NULL,
    RESOURCE_NAME VARCHAR(255) NOT NULL,
    SOFT_LIMIT INTEGER NOT NULL,
    HARD_LIMIT INTEGER NOT NULL,
    MODIFIED_TIME BIGINT,
    MODIFIED_BY VARCHAR(255),
    SCOPE VARCHAR(255) NOT NULL,

    CONSTRAINT V2_RESOURCES_PK UNIQUE (ID)
);

DROP TRIGGER IF EXISTS UPDATE_MODIFIED_TIME_OF_V2_RESOURCES ON V2_RESOURCES;
CREATE TRIGGER UPDATE_MODIFIED_TIME_OF_V2_RESOURCES BEFORE UPDATE ON V2_RESOURCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

--
-- 27. Name: V2_SECRET_HASH
--

CREATE TABLE IF NOT EXISTS V2_SECRET_HASH (
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    DP_ID VARCHAR(255) NOT NULL,
    ACCESS_KEY_ID VARCHAR(255),
    ACCESS_KEY_HASH VARCHAR(255),
    CREATED_TIME BIGINT,
    REGION VARCHAR NOT NULL,
    CONNECT_URL TEXT,
    
    CONSTRAINT V3_DATAPLANE_ID_FK1 FOREIGN KEY (DP_ID) REFERENCES V3_DATA_PLANES(DP_ID),
    CONSTRAINT V2_SECRET_HASH_PK PRIMARY KEY (SUBSCRIPTION_ID, REGION, DP_ID)
);

-- Insert created_time on v3_secret_hash by trigger

DROP FUNCTION IF EXISTS V2_SECRET_HASH_INSERT_CREATED_TIME() CASCADE;
CREATE FUNCTION V2_SECRET_HASH_INSERT_CREATED_TIME()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
BEGIN
    NEW.CREATED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    return NEW;
END;
$function$;

DROP TRIGGER IF EXISTS INSERT_CREATED_TIME ON V2_SECRET_HASH;
CREATE TRIGGER INSERT_CREATED_TIME BEFORE INSERT ON V2_SECRET_HASH FOR EACH ROW EXECUTE PROCEDURE V2_SECRET_HASH_INSERT_CREATED_TIME();

-- Trigger to validate if SUBSCRIPTION_ID exists before insert on table V2_SECRET_HASH

DROP FUNCTION IF EXISTS VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER() CASCADE;
CREATE FUNCTION VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER()
	RETURNS TRIGGER
	LANGUAGE PLPGSQL
	AS $function$
DECLARE
	SUBSCRIPTIONID VARCHAR(255);
BEGIN
	SELECT SUBSCRIPTION_ID INTO SUBSCRIPTIONID
	FROM V2_SUBSCRIPTIONS
	WHERE SUBSCRIPTION_ID = NEW.SUBSCRIPTION_ID;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'SUBSCRIPTION_ID "%" DOES NOT EXIST IN V2_SUBSCRIPTIONS', NEW.SUBSCRIPTION_ID;
	END IF;
	RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER ON V2_SECRET_HASH;
CREATE TRIGGER VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER BEFORE INSERT ON V2_SECRET_HASH FOR EACH ROW EXECUTE PROCEDURE VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_SECRET_HASH_TRIGGER();

-- Refresh materialized view V3_VIEW_DATA_PLANE_MONITOR_DETAILS

DROP FUNCTION IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH()
	RETURNS TRIGGER 
	LANGUAGE plpgsql 
	AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_DATA_PLANE_MONITOR_DETAILS;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_SH_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_SH_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();
--
-- 28. Name: V2_SERVICE_ACCOUNTS
--

CREATE TABLE IF NOT EXISTS V2_SERVICE_ACCOUNTS (
    USER_ENTITY_ID VARCHAR(255) NOT NULL,
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    ACCESS_WEB_UI BOOLEAN,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    CREATED_TIME BIGINT,
    MODIFIED_TIME BIGINT,
    COMMENT VARCHAR(255),

    PRIMARY KEY (USER_ENTITY_ID, TSC_ACCOUNT_ID),
    CONSTRAINT SERVICE_ACCOUNTS_FK0 FOREIGN KEY (USER_ENTITY_ID) REFERENCES V2_USERS(USER_ENTITY_ID),
    CONSTRAINT SERVICE_ACCOUNTS_FK1 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID)
);

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_SERVICE_ACCOUNTS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_SERVICE_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS VALIDATE_REDIRECT_URI_TRIGGER ON OAUTH2_USER_CONSENTS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_SERVICE_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

--
-- 29. Name: V2_SUBSCRIPTION_REQUESTS
--

CREATE TABLE IF NOT EXISTS V2_SUBSCRIPTION_REQUESTS (
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    REQUESTER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    REGION VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT NOT NULL,
    TSD_TICKET_URL TEXT,

    CONSTRAINT SUBSCRIPTION_REQUESTS_FK0 FOREIGN KEY (SUBSCRIPTION_TYPE) REFERENCES V2_EXTERNAL_ACCOUNT_TYPES(EXTERNAL_ACCOUNT_TYPE),
    CONSTRAINT SUBSCRIPTION_REQUESTS_FK1 FOREIGN KEY (REQUESTER_USER_ENTITY_ID) REFERENCES V2_USERS(USER_ENTITY_ID),
    CONSTRAINT SUBSCRIPTION_REQUESTS_FK2 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    PRIMARY KEY (TSC_ACCOUNT_ID, REGION)
);

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_SUBSCRIPTION_REQUESTS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_SUBSCRIPTION_REQUESTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V2_SUBSCRIPTION_REQUESTS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V2_SUBSCRIPTION_REQUESTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

--
-- 30. Name: V2_TENANT_PLANS
--

CREATE TABLE IF NOT EXISTS V2_TENANT_PLANS (
    TENANT_PLAN_ID VARCHAR(255) NOT NULL,
    TENANT_ID VARCHAR(255) NOT NULL,
    PLAN_ID VARCHAR(255) NOT NULL,
    DISPLAY_NAME VARCHAR(255) NOT NULL,
    CAPABILITIES VARCHAR(999) NOT NULL,
    GRACE_PERIOD BIGINT DEFAULT 30 NOT NULL,
    ACCESS_GRACE_PERIOD BIGINT,

    CONSTRAINT V2_TENANT_PRODUCT_PLANS_PKEY PRIMARY KEY (TENANT_PLAN_ID),
    CONSTRAINT V2_TENANT_PLANS_UNIQUE_CONSTRAINT UNIQUE (TENANT_ID, PLAN_ID),
    CONSTRAINT TENANT_PRODUCT_PLANS FOREIGN KEY (TENANT_ID) REFERENCES V2_TENANTS(TENANT_ID)
);

DROP TRIGGER IF EXISTS Z_V2_CINDEX_AUDIT_TENANT_PLANS ON V2_TENANT_PLANS;
CREATE TRIGGER Z_V2_CINDEX_AUDIT_TENANT_PLANS AFTER INSERT OR DELETE OR UPDATE ON V2_TENANT_PLANS FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_AUDIT();

--
-- 31. Name: V2_SUBSCRIPTIONS
--

CREATE TABLE IF NOT EXISTS V2_SUBSCRIPTIONS (
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    SUBSCRIPTION_TYPE VARCHAR(255) NOT NULL,
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    TENANT_PLAN_ID VARCHAR(255) NOT NULL,
    SEATS TEXT NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    BUY_TIME BIGINT,
    EXPIRY_TIME BIGINT,
    EXPIRY_NOTIFICATION_TIME BIGINT,
    GRACE_PERIOD_NOTIFICATION_TIME BIGINT,
    EXTERNAL_SUBSCRIPTION_ID VARCHAR(255),
    MODIFIED_TIME BIGINT,
    CAPABILITIES VARCHAR(999) NOT NULL,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    CREATED_FOR VARCHAR(255) NOT NULL,
    MODIFIED_FOR VARCHAR(255) NOT NULL,
    PARENT_SUBSCRIPTION_ID VARCHAR(255) DEFAULT NULL::VARCHAR,
    END_OF_CONTRACT_TIME BIGINT,
    COMMENT VARCHAR(255),
    SUBSCRIPTION_SOURCE VARCHAR(255),
    START_OF_CONTRACT_TIME BIGINT,
    RESOURCE_INSTANCE_IDS TEXT[],
    CONTAINER_REGISTRY_CREDENTIAL JSONB,

    CONSTRAINT SUBSCRIPTIONS_FK0 FOREIGN KEY (SUBSCRIPTION_TYPE) REFERENCES V2_EXTERNAL_ACCOUNT_TYPES(EXTERNAL_ACCOUNT_TYPE),
    CONSTRAINT SUBSCRIPTIONS_FK1 FOREIGN KEY (TSC_ACCOUNT_ID) REFERENCES V2_ACCOUNTS(TSC_ACCOUNT_ID),
    CONSTRAINT SUBSCRIPTIONS_FK2 FOREIGN KEY (TENANT_PLAN_ID) REFERENCES V2_TENANT_PLANS(TENANT_PLAN_ID),
    CONSTRAINT SUBSCRIPTIONS_FK3 FOREIGN KEY (STATUS) REFERENCES V2_STATUS(STATUS),
    PRIMARY KEY (SUBSCRIPTION_ID, TENANT_PLAN_ID)
);

-- Trigger to update SEAT_USAGE_MODIFIED_TIME in v2_accounts table

DROP FUNCTION IF EXISTS UPDATE_SEAT_USAGE_MODIFIED_TIME() CASCADE;
CREATE FUNCTION UPDATE_SEAT_USAGE_MODIFIED_TIME()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $function$
BEGIN
	IF (TG_OP = 'DELETE') THEN
		UPDATE V2_ACCOUNTS
		SET SEAT_USAGE_MODIFIED_TIME=extract(epoch from now())
		WHERE OLD.TSC_ACCOUNT_ID = V2_ACCOUNTS.TSC_ACCOUNT_ID;
		RETURN OLD;
	ELSE
		UPDATE V2_ACCOUNTS
		SET SEAT_USAGE_MODIFIED_TIME=extract(epoch from now())
		WHERE NEW.TSC_ACCOUNT_ID = V2_ACCOUNTS.TSC_ACCOUNT_ID;
		RETURN NEW;
	 END IF;
END;
$function$;

-- DROP TRIGGER IF EXISTS UPDATE_SEAT_USAGE_MODIFIED_TIME_ON_V2_SUBSCRIPTIONS ON V2_SUBSCRIPTIONS;
-- CREATE TRIGGER UPDATE_SEAT_USAGE_MODIFIED_TIME_ON_V2_SUBSCRIPTIONS AFTER INSERT OR DELETE OR UPDATE ON V2_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE UPDATE_SEAT_USAGE_MODIFIED_TIME();

-- Trigger to validate only one SUBSCRIPTION_ID is associated to one TSC_ACCOUNT

DROP FUNCTION IF EXISTS VALIDATE_SUBSCRIPTION_ID_FOR_TSC_ACCOUNT_TRIGGER() CASCADE;
CREATE FUNCTION VALIDATE_SUBSCRIPTION_ID_FOR_TSC_ACCOUNT_TRIGGER()
	RETURNS TRIGGER
	LANGUAGE PLPGSQL
	AS $function$
DECLARE
	SUBSCRIPTIONID VARCHAR(255);
BEGIN
	SELECT SUBSCRIPTION_ID INTO SUBSCRIPTIONID
	FROM V2_SUBSCRIPTIONS
	WHERE TSC_ACCOUNT_ID = NEW.TSC_ACCOUNT_ID;

	IF FOUND AND SUBSCRIPTIONID IS DISTINCT FROM NEW.SUBSCRIPTION_ID THEN
		RAISE EXCEPTION 'SUBSCRIPTION_ID "%" IS ALREADY ASSOCIATED TO TSC_ACCOUNT_ID "%"', SUBSCRIPTIONID, NEW.TSC_ACCOUNT_ID;
	END IF;
	RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS VALIDATE_SUBSCRIPTION_ID_FOR_TSC_ACCOUNT_TRIGGER ON V2_SUBSCRIPTIONS;
CREATE TRIGGER VALIDATE_SUBSCRIPTION_ID_FOR_TSC_ACCOUNT_TRIGGER BEFORE INSERT ON V2_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE VALIDATE_SUBSCRIPTION_ID_FOR_TSC_ACCOUNT_TRIGGER();

DROP TRIGGER IF EXISTS Z_V2_CINDEX_AUDIT_SUBSCRIPTIONS ON V2_SUBSCRIPTIONS;
CREATE TRIGGER Z_V2_CINDEX_AUDIT_SUBSCRIPTIONS AFTER INSERT OR DELETE OR UPDATE ON V2_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE tscutdb_audit.V2_CINDEX_UTD_AUDIT();

-- Refresh materialized view V3_VIEW_ACCOUNT_ALLOWED_RESOURCE

DROP TRIGGER IF EXISTS V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_SUB_TRIGGER ON V2_SUBSCRIPTIONS;
CREATE TRIGGER V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_SUB_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V2_SUBSCRIPTIONS 
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_REFRESH();

--
-- 32. Name: V2_TENANT_STATUS
--

CREATE TABLE IF NOT EXISTS V2_TENANT_STATUS (
    TENANT_ID VARCHAR(255) NOT NULL,
    REGION VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,

    PRIMARY KEY (TENANT_ID, REGION),
    CONSTRAINT V2_TENANT_STATUS_FK0 FOREIGN KEY (TENANT_ID) REFERENCES V2_TENANTS(TENANT_ID)
);

--
-- 34. Name: V2_TENANTS_ACCESS_SETTINGS
--

CREATE TABLE IF NOT EXISTS V2_TENANTS_ACCESS_SETTINGS (
    ACCESS_SETTINGS JSONB NOT NULL
);

--
-- 35. Name: V2_WHITELIST_CIDRS
--

CREATE TABLE IF NOT EXISTS V2_WHITELIST_CIDRS (
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    REGION VARCHAR(255) NOT NULL,
    CIDR_ADDR JSONB,
    CREATED_TIME BIGINT DEFAULT EXTRACT(EPOCH FROM NOW()) NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255),

    CONSTRAINT V2_WHITELIST_CIDRS_PK UNIQUE (SUBSCRIPTION_ID, REGION)
);

DROP TRIGGER IF EXISTS UPDATE_MODIFIED_TIME_OF_V2_WHITELIST_CIDRS ON V2_WHITELIST_CIDRS;
CREATE TRIGGER UPDATE_MODIFIED_TIME_OF_V2_WHITELIST_CIDRS BEFORE UPDATE ON V2_WHITELIST_CIDRS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- VALIDATE_SUBSCRIPTION_ID_ON_INSERT()

DROP FUNCTION IF EXISTS VALIDATE_SUBSCRIPTION_ID_ON_INSERT() CASCADE;
CREATE FUNCTION VALIDATE_SUBSCRIPTION_ID_ON_INSERT()
	RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
DECLARE
    SUBSCRIPTIONID VARCHAR(255);
BEGIN
    SELECT SUBSCRIPTION_ID
    INTO SUBSCRIPTIONID
    FROM V2_SUBSCRIPTIONS
    WHERE SUBSCRIPTION_ID = NEW.SUBSCRIPTION_ID;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SUBSCRIPTION_ID "%" DOES NOT EXIST IN V2_SUBSCRIPTIONS', NEW.SUBSCRIPTION_ID;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_WHITELIST_CIDRS ON V2_WHITELIST_CIDRS;
CREATE TRIGGER VALIDATE_SUBSCRIPTION_ID_ON_INSERT_V2_WHITELIST_CIDRS BEFORE INSERT ON V2_WHITELIST_CIDRS FOR EACH ROW EXECUTE PROCEDURE VALIDATE_SUBSCRIPTION_ID_ON_INSERT();

--
-- 36. Name: V3_MFA
--

CREATE TABLE IF NOT EXISTS V3_MFA (
    USER_ENTITY_ID varchar NOT NULL,
    SECRET VARCHAR NOT NULL,
    RECOVERY_CODES JSONB NOT NULL
);

--
-- 38. Name: SCHEMA_VERSION
--

CREATE TABLE IF NOT EXISTS SCHEMA_VERSION (
    ID SERIAL PRIMARY KEY,
    VERSION INTEGER NOT NULL UNIQUE
);

INSERT INTO SCHEMA_VERSION (VERSION) VALUES (1) ON CONFLICT DO NOTHING;


--------------------------------------------------------------------------------
-- Populating initial data
--------------------------------------------------------------------------------

--
-- V2_EXTERNAL_ACCOUNT_TYPES
--

INSERT INTO V2_EXTERNAL_ACCOUNT_TYPES (EXTERNAL_ACCOUNT_TYPE, DISPLAY_NAME, DESCRIPTION) VALUES
    ('TRIAL','Trial Subscription','TRIAL PLAN'),
    ('TIB','TIBCO(internal) Subscription','INTERNAL USERS PLAN'),
    ('PO','Purchase Order','PURCHASE ORDER PLAN'),
    ('CC','Credit Card Subscription','CREDIT CARD PLAN'),
    ('AWSMP','AWS Marketplace Subscription','AWS MARKETPLACE PLAN'),
    ('AMP','Azure Marketplace Subscription','AZURE MARKETPLACE PLAN'),
    ('PARTNER_NFR','Partner NFR Subscription','PARTNER NFR PLAN'),
    ('CPASS','Cloud Passport Subscription','CPASS PLAN')
ON CONFLICT DO NOTHING;

--
-- V2_RESOURCES
--

INSERT INTO V2_RESOURCES (ID, TENANT_ID, RESOURCE_NAME, SOFT_LIMIT, HARD_LIMIT, MODIFIED_TIME, MODIFIED_BY, SCOPE) VALUES
    (1,'TSC','ACCOUNT_USERS',10000,50000,NULL,NULL,'GLOBAL'),
    (2,'TSC','PROXY_AGENT_ACCESS_KEYS',500,1000,NULL,NULL,'REGIONAL'),
    (3,'TSC','DATA_PLANE_COUNT',10,15,NULL,NULL,'GLOBAL')
ON CONFLICT DO NOTHING;

--
-- V2_ROLES
--

INSERT INTO V2_ROLES (ROLE_ID, DISPLAY_NAME, DESCRIPTION) VALUES
    ('owner','OWNER','Owner of the Tsc-Account'),
    ('member','MEMBER','Member of the Tsc-Account')
ON CONFLICT DO NOTHING;

--
-- V2_STATUS
--

INSERT INTO V2_STATUS (STATUS, DISPLAY_NAME, DESCRIPTION) VALUES
    ('active','ACTIVE','Status is: active'),
    ('disabled','DISABLED','Status is: disabled'),
    ('invited','INVITED','Status is: invited'),
    ('retracted','RETRACTED','Status is: retracted'),
    ('expired','EXPIRED','Status is: expired'),
    ('accepted','ACCEPTED','Status is: accepted'),
    ('cancelled','CANCELLED','Status is: cancelled'),
    ('suspended','SUSPENDED','Status is: suspended'),
    ('amended','AMENDED','Status is: amended'),
    ('granted','GRANTED','Status is: granted')
ON CONFLICT DO NOTHING;

--
-- V2_TENANTS
--

INSERT INTO V2_TENANTS (TENANT_ID, DISPLAY_NAME, DESCRIPTION, EULA_LINK, EULA_TEXT, SUPPORT_FORM_METADATA) VALUES
    ('ADMIN','Admin','TIBCO Cloud<sup>&reg;</sup> Admin','https://www.cloud.com/content/dam/cloud/documents/legal/end-user-agreement.pdf','The TIBCO<sup>&reg;</sup> End User License Agreement and Privacy Policy have been updated. Please acknowledge your acceptance by checking the boxes below and clicking “ACCEPT” to continue.','{"domain": "Subscriber Cloud","type": "supportform","problemTypes": [{"displayName": "Logging in","value": "Logging in"},{"displayName": "TIBCO Cloud™ - Account","value": "TIBCO Cloud™ - Account"}, {"displayName": "TIBCO Cloud™ - Subscriptions","value": "TIBCO Cloud™ - Subscriptions"},{"displayName": "TIBCO Cloud™ - Organization","value": "TIBCO Cloud™ - Organization"}, {"displayName": "Documentation","value": "Documentation"},  {"displayName": "Billing","value": "Billing"}, {"displayName": "Other","value": "Other"}],"defaultFields": []}'),
    ('TP','TIBCO Platform','TIBCO Platform<sup>&trade;</sup>','https://www.cloud.com/content/dam/cloud/documents/legal/end-user-agreement.pdf','The TIBCO<sup>&reg;</sup> End User License Agreement and Privacy Policy have been updated. Please acknowledge your acceptance by checking the boxes below and clicking “ACCEPT” to continue.','{"domain": "TIBCO Platform","type": "supportform","problemTypes": [{"displayName": "Logging in","value": "Logging in"},{"displayName": "TIBCO Platform™ - Account","value": "TIBCO Platform™ - Account"}, {"displayName": "TIBCO Platform™ - Subscriptions","value": "TIBCO Platform™ - Subscriptions"},{"displayName": "TIBCO Platform™ - Organization","value": "TIBCO Platform™ - Organization"}, {"displayName": "Documentation","value": "Documentation"},{"displayName": "Billing","value": "Billing"}, {"displayName": "Other","value": "Other"}],"defaultFields": []}'),
    ('TSC','TSC','TIBCO Cloud<sup>&trade;</sup>','https://www.cloud.com/content/dam/cloud/documents/legal/end-user-agreement.pdf','The TIBCO<sup>&reg;</sup> End User License Agreement and Privacy Policy have been updated. Please acknowledge your acceptance by checking the boxes below and clicking “ACCEPT” to continue.','{"domain": "TIBCO Cloud","type": "supportform","problemTypes": [{"displayName": "Logging in","value": "Logging in"},{"displayName": "TIBCO Cloud™ - Account","value": "TIBCO Cloud™ - Account"}, {"displayName": "TIBCO Cloud™ - Subscriptions","value": "TIBCO Cloud™ - Subscriptions"},{"displayName": "TIBCO Cloud™ - Organization","value": "TIBCO Cloud™ - Organization"}, {"displayName": "Documentation","value": "Documentation"},{"displayName": "Billing","value": "Billing"}, {"displayName": "Other","value": "Other"}],"defaultFields": []}')
ON CONFLICT DO NOTHING;

--
-- INSERT EMPTY ARRAY ONLY IF THE TABLE IS EMPTY
--

INSERT INTO V2_TENANTS_ACCESS_SETTINGS (ACCESS_SETTINGS)
    SELECT '{}'
WHERE NOT EXISTS (SELECT * FROM V2_TENANTS_ACCESS_SETTINGS);

--
-- V2_TENANT_PLANS
--

INSERT INTO V2_TENANT_PLANS (TENANT_PLAN_ID, TENANT_ID, PLAN_ID, DISPLAY_NAME, CAPABILITIES, GRACE_PERIOD, ACCESS_GRACE_PERIOD) VALUES
    ('peiwdffhfo2jwkdjeu2wdq2lhi42ga00','TP','TIB_CLD_TP_PAID_CPASS','TIBCO Platform<sup>&reg;</sup> Cloud Passport Plan','{"TP":{"cpass":true}}',180,30),
    ('peiwdffhfo2jwkdjeu2wdq2lhi42gn21','ADMIN','TIB_CLD_ADMIN_TIB_CLOUDOPS','TIBCO Cloud<sup>&reg;</sup> Admin CloudOps Plan','{"ADMIN":{}}',0,NULL)
ON CONFLICT DO NOTHING;

--
-- DROP V2_GLOBAL_ACCOUNT_MIGRATION_DATA, V2_GLOBAL_SUBSCRIPTION_MIGRATION_DATA, V2_GLOBAL_USER_MIGRATION_DATA tables
--

DROP TABLE IF EXISTS V2_GLOBAL_ACCOUNT_MIGRATION_DATA, V2_GLOBAL_SUBSCRIPTION_MIGRATION_DATA, V2_GLOBAL_USER_MIGRATION_DATA CASCADE;

-- TRIGGER TRIGGER_SET_MODIFIER()
DROP FUNCTION IF EXISTS TRIGGER_SET_MODIFIER() CASCADE;
CREATE FUNCTION TRIGGER_SET_MODIFIER()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $function$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        NEW.CREATED_BY = (select coalesce(current_setting('cp.userId', true), 'platform-default'));
        NEW.MODIFIED_BY = (select coalesce(current_setting('cp.userId', true), 'platform-default'));
    ELSEIF (TG_OP = 'UPDATE') THEN
        NEW.MODIFIED_BY = (select coalesce(current_setting('cp.userId', true), 'platform-default'));
    END IF;
    RETURN NEW;
END;
$function$;

--
-- V3_SERVICE_RECIPES
--

CREATE TABLE IF NOT EXISTS V3_CAPABILITY_METADATA (
    CAPABILITY_ID VARCHAR(255) NOT NULL,
    VERSION int[] NOT NULL,
    DISPLAY_NAME VARCHAR(255) NOT NULL,
    DESCRIPTION VARCHAR(255),
    PACKAGE JSONB NOT NULL,
    COMMENT varchar(255) NULL,
    CAPABILITY_TYPE VARCHAR(255) NOT NULL DEFAULT 'PLATFORM',
    CREATED_TIME BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),

    CONSTRAINT V3_CAPABILITY_METADATA_PKEY PRIMARY KEY (CAPABILITY_ID, VERSION, CAPABILITY_TYPE)
);

ALTER TABLE V3_CAPABILITY_METADATA ALTER COLUMN DESCRIPTION TYPE VARCHAR(300);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON V3_CAPABILITY_METADATA;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON V3_CAPABILITY_METADATA FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();

DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON V3_CAPABILITY_METADATA;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON V3_CAPABILITY_METADATA FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V3_CAPABILITY_METADATA;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V3_CAPABILITY_METADATA FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V3_CAPABILITY_METADATA;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V3_CAPABILITY_METADATA FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

--
-- V3_SERVICE_INSTANCES
--

CREATE TABLE IF NOT EXISTS V3_CAPABILITY_INSTANCES (
    CAPABILITY_ID VARCHAR(255) NOT NULL,
    DP_ID VARCHAR(255) NOT NULL,
    NAMESPACE VARCHAR(255) NOT NULL,
    VERSION int[] NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    REGION VARCHAR(255) NOT NULL,
    CREATED_TIME BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    TAGS TEXT[],
    CAPABILITY_INSTANCE_ID VARCHAR(255) NOT NULL DEFAULT '',
    CAPABILITY_INSTANCE_NAME VARCHAR(255),
    CAPABILITY_INSTANCE_DESCRIPTION VARCHAR(255),
    CONCRETE_RECIPE        JSONB        NOT NULL DEFAULT '{}',
    RESOURCE_INSTANCE_IDS TEXT[],
    EULA BOOLEAN,
    CAPABILITY_TYPE VARCHAR(255) NOT NULL,
    CONSTRAINT V3_CAPABILITY_INSTANCES_PKEY PRIMARY KEY (CAPABILITY_INSTANCE_ID, CAPABILITY_ID, VERSION, DP_ID, NAMESPACE),
    CONSTRAINT V3_CAPABILITY_INSTANCES_FK0 FOREIGN KEY (CAPABILITY_ID,VERSION,CAPABILITY_TYPE) REFERENCES V3_CAPABILITY_METADATA(CAPABILITY_ID,VERSION,CAPABILITY_TYPE),
    CONSTRAINT V3_CAPABILITY_INSTANCES_FK1 FOREIGN KEY (DP_ID) REFERENCES V3_DATA_PLANES(DP_ID)
    );

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V3_CAPABILITY_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V3_CAPABILITY_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- Refresh materialized view V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_CI_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V3_CAPABILITY_INSTANCES 
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();


-- Refresh materialized view V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY
DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CAPABILITY_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_METADATA
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();


-- Refresh materialized view V3_VIEW_DATA_PLANE_MONITOR_DETAILS

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_CI_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V3_CAPABILITY_INSTANCES 
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

--
-- V3_APPS
--

CREATE TABLE IF NOT EXISTS V3_APPS (
    APP_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    APP_NAME VARCHAR(255) NOT NULL,
    APP_VERSION int[] NOT NULL,
    CAPABILITY_INSTANCE_ID VARCHAR(255) NOT NULL,
    CAPABILITY_ID VARCHAR(255) NOT NULL,
    CAPABILITY_VERSION int[] NOT NULL,
    DP_ID VARCHAR(255) NOT NULL,
    NAMESPACE VARCHAR(255) NOT NULL,
    STATE VARCHAR(255) NOT NULL,
    TAGS TEXT[],
    CREATED_TIME BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    EULA BOOLEAN
    );

-- Add foreign key explicitly on V3_APPS table
--TODO FIX me: ADD FOREIGN KEY ON V3_APPS TABLE
--ALTER TABLE V3_APPS DROP CONSTRAINT IF EXISTS V3_APPS_FK0;
--ALTER TABLE V3_APPS ADD CONSTRAINT V3_APPS_FK0 FOREIGN KEY (DP_ID,CAPABILITY_INSTANCE_ID,CAPABILITY_ID,CAPABILITY_VERSION) REFERENCES V3_CAPABILITY_INSTANCES(DP_ID,CAPABILITY_INSTANCE_ID,CAPABILITY_ID,VERSION);

-- create v3_resources table

CREATE TABLE IF NOT EXISTS V3_RESOURCES (
    RESOURCE_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    NAME VARCHAR(255) NOT NULL,
    DESCRIPTION VARCHAR(255),
    TYPE VARCHAR(255),
    RESOURCE_METADATA JSONB NOT NULL,
    HOST_CLOUD_TYPE VARCHAR(255) NOT NULL,
    RESOURCE_LEVEL varchar(255) NOT NULL
    );

-- Alter v3_resources to make host_cloud_type as TEXT[]
ALTER TABLE V3_RESOURCES DROP COLUMN host_cloud_type;
ALTER TABLE V3_RESOURCES ADD host_cloud_type TEXT[] NOT NULL DEFAULT '{"aws","azure"}';

-- Create V3_RESOURCE_SCOPES table
CREATE TABLE IF NOT EXISTS V3_RESOURCE_SCOPES (
    SCOPE VARCHAR(255) NOT NULL PRIMARY KEY,
    DISPLAY_NAME varchar(255),
    PARENT VARCHAR(255) REFERENCES V3_RESOURCE_SCOPES (SCOPE)
    );

-- create v3_resource_instances table

CREATE TABLE IF NOT EXISTS V3_RESOURCE_INSTANCES (
    RESOURCE_INSTANCE_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    RESOURCE_ID VARCHAR(255) NOT NULL,
    RESOURCE_INSTANCE_NAME VARCHAR(255),
    RESOURCE_INSTANCE_DESCRIPTION VARCHAR(255),
    SCOPE VARCHAR(255) NOT NULL,
    SCOPE_ID VARCHAR(255) NOT NULL,
    REGION VARCHAR(255),
    RESOURCE_INSTANCE_METADATA JSONB NOT NULL,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    CREATED_TIME VARCHAR(255) NOT NULL,
    MODIFIED_TIME VARCHAR(255) NOT NULL,
    CONSTRAINT V3_RESOURCE_INSTANCES_FK0 FOREIGN KEY (RESOURCE_ID) REFERENCES V3_RESOURCES(RESOURCE_ID),
    CONSTRAINT V3_RESOURCE_INSTANCES_FK1 FOREIGN KEY (SCOPE) REFERENCES V3_RESOURCE_SCOPES(SCOPE)
    );

DROP TRIGGER IF EXISTS SET_CREATED_BY ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON V3_RESOURCE_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();

DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON V3_RESOURCE_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V3_RESOURCE_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V3_RESOURCE_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V3_APPS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V3_APPS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON V3_APPS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON V3_APPS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- Add RESOURCE_LEVEL column to v3_resource_instances
ALTER TABLE v3_resource_instances ADD COLUMN IF NOT EXISTS resource_level varchar(255) NOT NULL DEFAULT 'PLATFORM';

-- Refresh materialized view V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_APPS_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_APPS_TRIGGER AFTER 
    INSERT OR UPDATE OR DELETE 
ON V3_APPS 
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

-- Refresh materialized view V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES

DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_RESOURCE_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

--
-- V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES
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

--
-- V3_VIEW_DATA_PLANE_MONITOR_DETAILS
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
        SELECT CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, DISPLAY_NAME, CI.CAPABILITY_TYPE, NAMESPACE, CI.VERSION, STATUS, REGION, TAGS)
            AS ColumnName (CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION, CAPABILITY_ID, NAME, CAPABILITY_TYPE, NAMESPACE, VERSION, STATUS, REGION, TAGS)
        ))) CAPABILITIES 
        FROM (V3_CAPABILITY_INSTANCES CI LEFT JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID))
        GROUP BY DP_ID) DPCP USING(DP_ID)
GROUP BY VDP.SUBSCRIPTION_ID
WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_DATA_PLANE_MONITOR_DETAILS_INDEX ON V3_VIEW_DATA_PLANE_MONITOR_DETAILS (SUBSCRIPTION_ID);

-- Adding TETRIS capability for testing purposes, should be removed later
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE)
VALUES ('TETRIS','{1,0,0}','Tetris Capability','Capability for testing purposes','{"package":{"recipe":{"helmCharts":[{"flags":{"createnamespace":true,"install":true},"name":"tetris","namespace":"tibco-dp","repository":{"git":{"branch":"master","host":"https://github.com/bsord/tetris","path":"/chart/"}},"values":[{"content":"ingress:\n enabled: true\n annotations:\n kubernetes.io/ingress.class: traefik\n traefik.ingress.kubernetes.io/router.entrypoints: websecure\n hosts:\n - host: app5.dp-platform.tcie.pro\n"}]}]},"allowMultipleInstances":true, "provisioningRoles": ["DEV_OPS"], "services":[{"name":"tetris","description":"Tetris serivce"}]}}')
ON CONFLICT DO NOTHING;

-- Add TIBCO Hub details to V3_CAPABILITY_METADATA table
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE)
VALUES ('TIBCOHUB', '{1,0,0}', 'TIBCO Developer Hub', 'TIBCO Developer Hub is a one-stop shop for developers on TIBCO Platform, where you can find and share documentation and assets with other developers. You can also create new TIBCO assets based on templates.',
        '{"package":{"recipe":{"helmCharts":[{"name":"tibco-hub","flags":{"install":true,"createNamespace":true,"dependencyUpdate":true},"values":[{"content":"baseUrlKeyPath: backstage.appConfig.app.baseUrl\nbackstage:\n  image:\n    registry: 664529841144.dkr.ecr.us-west-2.amazonaws.com\n    tag: qa-candidate\n  appConfig:\n    app:\n      baseUrl: ${PUBLIC_URL}\n    backend:\n      baseUrl: ${PUBLIC_URL}\n    auth:\n      providers:\n        oauth2:\n          development:\n            clientId: ${AUTH_TIBCO_CLIENT_ID}\n            clientSecret: ${AUTH_TIBCO_CLIENT_SECRET}\n            authorizationUrl: ${AUTH_TIBCO_AUTHORIZATION_URL}\n            tokenUrl: ${AUTH_TIBCO_TOKEN_URL}\n      enableAuthProviders: [tibco]\n# only if user provides a secrets reference\n#   extraEnvVarsSecrets:\n#     - tibco-hub-secrets\npostgresql:\n  enabled: true\ningress:\n  enabled: true\n  annotations:\n    traefik.ingress.kubernetes.io/router.entrypoints: websecure\n  className: ${INGRESS_CLASSNAME}\n  host: ${HOSTNAME}\n"}],"namespace":"${NAMESPACE}","repository":{"chartMuseum":{"host":"https://tibco-hub-backstage.github.io/charts/"}}}]},"allowMultipleInstances":false,"provisioningRoles":["DEV_OPS"],"services":[{"name":"postgresql","description":"Postgres Database"},{"name":"tibco-hub","description":"NodeJs backend and UI hosting service"}],"capabilityResourceDependencies":[{"required":true,"resourceId":"INGRESS","type":"PLATFORM"},{"required":true,"resourceId":"STORAGE","type":"PLATFORM"}]}}')
ON CONFLICT DO NOTHING;

--
-- V3_VIEW_ACCOUNT_ALLOWED_RESOURCE
--

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_ACCOUNT_ALLOWED_RESOURCE CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_ACCOUNT_ALLOWED_RESOURCE 
AS
SELECT 
	S.TSC_ACCOUNT_ID, 
	S.SUBSCRIPTION_ID,
	S.TENANT_PLAN_ID,
	DP.DP_ID
FROM V2_SUBSCRIPTIONS S
LEFT JOIN V3_DATA_PLANES DP 
USING(SUBSCRIPTION_ID)
WITH DATA;

CREATE UNIQUE INDEX V3_VIEW_ACCOUNT_ALLOWED_RESOURCE_INDEX ON V3_VIEW_ACCOUNT_ALLOWED_RESOURCE 
(TSC_ACCOUNT_ID, TENANT_PLAN_ID, SUBSCRIPTION_ID, DP_ID);

DROP TRIGGER IF EXISTS SET_CREATED_TIME ON V2_ACCOUNTS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON V2_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();

-- Add BWCE details to v3_capability_metadata table
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('BWCE', '{1,0,0}', 'TIBCO BusinessWorks™ Container Edition', 'TIBCO BusinessWorks integrates enterprise apps and orchestrates web services across hybrid environments.', '{"package":{"recipe":{"helmCharts":[{"name":"bwprovisioner","namespace":"${NAMESPACE}","version":"1.0.6","repository":{"chartMuseum":{"host":"https://syan-tibco.github.io/tp-helm-charts/"}},"values":[{"content":"global:\n  bwprovisioner:\n    image:\n      tag: 208\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"bwprovisioner","description":"BW Provisioner Service"}],"dependsOn":[{"version":[1,0,0],"capabilityId":"INTEGRATIONCORE"},{"version": [1,0,0],"capabilityId": "OAUTH2PROXY"}],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[{"type":"PLATFORM","required":true,"resourceId":"INGRESS"}]}}', 'PLATFORM')
ON CONFLICT DO NOTHING;

-- Create v3_view_resource_scope_hierarchy materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS V3_VIEW_RESOURCE_SCOPE_HIERARCHY AS
WITH RECURSIVE SCOPES_CTE(SCOPE, PARENT, PATH) AS (
    SELECT RS.SCOPE, RS.PARENT, ARRAY[RS.SCOPE::TEXT]
    FROM V3_RESOURCE_SCOPES RS
    WHERE RS.PARENT IS NULL
    UNION ALL
    SELECT RS.SCOPE, RS.PARENT, ARRAY_APPEND(SCOPES_CTE.PATH, RS.SCOPE::TEXT)
    FROM SCOPES_CTE,
         V3_RESOURCE_SCOPES RS
    WHERE RS.PARENT = SCOPES_CTE.SCOPE
)SELECT * FROM SCOPES_CTE;

DROP FUNCTION IF EXISTS V3_VIEW_RESOURCE_SCOPE_HIERARCHY_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_RESOURCE_SCOPE_HIERARCHY_REFRESH() RETURNS TRIGGER
    LANGUAGE PLPGSQL AS
$$
BEGIN
    REFRESH MATERIALIZED VIEW V3_VIEW_RESOURCE_SCOPE_HIERARCHY;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_RESOURCE_SCOPE_HIERARCHY_TRIGGER ON V3_RESOURCE_SCOPES;
CREATE TRIGGER V3_VIEW_RESOURCE_SCOPE_HIERARCHY_TRIGGER
    AFTER UPDATE OR INSERT OR DELETE OR TRUNCATE
    ON V3_RESOURCE_SCOPES
EXECUTE PROCEDURE V3_VIEW_RESOURCE_SCOPE_HIERARCHY_REFRESH();

-- Insert subscription, dataplane and capability scope
INSERT INTO V3_RESOURCE_SCOPES (SCOPE,DISPLAY_NAME)VALUES('SUBSCRIPTION','PER SUBSCRIPTION') ON CONFLICT DO NOTHING;
INSERT INTO V3_RESOURCE_SCOPES (SCOPE,DISPLAY_NAME,PARENT)VALUES('DATAPLANE','PER DATAPLANE','SUBSCRIPTION') ON CONFLICT DO NOTHING;
INSERT INTO V3_RESOURCE_SCOPES (SCOPE,DISPLAY_NAME,PARENT)VALUES('CAPABILITY','PER CAPABILITY INSTANCE','DATAPLANE') ON CONFLICT DO NOTHING;

-- Refresh materialized view V3_VIEW_APPS_ON_SUBSCRIPTIONS

DROP FUNCTION IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
	AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_APPS_ON_SUBSCRIPTIONS;
RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_APPS_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_APPS_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_APPS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_CI_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_CI_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_CAPABILITY_INSTANCES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_DP_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_DP_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V3_DATA_PLANES
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_APPS_ON_SUBSCRIPTIONS_SUB_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_APPS_ON_SUBSCRIPTIONS_SUB_TRIGGER AFTER
    INSERT OR UPDATE OR DELETE
              ON V2_SUBSCRIPTIONS
                  FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_APPS_ON_SUBSCRIPTIONS_REFRESH();


-- V3_VIEW_APPS_ON_SUBSCRIPTIONS view is used to get list of all apps present under a subscriptions
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

-- ADD TRIGGERS ON EXISTING INDIVIDUAL TABLES FOR AUDIT TRAILING
DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_ACCOUNT_USER_ROLES_AUDIT_TRAIL ON V2_ACCOUNT_USER_ROLES;
-- CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_ACCOUNT_USER_ROLES_AUDIT_TRAIL AFTER INSERT OR UPDATE OR DELETE ON V2_ACCOUNT_USER_DETAILS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_ACCOUNTS_AUDIT_TRAIL ON V2_ACCOUNTS;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_ACCOUNTS_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V2_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_EULA_STATUS_AUDIT_TRAIL ON V2_EULA_STATUS;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_EULA_STATUS_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V2_EULA_STATUS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_EXTERNAL_ACCOUNTS_AUDIT_TRAIL ON V2_EXTERNAL_ACCOUNTS;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_EXTERNAL_ACCOUNTS_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V2_EXTERNAL_ACCOUNTS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_SUBSCRIPTIONS_AUDIT_TRAIL ON V2_SUBSCRIPTIONS;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_SUBSCRIPTIONS_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V2_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();


DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_USERS_AUDIT_TRAIL ON V2_USERS;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_USERS_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V2_USERS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V2_SECRET_HASH_AUDIT_TRAIL ON V2_SECRET_HASH;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V2_SECRET_HASH_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V2_SECRET_HASH FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V3_DATA_PLANES_AUDIT_TRAIL ON V3_DATA_PLANES;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V3_DATA_PLANES_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V3_DATA_PLANES FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V3_CAPABILITY_INSTANCES_AUDIT_TRAIL ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V3_CAPABILITY_INSTANCES_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V3_CAPABILITY_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V3_APPS_AUDIT_TRAIL ON V3_APPS;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V3_APPS_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V3_APPS FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V3_RESOURCE_INSTANCES_AUDIT_TRAIL ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V3_RESOURCE_INSTANCES_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V3_RESOURCE_INSTANCES FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V3_RESOURCE_SCOPES_AUDIT_TRAIL ON V3_RESOURCE_SCOPES;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V3_RESOURCE_SCOPES_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V3_RESOURCE_SCOPES FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

DROP TRIGGER IF EXISTS V3_EVENTS_AUDIT_SET_V3_RESOURCES_AUDIT_TRAIL ON V3_RESOURCES;
CREATE TRIGGER V3_EVENTS_AUDIT_SET_V3_RESOURCES_AUDIT_TRAIL AFTER UPDATE OR INSERT OR DELETE ON V3_RESOURCES FOR EACH ROW EXECUTE PROCEDURE TSCUTDB_AUDIT.V3_EVENTS_AUDIT();

-- create V3_VALIDATE_RESOURCE_INSTANCE_ID func to validate resource_instance_id being added to V2_SUBSCRIPTIONS, V3_DATA_PLANES and V3_CAPABILITY_INSTANCES tables
DROP FUNCTION IF EXISTS V3_VALIDATE_RESOURCE_INSTANCE_ID() CASCADE;
CREATE FUNCTION V3_VALIDATE_RESOURCE_INSTANCE_ID()
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
                    RAISE EXCEPTION 'INVALID RESOURCE_INSTANCE_ID';
                END IF;
            END LOOP;
    END IF ;
    RETURN NEW;
END;
$FUNCTION$
;

DROP TRIGGER IF EXISTS V3_VALIDATE_RESOURCE_INSTANCE_ID_TRIGGER ON V2_SUBSCRIPTIONS;
CREATE TRIGGER V3_VALIDATE_RESOURCE_INSTANCE_ID_TRIGGER BEFORE INSERT OR UPDATE ON V2_SUBSCRIPTIONS FOR EACH ROW EXECUTE PROCEDURE V3_VALIDATE_RESOURCE_INSTANCE_ID();

DROP TRIGGER IF EXISTS V3_VALIDATE_RESOURCE_INSTANCE_ID_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VALIDATE_RESOURCE_INSTANCE_ID_TRIGGER BEFORE INSERT OR UPDATE ON V3_DATA_PLANES FOR EACH ROW EXECUTE PROCEDURE V3_VALIDATE_RESOURCE_INSTANCE_ID();

DROP TRIGGER IF EXISTS V3_VALIDATE_RESOURCE_INSTANCE_ID_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VALIDATE_RESOURCE_INSTANCE_ID_TRIGGER BEFORE INSERT OR UPDATE ON V3_CAPABILITY_INSTANCES FOR EACH ROW EXECUTE PROCEDURE V3_VALIDATE_RESOURCE_INSTANCE_ID();

-- add MONITORINGAGENT as an internal capability to v3_capability_metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('MONITORINGAGENT', '{1,0,0}', 'Monitoring Agent', 'Monitoring Agent','{"package": {"recipe": {"helmCharts": [{"name": "tp-dp-monitor-agent", "flags": {"install": true, "createNamespace": false}, "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}]}, "services": [{"name": "tp-dp-monitor-agent", "description": "Monitoring Agent Service"}], "dependsOn": [], "provisioningRoles": [], "allowMultipleInstances": false}}', 'INFRA')
ON CONFLICT DO NOTHING;

-- add FINOPSAGENT as an internal capability to v3_capability_metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('FINOPSAGENT', '{1,0,0}', 'FinOps Agent', 'FinOps Agent',
        '{"package":{"recipe":{"helmCharts":[{"name":"finops-agent","flags":{"install":true,"createnamespace":true},"values":[{"content":"ingress:\n enabled: true\n annotations:\n kubernetes.io/ingress.class: traefik\n traefik.ingress.kubernetes.io/router.entrypoints: websecure\n hosts:\n - host: app5.dp-platform.tcie.pro\n"}],"namespace":"tibco-dp","repository":{"git":{"host":"https://github.com/bsord/tetris","path":"/chart/","branch":"master"}}}]},"roles":[],"services":[],"allowMultipleInstances":false,"dependsOn":[]}}', 'INFRA')
ON CONFLICT DO NOTHING;

-- Add STORAGE resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('STORAGE','Storage','Storage Class Name','Storage Class','{"fields":[{"key":"storageClassName","name":"Storage Class Name","dataType":"string","required":true},{"key":"type","enum":["multiPod","singlePod"],"name":"Type","dataType":"string","required":false,"fieldType":"dropdown"}]}','{"aws","azure"}','PLATFORM')
ON CONFLICT DO NOTHING;

DROP TABLE V2_ARCHIVED_INVITE_HISTORY;

CREATE TABLE IF NOT EXISTS V2_ARCHIVED_INVITE_HISTORY (
    INVITE_ID VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255),
    TSC_ACCOUNT_ID VARCHAR(255) NOT NULL,
    RECEIVER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    SENDER_USER_ENTITY_ID VARCHAR(255) NOT NULL,
    REVOKED_TIME_STAMP BIGINT,
    PERMISSIONS JSONB NOT NULL,
    CREATED_TIME BIGINT NOT NULL,
    MODIFIED_TIME BIGINT,
    CREATED_BY VARCHAR(255) NOT NULL,
    MODIFIED_BY VARCHAR(255) NOT NULL,
    ALLOW_TIBCO_AUTHENTICATION BOOLEAN,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP),

    CONSTRAINT V2_ARCHIVED_INVITE_HISTORY_PKEY1 PRIMARY KEY (INVITE_ID)
    );

-- Add Flogo metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('FLOGO', '{1,0,0}', 'TIBCO Flogo', 'Flogo supports event-driven integrations, microservices, and APIs. You can run your Flogo app on TIBCO Cloud or deploy it as a function on serverless compute. Flogo apps are based on the Flogo open source project.', '{"package":{"recipe":{"helmCharts":[{"name":"flogoprovisioner","namespace":"${NAMESPACE}","version":"1.0.8","repository":{"chartMuseum":{"host":"https://syan-tibco.github.io/tp-helm-charts/"}},"values":[{"content":"global:\n  flogoprovisioner:\n    image:\n      tag: 35\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"flogoprovisioner","description":"Flogo Provisioner Service"}],"dependsOn":[{"capabilityId":"INTEGRATIONCORE","version":[1,0,0]}],"provisioningRoles":["DEV_OPS"],"capabilityResourceDependencies":[{"required":true,"resourceId":"INGRESS","type":"PLATFORM"}],"allowMultipleInstances":false}}', 'PLATFORM')
ON CONFLICT DO NOTHING;

--
-- V3_ARCHIVED_DATA_PLANES
--

CREATE TABLE IF NOT EXISTS V3_ARCHIVED_DATA_PLANES (
    DP_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    NAME VARCHAR(255) NOT NULL,
    DESCRIPTION VARCHAR(255),
    HOST_CLOUD_TYPE VARCHAR(255) NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    REGISTERED_REGION VARCHAR(255),
    RUNNING_REGION VARCHAR(255),
    CREATED_DATE BIGINT,
    MODIFIED_DATE BIGINT,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    TAGS TEXT[],
    NAMESPACES TEXT[],
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL,
    RESOURCE_INSTANCE_IDS TEXT[],
    DP_CONFIG JSONB,
    EULA BOOLEAN,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP)
);

--
-- V3_ARCHIVED_CAPABILITY_INSTANCES
--

CREATE TABLE IF NOT EXISTS V3_ARCHIVED_CAPABILITY_INSTANCES (
    CAPABILITY_ID VARCHAR(255) NOT NULL,
    DP_ID VARCHAR(255) NOT NULL,
    NAMESPACE VARCHAR(255) NOT NULL,
    VERSION int[] NOT NULL,
    STATUS VARCHAR(255) NOT NULL,
    REGION VARCHAR(255) NOT NULL,
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    TAGS TEXT[],
    CAPABILITY_INSTANCE_ID VARCHAR(255) NOT NULL DEFAULT '',
    CAPABILITY_INSTANCE_NAME VARCHAR(255),
    CAPABILITY_INSTANCE_DESCRIPTION VARCHAR(255),
    CONCRETE_RECIPE        JSONB        NOT NULL DEFAULT '{}',
    RESOURCE_INSTANCE_IDS TEXT[],
    EULA BOOLEAN,
    CAPABILITY_TYPE VARCHAR(255) NOT NULL,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP)
);

--
-- V3_ARCHIVED_APPS
--
CREATE TABLE IF NOT EXISTS V3_ARCHIVED_APPS (
    APP_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    APP_NAME VARCHAR(255) NOT NULL,
    APP_VERSION int[] NOT NULL,
    CAPABILITY_INSTANCE_ID VARCHAR(255) NOT NULL,
    CAPABILITY_ID VARCHAR(255) NOT NULL,
    CAPABILITY_VERSION int[] NOT NULL,
    DP_ID VARCHAR(255) NOT NULL,
    NAMESPACE VARCHAR(255) NOT NULL,
    STATE VARCHAR(255) NOT NULL,
    TAGS TEXT[],
    CREATED_BY VARCHAR(255),
    MODIFIED_BY VARCHAR(255),
    EULA BOOLEAN,
    ARCHIVED_TIME_STAMP BIGINT DEFAULT DATE_PART('EPOCH'::TEXT, CURRENT_TIMESTAMP)
);

--
-- V3_TAGS_AUDIT
--

CREATE TABLE IF NOT EXISTS V3_TAGS_AUDIT (
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL PRIMARY KEY,
    TAG_DETAILS JSONB
);

-- Insert TAGS Record
DROP FUNCTION IF EXISTS UPDATE_TAGS_DETAIL() CASCADE;
CREATE FUNCTION UPDATE_TAGS_DETAIL()
    RETURNS TRIGGER 
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    SUBSCRIPTION_ID_L VARCHAR(255);
	TAG_SCOPE VARCHAR(32);
	CREATED_TIME BIGINT;
	CREATED_BY TEXT;
	TAG_DETAILS_L JSONB;
	TAG_DETAILS_ELEM JSONB;
    TAG TEXT;
	EXIST BOOLEAN;
BEGIN
	IF TG_TABLE_NAME = 'v3_data_planes' THEN
		SUBSCRIPTION_ID_L := NEW.SUBSCRIPTION_ID;
		TAG_SCOPE = 'dp';
	ELSE
		SELECT SUBSCRIPTION_ID INTO SUBSCRIPTION_ID_L FROM V3_DATA_PLANES WHERE DP_ID = NEW.DP_ID;
		IF TG_TABLE_NAME = 'v3_apps' THEN
			TAG_SCOPE = 'app';
		ELSEIF TG_TABLE_NAME = 'v3_capability_instances' THEN
			TAG_SCOPE = 'capability';
		END IF;
	END IF;
	SELECT TAG_DETAILS INTO TAG_DETAILS_L FROM V3_TAGS_AUDIT WHERE SUBSCRIPTION_ID = SUBSCRIPTION_ID_L;
	
	CREATED_BY := (select coalesce(current_setting('cp.userId', true), 'platform-default'));
	CREATED_TIME := (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));

    IF TAG_DETAILS_L IS NULL THEN
		TAG_DETAILS_L = '[]'::JSONB;
		IF NEW.TAGS IS NOT NULL THEN
    		FOREACH TAG IN ARRAY NEW.TAGS
    		LOOP
				TAG_DETAILS_L = TAG_DETAILS_L || jsonb_build_object(
					'tag',TAG,
					'scope',TAG_SCOPE,
					'created_by',CREATED_BY,
					'created_time', CREATED_TIME);
    		END LOOP;
		END IF;
		INSERT INTO V3_TAGS_AUDIT (SUBSCRIPTION_ID, TAG_DETAILS) VALUES (SUBSCRIPTION_ID_L, TAG_DETAILS_L);
	ELSEIF OLD.TAGS IS NULL OR NEW.TAGS != OLD.TAGS THEN
		IF NEW.TAGS IS NOT NULL THEN
    		FOREACH TAG IN ARRAY NEW.TAGS
    		LOOP
				EXIST = false;
    			FOR TAG_DETAILS_ELEM IN SELECT jsonb_array_elements(TAG_DETAILS_L)
    			LOOP
					IF TAG = TAG_DETAILS_ELEM ->> 'tag' THEN
						EXIST = true;
						EXIT;
					END IF;
    			END LOOP;
				IF EXIST = false THEN
					TAG_DETAILS_L = TAG_DETAILS_L || jsonb_build_object(
						'tag',TAG,
						'scope',TAG_SCOPE,
						'created_by',CREATED_BY,
						'created_time', CREATED_TIME);
				END IF;
    		END LOOP;
			UPDATE V3_TAGS_AUDIT SET TAG_DETAILS = TAG_DETAILS_L WHERE SUBSCRIPTION_ID = SUBSCRIPTION_ID_L;
		END IF;
    END IF;
    RETURN NEW;
END;
$FUNCTION$;

-- ADD TRIGGER ON V3_APPS FOR POPULATING TAGS_AUDIT TABLE
DROP TRIGGER IF EXISTS POPULATE_TAG_DETAILS_TRIGGER_BY_APPS ON V3_APPS;
CREATE TRIGGER POPULATE_TAG_DETAILS_TRIGGER_BY_APPS
AFTER INSERT OR UPDATE ON V3_APPS
FOR EACH ROW
EXECUTE FUNCTION UPDATE_TAGS_DETAIL();

-- ADD TRIGGER ON V3_DATA_PLANES FOR POPULATING TAGS_AUDIT TABLE
DROP TRIGGER IF EXISTS POPULATE_TAG_DETAILS_TRIGGER_BY_DATAPLANES ON V3_DATA_PLANES;
CREATE TRIGGER POPULATE_TAG_DETAILS_TRIGGER_BY_DATAPLANES
AFTER INSERT OR UPDATE ON V3_DATA_PLANES
FOR EACH ROW
EXECUTE FUNCTION UPDATE_TAGS_DETAIL();

-- ADD TRIGGER ON V3_CAPABILITY_INSTANCES FOR POPULATING TAGS_AUDIT TABLE
DROP TRIGGER IF EXISTS POPULATE_TAG_DETAILS_TRIGGER_BY_CAPABILITY_INSTANCES ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER POPULATE_TAG_DETAILS_TRIGGER_BY_CAPABILITY_INSTANCES
AFTER INSERT OR UPDATE ON V3_CAPABILITY_INSTANCES
FOR EACH ROW
EXECUTE FUNCTION UPDATE_TAGS_DETAIL();

-- Delete TAGS Record
DROP FUNCTION IF EXISTS DELETE_TAG_DETAILS() CASCADE;
CREATE FUNCTION DELETE_TAG_DETAILS()
    RETURNS TRIGGER 
    LANGUAGE PLPGSQL
AS $FUNCTION$
BEGIN
	IF TG_TABLE_NAME = 'v2_subscriptions' THEN
        DELETE FROM V3_TAGS_AUDIT WHERE SUBSCRIPTION_ID = OLD.SUBSCRIPTION_ID;
    END IF;
    RETURN NEW;
END;
$FUNCTION$;

-- ADD TRIGGER ON V2_SUBSCRIPTIONS FOR CLEAN UP TAGS_AUDIT TABLE
DROP TRIGGER IF EXISTS DELETE_TAG_DETAILS_TRIGGER_BY_SUBSCRIPTIONS ON V2_SUBSCRIPTIONS;
CREATE TRIGGER DELETE_TAG_DETAILS_TRIGGER_BY_SUBSCRIPTIONS
AFTER DELETE ON V2_SUBSCRIPTIONS
FOR EACH ROW
EXECUTE FUNCTION DELETE_TAG_DETAILS();


-- Add O11y INFRA Capability to metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES('O11Y', '{1,0,0}', 'Observability', 'Default Observability', '{"package": {"recipe": {"helmCharts": [{"name": "o11yservice", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "global:\n  o11yservice:\n    image:\n      tag: 273\n"}], "version": "1.0.10", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-userapp\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nautoscaling:\n  enabled: false\n  minReplicas: 1\n  maxReplicas: 10\n  behavior:\n    scaleUp:\n      stabilizationWindowSeconds: 15\n    scaleDown:\n      stabilizationWindowSeconds: 15\n  targetCPUUtilizationPercentage: 80\n  targetMemoryUtilizationPercentage: 80\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nclusterRole:\n  create: false\n  name: otel-userapp-${DATAPLANE-ID}\n  rules:\n    - apiGroups:\n      - \"\"\n      resources:\n      - events\n      - namespaces\n      - namespaces/status\n      - nodes\n      - nodes/spec\n      - pods\n      - pods/status\n      - replicationcontrollers\n      - replicationcontrollers/status\n      - resourcequotas\n      - services\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - apps\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      - statefulsets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - extensions\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - autoscaling\n      resources:\n      - horizontalpodautoscalers\n      verbs:\n      - get\n      - list\n      - watch\n  clusterRoleBinding:\n    name: otel-userapp-${DATAPLANE-ID}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter: null\n    batch: {}\n    filter/devnull:\n      error_mode: ignore\n      traces:\n        span:\n          - ''name != \"\"''\n      metrics:\n        metric:\n          - ''name != \"\"''\n        datapoint:\n          - ''metric.name != \"\"''\n      logs:\n        log_record:\n          - ''IsMatch(body, \"\")''\n    memory_limiter:\n      check_interval: 5s\n      limit_percentage: 80\n      spike_limit_percentage: 25\n  exporters:\n    logging: {}\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n      metrics:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n      traces:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n"}], "version": "0.66.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-userapp"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-finops\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nclusterRole:\n  create: false\n  name: otel-finops-${DATAPLANE-ID}\n  rules:\n    - apiGroups:\n      - \"\"\n      resources:\n      - events\n      - namespaces\n      - namespaces/status\n      - nodes\n      - nodes/spec\n      - pods\n      - pods/status\n      - replicationcontrollers\n      - replicationcontrollers/status\n      - resourcequotas\n      - services\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - apps\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      - statefulsets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - extensions\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - autoscaling\n      resources:\n      - horizontalpodautoscalers\n      verbs:\n      - get\n      - list\n      - watch\n  clusterRoleBinding:\n    name: otel-finops-${DATAPLANE-ID}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    prometheus/finops:\n      config:\n        scrape_configs:\n          - job_name: ''otel-collector''\n            scrape_interval: 10s\n            static_configs:\n              - targets: [''0.0.0.0:8888'']\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      metrics:\n        exporters:\n          - logging\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - prometheus/finops\n"}], "version": "0.66.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-finops"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-services\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  annotations: {}\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - logging\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.66.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-services"}, {"name": "jaeger", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "provisionDataStore:\n  cassandra: false\n  elasticsearch: false\nstorage:\n  type: memory\nagent:\n  enabled: false\nquery:\n  fullnameOverride: jaeger-query\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  ingress:\n    enabled: true\n    ingressClassName: haproxy-dp-${DATAPLANE-ID}\n    annotations:\n      haproxy.org/cors-enable: \"true\"\n      haproxy.org/load-balance: leastconn\n      haproxy.org/src-ip-header: X-Real-IP\n      haproxy.org/timeout-http-request: 600s\n      ingress.kubernetes.io/rewrite-target: /\n      meta.helm.sh/release-name: jaeger\n    pathType: Prefix\n    hosts:\n      -\n  oAuthSidecar:\n    enabled: false\n  agentSidecar:\n    enabled: false\ncollector:\n  fullnameOverride: jaeger-collector\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  autoscaling:\n    enabled: false\n    minReplicas: 2\n    maxReplicas: 10\n    behavior:\n      targetCPUUtilizationPercentage: 80\n      targetMemoryUtilizationPercentage: 80\n  service:\n    otlp:\n      grpc:\n        name: otlp-grpc\n        port: 4317\n      http:\n        name: otlp-http\n        port: 4318\n"}], "version": "0.71.14", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://jaegertracing.github.io/helm-charts"}}, "releaseName": "jaeger"}]}, "services": [{"name": "o11yservice", "description": "o11y Service"}, {"name": "jaeger", "description": "jaeger"}, {"name": "otel-userapp", "description": "otel userapp"}, {"name": "otel-finops", "description": "otel finops"}, {"name": "otel-services", "description": "otel services"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false}}', 'INFRA')
ON CONFLICT DO NOTHING;

-- Add O11Y PLATFORM Capability to metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('O11Y','{1,0,0}','Observability','Observability With Resources','{"package": {"recipe": {"helmCharts": [{"name": "o11yservice", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "global:\n  o11yservice:\n    image:\n      tag: 273\n"}], "version": "1.0.10", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-userapp\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  prometheus.io/scrape: \"true\"\n  prometheus.io/path: \"metrics\"\n  prometheus.io/port: \"4319\"\nautoscaling:\n  enabled: false\n  minReplicas: 1\n  maxReplicas: 10\n  behavior:\n    scaleUp:\n      stabilizationWindowSeconds: 15\n    scaleDown:\n      stabilizationWindowSeconds: 15\n  targetCPUUtilizationPercentage: 80\n  targetMemoryUtilizationPercentage: 80\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nclusterRole:\n  create: false\n  name: otel-userapp-${DATAPLANE-ID}\n  rules:\n    - apiGroups:\n      - \"\"\n      resources:\n      - events\n      - namespaces\n      - namespaces/status\n      - nodes\n      - nodes/spec\n      - pods\n      - pods/status\n      - replicationcontrollers\n      - replicationcontrollers/status\n      - resourcequotas\n      - services\n      - stats/summary\n      - nodes/stats\n      - nodes/proxy\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - apps\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      - statefulsets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - extensions\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - autoscaling\n      resources:\n      - horizontalpodautoscalers\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - batch\n      resources:\n      - jobs\n      - cronjobs\n      verbs:\n      - get\n      - list\n      - watch\n  clusterRoleBinding:\n    name: otel-userapp-${DATAPLANE-ID}\nextraEnvs:\n  - name: KUBE_NODE_NAME\n    valueFrom:\n      fieldRef:\n        apiVersion: v1\n        fieldPath: spec.nodeName\nextraEnvsFrom:\n  - secretRef:\n      name: o11y-service\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n    k8s_cluster/all_settings:\n      collection_interval: 20s\n      allocatable_types_to_report: [ \"cpu\",\"memory\" ]\n      metadata_collection_interval: 30m\n    kubeletstats/user-app:\n      collection_interval: 20s\n      auth_type: \"serviceAccount\"\n      endpoint: \"https://${env:KUBE_NODE_NAME}:10250\"\n      insecure_skip_verify: true\n      metric_groups:\n        - pod\n      extra_metadata_labels:\n        - container.id\n      metrics:\n        k8s.pod.filesystem.available:\n          enabled: false\n        k8s.pod.filesystem.capacity:\n          enabled: false\n        k8s.pod.filesystem.usage:\n          enabled: false\n        k8s.pod.memory.major_page_faults:\n          enabled: false\n        k8s.pod.memory.page_faults:\n          enabled: false\n        k8s.pod.memory.rss:\n          enabled: false\n        k8s.pod.memory.working_set:\n          enabled: false\n    prometheus:\n      config:\n        scrape_configs:\n         - job_name: otel-userapp\n           scrape_interval: 10s\n           static_configs:\n           - targets:\n             - 0.0.0.0:8888\n         - job_name: k8s\n           kubernetes_sd_configs:\n           - role: pod\n           metric_relabel_configs:\n           - action: keep\n             regex: (request_duration_seconds.*|response_duration_seconds.*)\n             source_labels:\n             - __name__\n           relabel_configs:\n           - action: keep\n             regex: \"true\"\n             source_labels:\n             - __meta_kubernetes_pod_annotation_prometheus_io_scrape\n         - job_name: monitoring-agent\n           kubernetes_sd_configs:\n           - role: service\n           relabel_configs:\n           - source_labels: [__meta_kubernetes_service_label_prometheus_io_scrape]\n             regex: \"true\"\n             action: keep\n           - action: keepequal\n             source_labels: [__meta_kubernetes_service_port_number]\n             target_label: __meta_kubernetes_service_annotation_prometheus_io_port\n           - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]\n             action: replace\n             target_label: __metrics_path__\n             regex: (.+)\n         - job_name: envoy-stats\n           metrics_path: /stats/prometheus\n           kubernetes_sd_configs:\n           - role: pod\n           relabel_configs:\n           - source_labels:\n             - __meta_kubernetes_pod_container_port_name\n             action: keep\n             regex: ''.*-envoy-prom''\n  processors:\n    memory_limiter:\n      check_interval: 5s\n      limit_percentage: 80\n      spike_limit_percentage: 25\n    k8sattributes/log:\n      auth_type: \"serviceAccount\"\n      passthrough: false\n      extract:\n        metadata:\n          - k8s.pod.name\n          - k8s.pod.uid\n          - k8s.namespace.name\n        labels:\n          - tag_name: app_id\n            key: platform.tibco.com/app-id\n            from: pod\n          - tag_name: app_type\n            key: platform.tibco.com/app-type\n            from: pod\n          - tag_name: dataplane_id\n            key: platform.tibco.com/dataplane-id\n            from: pod\n          - tag_name: workload_type\n            key: platform.tibco.com/workload-type\n            from: pod\n        annotations:\n          - tag_name: app_tag\n            key: platform.tibco.com/app-tag\n            from: pod\n    k8sattributes:\n      auth_type: \"serviceAccount\"\n      passthrough: false\n      extract:\n        metadata:\n          - k8s.pod.name\n          - k8s.pod.uid\n          - k8s.namespace.name\n        labels:\n          - tag_name: app_id\n            key: platform.tibco.com/app-id\n            from: pod\n          - tag_name: app_type\n            key: platform.tibco.com/app-type\n            from: pod\n          - tag_name: dataplane_id\n            key: platform.tibco.com/dataplane-id\n            from: pod\n          - tag_name: workload_type\n            key: platform.tibco.com/workload-type\n            from: pod\n        annotations:\n          - tag_name: app_tag\n            key: platform.tibco.com/app-tag\n            from: pod\n          - tag_name: limits_cpu\n            key: platform.tibco.com/app.resources.limits.cpu\n            from: pod\n          - tag_name: limits_mem\n            key: platform.tibco.com/app.resources.limits.memory\n            from: pod\n          - tag_name: requests_cpu\n            key: platform.tibco.com/app.resources.requests.cpu\n            from: pod\n          - tag_name: requests_mem\n            key: platform.tibco.com/app.resources.requests.memory\n            from: pod\n      pod_association:\n        - sources:\n            - from: resource_attribute\n              name: k8s.pod.uid\n    filter/user-app:\n      metrics:\n        include:\n          match_type: strict\n          resource_attributes:\n            - key: workload_type\n              value: user-app\n    transform:\n      metric_statements:\n      - context: datapoint\n        statements:\n          - set(attributes[\"pod_name\"], resource.attributes[\"k8s.pod.name\"])\n          - set(attributes[\"pod_namespace\"], resource.attributes[\"k8s.namespace.name\"])\n          - set(attributes[\"app_id\"], resource.attributes[\"app_id\"])\n          - set(attributes[\"app_type\"], resource.attributes[\"app_type\"])\n          - set(attributes[\"dataplane_id\"], resource.attributes[\"dataplane_id\"])\n          - set(attributes[\"workload_type\"], resource.attributes[\"workload_type\"])\n          - set(attributes[\"app_tag\"], resource.attributes[\"app_tag\"])\n    filter/include:\n      metrics:\n        include:\n          match_type: regexp\n          metric_names:\n            - .*memory.*\n            - .*cpu.*\n  exporters:\n    elasticsearch/log:\n      endpoints:\n      - ${env:ES_SERVER_EXPORTER_ENDPOINT}\n      logs_index: ${env:ES_EXPORTER_LOG_INDEX_NAME}\n      user: ${env:ES_EXPORTER_LOG_INDEX_USERNAME}\n      password: ${env:ES_EXPORTER_LOG_INDEX_PASSWORD}\n      retry:\n        enabled: false\n      tls:\n        insecure: false\n        insecure_skip_verify: true\n    otlp/trace:\n      endpoint: ${env:JAEGER_COLLECTOR_ENDPOINT}\n      tls:\n        insecure: true\n    prometheus/user:\n      endpoint: 0.0.0.0:4319\n      enable_open_metrics: true\n      resource_to_telemetry_conversion:\n        enabled: true\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - elasticsearch/log\n        processors:\n          - k8sattributes/log\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n      metrics:\n        exporters:\n          - prometheus/user\n        processors:\n          - k8sattributes\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n          - prometheus\n      metrics/user-apps:\n        receivers:\n          - kubeletstats/user-app\n          - k8s_cluster/all_settings\n        processors:\n          - k8sattributes\n          - filter/user-app\n          - filter/include\n          - transform\n          - batch\n        exporters:\n          - prometheus/user\n      traces:\n        exporters:\n          - otlp/trace\n        processors:\n          - k8sattributes\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.67.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-userapp"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-finops\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nclusterRole:\n  create: false\n  name: otel-finops-${DATAPLANE-ID}\n  rules:\n    - apiGroups:\n      - \"\"\n      resources:\n      - events\n      - namespaces\n      - namespaces/status\n      - nodes\n      - nodes/spec\n      - pods\n      - pods/status\n      - replicationcontrollers\n      - replicationcontrollers/status\n      - resourcequotas\n      - services\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - apps\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      - statefulsets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - extensions\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - autoscaling\n      resources:\n      - horizontalpodautoscalers\n      verbs:\n      - get\n      - list\n      - watch\n  clusterRoleBinding:\n    name: otel-finops-${DATAPLANE-ID}\nextraEnvsFrom:\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    prometheus/finops:\n      config:\n        scrape_configs:\n          - job_name: ''otel-collector''\n            scrape_interval: 10s\n            static_configs:\n              - targets: [''0.0.0.0:8888'']\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n    otlp/finops:\n      endpoint: ${env:FINOPS_OTLP_COLLECTOR_ENDPOINT}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      metrics:\n        exporters:\n          - otlp/finops\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - prometheus/finops\n"}], "version": "0.67.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-finops"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-services\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nclusterRole:\n  create: false\n  name: otel-services-${DATAPLANE-ID}\n  rules:\n    - apiGroups:\n      - \"\"\n      resources:\n      - events\n      - namespaces\n      - namespaces/status\n      - nodes\n      - nodes/spec\n      - pods\n      - pods/status\n      - replicationcontrollers\n      - replicationcontrollers/status\n      - resourcequotas\n      - services\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - apps\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      - statefulsets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - extensions\n      resources:\n      - daemonsets\n      - deployments\n      - replicasets\n      verbs:\n      - get\n      - list\n      - watch\n    - apiGroups:\n      - autoscaling\n      resources:\n      - horizontalpodautoscalers\n      verbs:\n      - get\n      - list\n      - watch\n  clusterRoleBinding:\n    name: otel-services-${DATAPLANE-ID}\nextraEnvsFrom:\n  - secretRef:\n      name: o11y-service\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    elasticsearch/log:\n      endpoints:\n      - ${env:ES_SERVER_SERVICE_ENDPOINT}\n      logs_index: ${env:ES_SERVICE_LOG_INDEX_NAME}\n      user: ${env:ES_SERVICE_LOG_INDEX_USERNAME}\n      password: ${env:ES_SERVICE_LOG_INDEX_PASSWORD}\n      retry:\n        enabled: false\n      tls:\n        insecure: false\n        insecure_skip_verify: true\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - elasticsearch/log\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.67.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-services"}, {"name": "jaeger", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "provisionDataStore:\n  cassandra: false\n  elasticsearch: false\nstorage:\n  type: elasticsearch\n  elasticsearch:\n    version: 7\n    host: ${ES-SERVER-HOST}\n    port: ${ES-SERVER-PORT}\n    scheme: https\n    user: ${ES-SERVER-USERNAME}\n    password: ${ES-SERVER-PASSWORD}\n    tags-as-fields:\n      all: true\n    tls:\n      secretName: jaeger-elasticsearch\nagent:\n  enabled: false\nquery:\n  fullnameOverride: jaeger-query\n  basePath: /tibco/agent/o11y/${INSTANCE-ID}/jaeger/\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  ingress:\n    enabled: true\n    ingressClassName: haproxy-dp-${DATAPLANE-ID}\n    annotations:\n      haproxy.org/cors-enable: \"true\"\n      haproxy.org/load-balance: leastconn\n      haproxy.org/src-ip-header: X-Real-IP\n      haproxy.org/timeout-http-request: 600s\n      ingress.kubernetes.io/rewrite-target: /\n      meta.helm.sh/release-name: jaeger\n    pathType: Prefix\n    hosts:\n      -\n  oAuthSidecar:\n    enabled: false\n  agentSidecar:\n    enabled: false\n  cmdlineParams:\n    es.tls.enabled: true\n    es.tls.skip-host-verify: true\ncollector:\n  fullnameOverride: jaeger-collector\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  autoscaling:\n    enabled: false\n    minReplicas: 2\n    maxReplicas: 10\n    behavior:\n      targetCPUUtilizationPercentage: 80\n      targetMemoryUtilizationPercentage: 80\n  cmdlineParams:\n    es.tls.enabled: true\n    es.tls.skip-host-verify: true\n  service:\n    otlp:\n      grpc:\n        name: otlp-grpc\n        port: 4317\n      http:\n        name: otlp-http\n        port: 4318\n"}], "version": "0.71.14", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://jaegertracing.github.io/helm-charts"}}, "releaseName": "jaeger"}]}, "services": [{"name": "o11yservice", "description": "o11y Service"}, {"name": "jaeger", "description": "jaeger"}, {"name": "otel-userapp", "description": "otel userapp"}, {"name": "otel-finops", "description": "otel finops"}, {"name": "otel-services", "description": "otel services"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false, "capabilityResourceDependencies": [{"type": "PLATFORM", "required": true, "resourceId": "O11Y"}]}}','PLATFORM')
ON CONFLICT DO NOTHING;

-- Add O11Y Platform Capability resources
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('O11Y','Observability Resources','Observability Resources Name','Observability','{"fields":[{"name":"User App Log Index","key":"logserver.userapp.logindex","dataType":"string","required":true},{"name":"User App Trace Index","key":"logserver.userapp.traceindex","dataType":"string","required":true},{"name":"Services Log Index","key":"logserver.services.logindex","dataType":"string","required":true},{"name":"Proxy User App Log Index Endpoint","key":"logserver.proxy.userapp.logindex.endpoint","dataType":"string","required":true},{"name":"Proxy User App Log Index Username","key":"logserver.proxy.userapp.logindex.username","dataType":"string","required":true},{"name":"Exporter User App LogINdex Endpoint","key":"logserver.exporter.userapp.logindex.endpoint","dataType":"string","required":true},{"name":"Exporter User App Log Index Username","key":"logserver.exporter.userapp.logindex.username","dataType":"string","required":true},{"name":"Exporter Services Log Index Username","key":"logserver.exporter.services.logindex.username","dataType":"string","required":true},{"name":"Exporter Services Log Index Endpoint","key":"logserver.exporter.services.logindex.endpoint","dataType":"string","required":true},{"name":"Proxy Endpoint","key":"promserver.proxy.endpoint","dataType":"string","required":true},{"name":"Proxy Username","key":"promserver.proxy.username","dataType":"string","required":true},{"name":"Exporter Endpoint","key":"promserver.exporter.endpoint","dataType":"string","required":true},{"name":"Elastic Search Host","key":"jaeger.es.host","dataType":"string","required":true},{"name":"Elastic Search port","key":"jaeger.es.port","dataType":"string","required":true},{"name":"Elastic Search Username","key":"jaeger.es.username","dataType":"string","required":true},{"name":"User App Proxy Password","key":"secret.logserver.userapp.proxy.password","dataType":"string","required":true},{"name":"User App ExporterPassword","key":"secret.logserver.userapp.exporter.password","dataType":"string","required":true},{"name":"Services Exporter Password","key":"secret.logserver.services.exporter.password","dataType":"string","required":true},{"name":"Proxy Password","key":"secret.promserver.proxy.password","dataType":"string","required":true},{"name":"Exporter Token","key":"secret.promserver.exporter.token","dataType":"string","required":true},{"name":"Elastic Search Password","key":"secret.jaeger.es.password","dataType":"string","required":true}]}','{"aws","azure"}','PLATFORM')
ON CONFLICT DO NOTHING;

-- Add INTEGRATIONCORE capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('INTEGRATIONCORE', '{1,0,0}', 'Integration Core', 'Integration Core', '{"package": {"recipe": {"helmCharts": [{"name": "artifactmanager", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "global:\n  artifactmanager:\n    image:\n      tag: 26\n"}], "version": "1.0.7", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}, {"name": "distributed-lock-operator", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "global:\n  distlockop:\n    image:\n      tag: 58\n"}], "version": "1.0.3", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}]}, "services": [{"name": "artifactmanager", "description": "Artifact Manager"}, {"name": "distributed-lock-operator", "description": "Distributed Lock Operator"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false, "capabilityResourceDependencies": [{"type": "INFRA", "required": true, "resourceId": "STORAGE"}]}}', 'INFRA')
ON CONFLICT DO NOTHING;

-- Add EMS details into capability metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE)
VALUES ('EMS','{1,0,0}','TIBCO Enterprise Message Service™','TIBCO Enterprise Message Service (EMS) allows you to send messages from your applications in a format that conforms to the Jakarta Messaging (JMS) specification. The software also extends the JMS specification with a reliable delivery mode and a no-acknowledge acknowledgement mode.','{"package":{"allowMultipleInstances":true,"capabilityResourceDependencies":[{"required":false,"resourceId":"STORAGE","type":"PLATFORM"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"recipe":{"helmCharts":[{"flags":{"createNamespace":false,"install":true},"name":"dp-ems-on-ftl","namespace":"${NAMESPACE}","releaseName":"${EMS_NAME}","repository":{"chartMuseum":{"host":"https://syan-tibco.github.io/tp-helm-charts/"}},"values":[{"content":"global: {}\nems: \n  name: ${EMS_NAME}\n  sizing: ${EMS_SIZE}\n  use: ${EMS_USE}\n"}],"version":"1.0.4"}]},"services":[{"description":"EMS Service","name":"ems"}]}}')
ON CONFLICT DO NOTHING;

-- Update v3_resource table's primary key from (resource_id) to (resource_id, resource_level)
ALTER TABLE v3_resources DROP CONSTRAINT IF EXISTS v3_resources_pkey CASCADE;
ALTER TABLE v3_resources ADD PRIMARY KEY (resource_id, resource_level);

-- Insert SERVICEACCOUNT INFRA resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('SERVICEACCOUNT','Infra Service Account','Infra Service Account','Service Account','{"fields":[{"name":"Service Account","key":"serviceAccountName","dataType":"string","required":true},{"name":"Namespace","key":"namespace","dataType":"string","required":true}]}','{"aws","azure"}', 'INFRA')
ON CONFLICT DO NOTHING;

-- Insert SERVICEACCOUNT PLATFORM resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('SERVICEACCOUNT','Platform Service Account','Platform Service Account','Service Account','{"fields":[{"name":"Service Account","key":"serviceAccountName","dataType":"string","required":true},{"name":"Namespace","key":"namespace","dataType":"string","required":true}]}','{"aws","azure"}', 'PLATFORM')
ON CONFLICT DO NOTHING;

-- Add capability_id column to v3_resource_instances
ALTER TABLE V3_RESOURCE_INSTANCES ADD COLUMN IF NOT EXISTS CAPABILITY_ID TEXT[];

-- Insert STORAGE INFRA resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('STORAGE','Storage','Storage Class Name','Storage Class','{"fields":[{"name":"Storage Class Name","key":"storageClassName","dataType":"string","required":true}]}','{"aws","azure"}', 'INFRA')
ON CONFLICT DO NOTHING;

-- Insert Service Mesh capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('ISTIO', '{1,0,0}', 'Service Mesh', 'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum is simply dummy text of the printing and typesetting industry.', '{"package":{"allowMultipleInstances":false,"capabilityResourceDependencies":[],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"recipe":{"helmCharts":[{"name":"istio-crd","namespace":"istio-system","version":"1.16.1","repository":{"chartMuseum":{"host":"http://94.43.70.34.bc.googleusercontent.com:8879"}},"flags":{"install":true,"createNamespace":true}},{"name":"istio-istiod","namespace":"istio-system","version":"1.16.1","repository":{"chartMuseum":{"host":"http://94.43.70.34.bc.googleusercontent.com:8879"}},"values":[{"content":"pilot:\n  autoscaleEnabled: true\n  autoscaleMin: 1\n  autoscaleMax: 5\n  replicaCount: 1\nglobal:\n  istioNamespace: istio-system\n  defaultResources:\n    requests:\n      cpu: 250m\n      memory: 256Mi\n    limits:\n      cpu: 750m\n      memory: 512Mi\n  proxy:\n    tracer: zipkin\n    requests:\n      cpu: 100m\n      memory: 256Mi\n    limits:\n      cpu: 500m\n      memory: 512Mi\n  tracer:\n    zipkin:\n      address: zipkin.istio-aom.svc.cluster.local:9411       \nmeshConfig:\n  accessLogFile: /dev/stdout\ndefaultConfig:\n  tracing:\n    sampling: 10        \ndefaultProviders:\n  tracing: [\"traceCollector\"]\n  accessLogging: [\"logCollector\"]                \nextensionProviders:\n  - name: logCollector\n    envoyOtelAls:\n      service: opentelemetry-collector.istio-system.svc.cluster.local\n      port: 4318\n      logName: \"istio_envoy_accesslog\"\n  - name: traceCollector\n    opentelemetry:\n      service: opentelemetry-collector.istio-system.svc.cluster.local\n      port: 4317           \nmembers: [backend]        \n"}],"flags":{"install":true,"createNamespace":true}}]},"services":[{"description":"istio crd","name":"istio-crd"},{"description":"istiod","name":"istio-istiod"}]}}', 'PLATFORM')
ON CONFLICT DO NOTHING;

-- Add INGRESS PLATFORM resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('INGRESS','Ingress Controller','Ingress Controller','Ingress Controller','{"fields":[{"name":"Ingress Class Name","key":"ingressClassName","dataType":"string","required":true},{"name":"Ingress Controller","key":"ingressController","dataType":"string","fieldType":"dropdown","enum":["nginx"],"required":true},{"name":"FQDN","key":"fqdn","dataType":"string","required":true}]}','{"aws","azure"}','PLATFORM')
ON CONFLICT DO NOTHING;

-- ADD CPPROXY INFRA capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('CPPROXY', '{1,0,0}', 'CP Proxy', 'CP Proxy', '{"package":{"recipe":{"helmCharts":[{"name":"tp-cp-proxy","flags":{"install":true},"namespace":"${NAMESPACE}","repository":{"chartMuseum":{"host":"https://syan-tibco.github.io/tp-helm-charts"}}}]},"services":[{"name":"tp-cp-proxy","description":"cp proxy"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[]}}', 'INFRA')
ON CONFLICT DO NOTHING;

INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('OAUTH2PROXY','{1,0,0}','OAuth2 Proxy','OAuth2 Proxy infra sidecar','{"package":{"recipe":{"helmCharts":[{"name":"oauth2-proxy","namespace":"${NAMESPACE}","version":"6.17.0-tibx-3","repository":{"chartMuseum":{"host":"https://syan-tibco.github.io/tp-helm-charts/"}},"values":[{"content":"global:     #global section can be removed once CP is having these values passed down through capability\n  cp:\n    cpHostName: \"${CP_HOST_NAME}\"\n    instanceId: \"${CP_CAPABILITY_INSTANCE_ID}\"\n    capability:\n      pathPrefix: \"${CAPABILITY_PATH_PREFIX}\"\n    resources:\n      ingress:\n        fqdn: \"${INGRESS_FQDN}\"\n        ingressClassName: \"${INGRESS_CLASSNAME}\"\n        secrets:\n          iat: \"${SECRETS_IAT}\"\nserviceAccount:\n  enabled: false\n  name: ${SERVICE_ACCOUNT_NAME}   #CP global var? \nimage:\n  repository: \"${IMAGE_REPOSITORY}/stratosphere/oauth2-proxy-tibx\"\n  tag: \"v7.4.0-tibx-1\"\nconfig:\n  existingSecret: \"oauth2proxy-${CP_CAPABILITY_INSTANCE_ID}\" ### can be the release name to make it unique\nextraArgs:\n  oidc-issuer-url: \"https://${CP_HOST_NAME}\"\n  cookie-path: ${CAPABILITY_PATH_PREFIX}      ### ${global.cp.capability.pathPrefix}\n  proxy-prefix: ${CAPABILITY_PATH_PREFIX}/oauth2   ### ${global.cp.capability.pathPrefix}/oauth2\ningress:\n  className: ${INGRESS_CLASSNAME} ### ${global.cp.resources.ingress.ingressClassName}\n  hosts: \n    - ${INGRESS_FQDN} ### ${global.cp.resources.ingress.fqdn}\n  path: \"${CAPABILITY_PATH_PREFIX}/oauth2\" ### ${global.cp.capability.pathPrefix}/oauth2\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]}}}','INFRA_SIDECAR')
ON CONFLICT DO NOTHING;

-- UPDATE O11Y INFRA
UPDATE v3_capability_metadata
SET display_name='Observability', description='Default Observability', package='{"package": {"recipe": {"helmCharts": [{"name": "o11yservice", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "global:\n  o11yservice:\n    image:\n      tag: 304\n"}], "version": "1.0.15", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-userapp\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nautoscaling:\n  enabled: false\n  minReplicas: 1\n  maxReplicas: 10\n  behavior:\n    scaleUp:\n      stabilizationWindowSeconds: 15\n    scaleDown:\n      stabilizationWindowSeconds: 15\n  targetCPUUtilizationPercentage: 80\n  targetMemoryUtilizationPercentage: 80\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter: null\n    batch: {}\n    filter/devnull:\n      error_mode: ignore\n      traces:\n        span:\n          - ''name != \"\"''\n      metrics:\n        metric:\n          - ''name != \"\"''\n        datapoint:\n          - ''metric.name != \"\"''\n      logs:\n        log_record:\n          - ''IsMatch(body, \"\")''\n    memory_limiter:\n      check_interval: 5s\n      limit_percentage: 80\n      spike_limit_percentage: 25\n  exporters:\n    logging: {}\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n      metrics:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n      traces:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n"}], "version": "0.66.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-userapp"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-finops\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    prometheus/finops:\n      config:\n        scrape_configs:\n          - job_name: ''otel-collector''\n            scrape_interval: 10s\n            static_configs:\n              - targets: [''0.0.0.0:8888'']\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      metrics:\n        exporters:\n          - logging\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - prometheus/finops\n"}], "version": "0.66.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-finops"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-services\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  annotations: {}\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - logging\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.66.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-services"}, {"name": "jaeger", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "provisionDataStore:\n  cassandra: false\n  elasticsearch: false\nstorage:\n  type: memory\nagent:\n  enabled: false\nquery:\n  fullnameOverride: jaeger-query\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  ingress:\n    enabled: true\n    ingressClassName: haproxy-dp-${DATAPLANE-ID}\n    annotations:\n      haproxy.org/cors-enable: \"true\"\n      haproxy.org/load-balance: leastconn\n      haproxy.org/src-ip-header: X-Real-IP\n      haproxy.org/timeout-http-request: 600s\n      ingress.kubernetes.io/rewrite-target: /\n      meta.helm.sh/release-name: jaeger\n    pathType: Prefix\n    hosts:\n      -\n  oAuthSidecar:\n    enabled: false\n  agentSidecar:\n    enabled: false\ncollector:\n  fullnameOverride: jaeger-collector\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  autoscaling:\n    enabled: false\n    minReplicas: 2\n    maxReplicas: 10\n    behavior:\n      targetCPUUtilizationPercentage: 80\n      targetMemoryUtilizationPercentage: 80\n  service:\n    otlp:\n      grpc:\n        name: otlp-grpc\n        port: 4317\n      http:\n        name: otlp-http\n        port: 4318\n"}], "version": "0.71.14", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://jaegertracing.github.io/helm-charts"}}, "releaseName": "jaeger"}]}, "services": [{"name": "o11yservice", "description": "o11y Service"}, {"name": "jaeger", "description": "jaeger"}, {"name": "otel-userapp", "description": "otel userapp"}, {"name": "otel-finops", "description": "otel finops"}, {"name": "otel-services", "description": "otel services"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false}}'
WHERE capability_id='O11Y' AND "version"='{1,0,0}' AND capability_type='INFRA';

-- UPDATE O11Y PLATFORM
UPDATE v3_capability_metadata
SET display_name='Observability', description='Observability With Resources', package='{"package": {"recipe": {"helmCharts": [{"name": "o11yservice", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "global:\n  o11yservice:\n    image:\n      tag: 304\n"}], "version": "1.0.15", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://syan-tibco.github.io/tp-helm-charts/"}}}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-userapp\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  prometheus.io/scrape: \"true\"\n  prometheus.io/path: \"metrics\"\n  prometheus.io/port: \"4319\"\nautoscaling:\n  enabled: false\n  minReplicas: 1\n  maxReplicas: 10\n  behavior:\n    scaleUp:\n      stabilizationWindowSeconds: 15\n    scaleDown:\n      stabilizationWindowSeconds: 15\n  targetCPUUtilizationPercentage: 80\n  targetMemoryUtilizationPercentage: 80\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nextraEnvs:\n  - name: KUBE_NODE_NAME\n    valueFrom:\n      fieldRef:\n        apiVersion: v1\n        fieldPath: spec.nodeName\nextraEnvsFrom:\n  - secretRef:\n      name: o11y-service\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n    k8s_cluster/all_settings:\n      collection_interval: 20s\n      allocatable_types_to_report: [ \"cpu\",\"memory\" ]\n      metadata_collection_interval: 30m\n    kubeletstats/user-app:\n      collection_interval: 20s\n      auth_type: \"serviceAccount\"\n      endpoint: \"https://${env:KUBE_NODE_NAME}:10250\"\n      insecure_skip_verify: true\n      metric_groups:\n        - pod\n      extra_metadata_labels:\n        - container.id\n      metrics:\n        k8s.pod.filesystem.available:\n          enabled: false\n        k8s.pod.filesystem.capacity:\n          enabled: false\n        k8s.pod.filesystem.usage:\n          enabled: false\n        k8s.pod.memory.major_page_faults:\n          enabled: false\n        k8s.pod.memory.page_faults:\n          enabled: false\n        k8s.pod.memory.rss:\n          enabled: false\n        k8s.pod.memory.working_set:\n          enabled: false\n    prometheus:\n      config:\n        scrape_configs:\n         - job_name: monitoring-agent\n           scrape_interval: 20s\n           kubernetes_sd_configs:\n           - role: service\n           relabel_configs:\n           - action: keep\n             source_labels: [__meta_kubernetes_service_label_prometheus_io_scrape]\n             regex: \"true\"\n           - action: keep\n             source_labels: [__meta_kubernetes_service_label_platform_tibco_com_dataplane_id]\n             regex: \"${DATAPLANE-ID}\"\n           - action: replace\n             source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]\n             target_label: __metrics_path__\n             regex: (.+)\n         - job_name: envoy-stats\n           scrape_interval: 20s\n           kubernetes_sd_configs:\n           - role: pod\n           relabel_configs:\n           - action: keep\n             source_labels: [__meta_kubernetes_pod_label_prometheus_io_scrape]\n             regex: \"true\"\n           - action: keep\n             source_labels: [__meta_kubernetes_pod_container_port_name]\n             regex: \".*-envoy-prom\"\n           - action: keep\n             source_labels: [__meta_kubernetes_pod_label_platform_tibco_com_dataplane_id]\n             regex: \"${DATAPLANE-ID}\"\n           - action: replace\n             source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]\n             target_label: __metrics_path__\n             regex: (.+)\n  processors:\n    memory_limiter:\n      check_interval: 5s\n      limit_percentage: 80\n      spike_limit_percentage: 25\n    k8sattributes/general:\n      auth_type: \"serviceAccount\"\n      passthrough: false\n      extract:\n        metadata:\n          - k8s.pod.name\n          - k8s.pod.uid\n          - k8s.namespace.name\n        labels:\n          - tag_name: app_id\n            key: platform.tibco.com/app-id\n            from: pod\n          - tag_name: app_type\n            key: platform.tibco.com/app-type\n            from: pod\n          - tag_name: dataplane_id\n            key: platform.tibco.com/dataplane-id\n            from: pod\n          - tag_name: workload_type\n            key: platform.tibco.com/workload-type\n            from: pod\n        annotations:\n          - tag_name: app_tag\n            key: platform.tibco.com/app-tag\n            from: pod\n    k8sattributes/kubeletstats:\n      auth_type: \"serviceAccount\"\n      passthrough: false\n      extract:\n        metadata:\n          - k8s.pod.name\n          - k8s.pod.uid\n          - k8s.namespace.name\n        labels:\n          - tag_name: app_id\n            key: platform.tibco.com/app-id\n            from: pod\n          - tag_name: app_type\n            key: platform.tibco.com/app-type\n            from: pod\n          - tag_name: dataplane_id\n            key: platform.tibco.com/dataplane-id\n            from: pod\n          - tag_name: workload_type\n            key: platform.tibco.com/workload-type\n            from: pod\n        annotations:\n          - tag_name: app_tag\n            key: platform.tibco.com/app-tag\n            from: pod\n          - tag_name: limits_cpu\n            key: platform.tibco.com/app.resources.limits.cpu\n            from: pod\n          - tag_name: limits_mem\n            key: platform.tibco.com/app.resources.limits.memory\n            from: pod\n          - tag_name: requests_cpu\n            key: platform.tibco.com/app.resources.requests.cpu\n            from: pod\n          - tag_name: requests_mem\n            key: platform.tibco.com/app.resources.requests.memory\n            from: pod\n      pod_association:\n        - sources:\n            - from: resource_attribute\n              name: k8s.pod.uid\n    filter/user-app:\n      metrics:\n        include:\n          match_type: strict\n          resource_attributes:\n            - key: workload_type\n              value: user-app\n    transform:\n      metric_statements:\n      - context: datapoint\n        statements:\n          - set(attributes[\"pod_name\"], resource.attributes[\"k8s.pod.name\"])\n          - set(attributes[\"pod_namespace\"], resource.attributes[\"k8s.namespace.name\"])\n          - set(attributes[\"app_id\"], resource.attributes[\"app_id\"])\n          - set(attributes[\"app_type\"], resource.attributes[\"app_type\"])\n          - set(attributes[\"dataplane_id\"], resource.attributes[\"dataplane_id\"])\n          - set(attributes[\"workload_type\"], resource.attributes[\"workload_type\"])\n          - set(attributes[\"app_tag\"], resource.attributes[\"app_tag\"])\n    filter/include:\n      metrics:\n        include:\n          match_type: regexp\n          metric_names:\n            - .*memory.*\n            - .*cpu.*\n  exporters:\n    elasticsearch/log:\n      endpoints:\n      - ${env:ES_SERVER_EXPORTER_ENDPOINT}\n      logs_index: ${env:ES_EXPORTER_LOG_INDEX_NAME}\n      user: ${env:ES_EXPORTER_LOG_INDEX_USERNAME}\n      password: ${env:ES_EXPORTER_LOG_INDEX_PASSWORD}\n      retry:\n        enabled: false\n      tls:\n        insecure: false\n        insecure_skip_verify: true\n    otlp/trace:\n      endpoint: ${env:JAEGER_COLLECTOR_ENDPOINT}\n      tls:\n        insecure: true\n    prometheus/user:\n      endpoint: 0.0.0.0:4319\n      enable_open_metrics: true\n      resource_to_telemetry_conversion:\n        enabled: true\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        receivers:\n          - otlp\n        processors:\n          - k8sattributes/general\n          - memory_limiter\n          - batch\n        exporters:\n          - elasticsearch/log\n      metrics/kubeletstats:\n        receivers:\n          - kubeletstats/user-app\n          - k8s_cluster/all_settings\n        processors:\n          - k8sattributes/kubeletstats\n          - filter/user-app\n          - filter/include\n          - transform\n          - batch\n        exporters:\n          - prometheus/user\n      metrics/appengines:\n        receivers:\n          - otlp\n          - prometheus\n        processors:\n          - k8sattributes/general\n          - memory_limiter\n          - batch\n        exporters:\n          - prometheus/user\n      traces:\n        receivers:\n          - otlp\n        processors:\n          - k8sattributes/general\n          - memory_limiter\n          - batch\n        exporters:\n          - otlp/trace\n"}], "version": "0.67.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-userapp"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-finops\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nextraEnvsFrom:\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    prometheus/finops:\n      config:\n        scrape_configs:\n          - job_name: ''otel-collector''\n            scrape_interval: 10s\n            static_configs:\n              - targets: [''0.0.0.0:8888'']\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n    otlp/finops:\n      endpoint: ${env:FINOPS_OTLP_COLLECTOR_ENDPOINT}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      metrics:\n        exporters:\n          - otlp/finops\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - prometheus/finops\n"}], "version": "0.67.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-finops"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-services\npodLabels:\n  platform.tibco.com/workload-type: \"infra\"\n  platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n  platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nextraEnvsFrom:\n  - secretRef:\n      name: o11y-service\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    elasticsearch/log:\n      endpoints:\n      - ${env:ES_SERVER_SERVICE_ENDPOINT}\n      logs_index: ${env:ES_SERVICE_LOG_INDEX_NAME}\n      user: ${env:ES_SERVICE_LOG_INDEX_USERNAME}\n      password: ${env:ES_SERVICE_LOG_INDEX_PASSWORD}\n      retry:\n        enabled: false\n      tls:\n        insecure: false\n        insecure_skip_verify: true\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - elasticsearch/log\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.67.0", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://open-telemetry.github.io/opentelemetry-helm-charts"}}, "releaseName": "otel-services"}, {"name": "jaeger", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "provisionDataStore:\n  cassandra: false\n  elasticsearch: false\nstorage:\n  type: elasticsearch\n  elasticsearch:\n    version: 7\n    host: ${ES-SERVER-HOST}\n    port: ${ES-SERVER-PORT}\n    scheme: https\n    user: ${ES-SERVER-USERNAME}\n    password: ${ES-SERVER-PASSWORD}\n    tags-as-fields:\n      all: true\n    tls:\n      secretName: jaeger-elasticsearch\nagent:\n  enabled: false\nquery:\n  fullnameOverride: jaeger-query\n  basePath: /tibco/agent/o11y/${INSTANCE-ID}/jaeger/\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  ingress:\n    enabled: true\n    ingressClassName: haproxy-dp-${DATAPLANE-ID}\n    annotations:\n      haproxy.org/cors-enable: \"true\"\n      haproxy.org/load-balance: leastconn\n      haproxy.org/src-ip-header: X-Real-IP\n      haproxy.org/timeout-http-request: 600s\n      ingress.kubernetes.io/rewrite-target: /\n      meta.helm.sh/release-name: jaeger\n    pathType: Prefix\n    hosts:\n      -\n  oAuthSidecar:\n    enabled: false\n  agentSidecar:\n    enabled: false\n  cmdlineParams:\n    es.tls.enabled: true\n    es.tls.skip-host-verify: true\ncollector:\n  fullnameOverride: jaeger-collector\n  podLabels:\n    platform.tibco.com/workload-type: \"infra\"\n    platform.tibco.com/dataplane-id: ${DATAPLANE-ID}\n    platform.tibco.com/capability-instance-id: ${INSTANCE-ID}\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  autoscaling:\n    enabled: false\n    minReplicas: 2\n    maxReplicas: 10\n    behavior:\n      targetCPUUtilizationPercentage: 80\n      targetMemoryUtilizationPercentage: 80\n  cmdlineParams:\n    es.tls.enabled: true\n    es.tls.skip-host-verify: true\n  service:\n    otlp:\n      grpc:\n        name: otlp-grpc\n        port: 4317\n      http:\n        name: otlp-http\n        port: 4318\n"}], "version": "0.71.14", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "https://jaegertracing.github.io/helm-charts"}}, "releaseName": "jaeger"}]}, "services": [{"name": "o11yservice", "description": "o11y Service"}, {"name": "jaeger", "description": "jaeger"}, {"name": "otel-userapp", "description": "otel userapp"}, {"name": "otel-finops", "description": "otel finops"}, {"name": "otel-services", "description": "otel services"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false, "capabilityResourceDependencies": [{"type": "PLATFORM", "required": true, "resourceId": "O11Y"}]}}'
WHERE capability_id='O11Y' AND "version"='{1,0,0}' AND capability_type='PLATFORM';

-- ADD SECRETCONTROLLER INFRA capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, VERSION, DISPLAY_NAME, DESCRIPTION, PACKAGE, CAPABILITY_TYPE)
VALUES ('SECRETCONTROLLER', '{1,0,0}', 'Secret Controller', 'Secret Controller', '{"package":{"recipe":{"helmCharts":[{"name":"tp-dp-secret-controller","namespace":"${NAMESPACE}","repository":{"chartMuseum":{"host":"https://syan-tibco.github.io/tp-helm-charts"}},"values":[{"content":"global:\n  cp:\n    containerRegistry:\n      url: \"reldocker.tibco.com\"\n      secret: dp1\n    dataplaneId: dp1\n    subscriptionId: sub1\n    serviceAccount: \"\""}],"flags":{"install":true}}]},"services":[{"name":"tp-dp-secret-controller","description":"Secret Controller"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[]}}', 'INFRA')
ON CONFLICT DO NOTHING;


-- DELETE FINOPSAGENT entry from v3_capability_metadata
DELETE FROM V3_CAPABILITY_METADATA WHERE CAPABILITY_ID = 'FINOPSAGENT' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'INFRA';

-- Update O11Y Platform Capability resources
UPDATE V3_RESOURCES SET  RESOURCE_METADATA = '{"fields":[{"name":"User App Log Index","key":"logserver.userapp.logindex","dataType":"string","required":true},{"name":"Services Log Index","key":"logserver.services.logindex","dataType":"string","required":true},{"name":"Proxy User App Log Index Endpoint","key":"logserver.proxy.userapp.logindex.endpoint","dataType":"string","required":true},{"name":"Proxy User App Log Index Username","key":"logserver.proxy.userapp.logindex.username","dataType":"string","required":false},{"name":"Exporter User App LogINdex Endpoint","key":"logserver.exporter.userapp.logindex.endpoint","dataType":"string","required":true},{"name":"Exporter User App Log Index Username","key":"logserver.exporter.userapp.logindex.username","dataType":"string","required":false},{"name":"Exporter Services Log Index Username","key":"logserver.exporter.services.logindex.username","dataType":"string","required":false},{"name":"Exporter Services Log Index Endpoint","key":"logserver.exporter.services.logindex.endpoint","dataType":"string","required":true},{"name":"Proxy Endpoint","key":"promserver.proxy.endpoint","dataType":"string","required":true},{"name":"Proxy Username","key":"promserver.proxy.username","dataType":"string","required":false},{"name":"Exporter Endpoint","key":"promserver.exporter.endpoint","dataType":"string","required":true},{"name":"Elastic Search Host","key":"jaeger.es.host","dataType":"string","required":true},{"name":"Elastic Search port","key":"jaeger.es.port","dataType":"string","required":true},{"name":"Elastic Search Username","key":"jaeger.es.username","dataType":"string","required":false},{"name":"User App Proxy Password","key":"secret.logserver.userapp.proxy.password","dataType":"string","required":false},{"name":"User App ExporterPassword","key":"secret.logserver.userapp.exporter.password","dataType":"string","required":false},{"name":"Services Exporter Password","key":"secret.logserver.services.exporter.password","dataType":"string","required":false},{"name":"Proxy Password","key":"secret.promserver.proxy.password","dataType":"string","required":false},{"name":"Exporter Token","key":"secret.promserver.exporter.token","dataType":"string","required":false},{"name":"Elastic Search Password","key":"secret.jaeger.es.password","dataType":"string","required":false}]}'
WHERE RESOURCE_ID = 'O11Y' AND RESOURCE_LEVEL = 'PLATFORM';

-- Add MSGSTORAGE resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('MSGSTORAGE','Message Storage','Storage Class Name','Message Storage','{"fields":[{"key":"storageClassName","name":"Storage Class Name","dataType":"string","required":true},{"key":"type","enum":["notShared"],"name":"Type","dataType":"string","required":true}]}','{"aws","azure"}','PLATFORM')
ON CONFLICT DO NOTHING;

-- Add LOGSTORAGE resource
INSERT INTO V3_RESOURCES(RESOURCE_ID, NAME, DESCRIPTION, TYPE, RESOURCE_METADATA, HOST_CLOUD_TYPE, RESOURCE_LEVEL)
VALUES ('LOGSTORAGE','Log Storage','Storage Class Name','Log Storage','{"fields":[{"key":"storageClassName","name":"Storage Class Name","dataType":"string","required":true},{"key":"type","enum":["shared"],"name":"Type","dataType":"string","required":true}]}','{"aws","azure"}','PLATFORM')
ON CONFLICT DO NOTHING;

-- Remove type field from PLATFORM STORAGE metadata
UPDATE V3_RESOURCES SET resource_metadata = '{"fields": [{"key": "storageClassName", "name": "Storage Class Name", "dataType": "string", "required": true}]}'
WHERE resource_id = 'STORAGE' AND resource_level = 'PLATFORM';

ALTER TABLE V2_SUBSCRIPTIONS ADD COLUMN IF NOT EXISTS HELM_REPO_PREFERENCE VARCHAR(255) DEFAULT '';
ALTER TABLE V2_ARCHIVED_SUBSCRIPTIONS ADD COLUMN IF NOT EXISTS HELM_REPO_PREFERENCE VARCHAR(255) DEFAULT '';
ALTER TABLE V2_ACCOUNTS ALTER COLUMN HOST_PREFIX TYPE VARCHAR(32);

------- EDIT THIS SECTION FOR UPDATING ENTRIES IN V3_CAPABILITY_METADATA ----------------
-- Update BWCE Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"bwprovisioner","namespace":"${NAMESPACE}","version":"1.0.30","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"global:\n  bwprovisioner:\n    image:\n      tag: 283\nconfig:\n  APP_INIT_IMAGE_TAG: \"20\"\npublicApi:\n  ingress:\n    controllerName: ${INGRESS_CONTROLLER_NAME}\n    nginx:\n      className: ${INGRESS_CLASS_NAME}\n      pathPrefix: ${INGRESS_PATH_PREFIX}\n      fqdn: ${INGRESS_FQDN}\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"bwprovisioner","description":"BW Provisioner Service"},{"name":"oauth2-proxy","description":"OAuth2 Proxy"}],"dependsOn":[{"version":[1,0,0],"capabilityId":"INTEGRATIONCORE","capabilityType":"INFRA"},{"version":[1,0,0],"capabilityId":"OAUTH2PROXY","capabilityType":"INFRA_SIDECAR"}],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[{"required":true,"resourceId":"INGRESS","resourceType":"PLATFORM","type":"Ingress Controller"}]}}'
WHERE CAPABILITY_ID = 'BWCE' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'PLATFORM';

-- Update INTEGRATIONCORE Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"artifactmanager","namespace":"${NAMESPACE}","version":"1.0.24","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"global:\n  artifactmanager:\n    image:\n      tag: 37\nvolumes:\n  artifactmanager:\n    persistentVolumeClaim:\n      resources:\n        requests:\n          storage: 20Gi\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}},{"name":"distributed-lock-operator","namespace":"${NAMESPACE}","version":"1.0.75","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"global:\n  distlockop:\n    image:\n      tag: 72\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"artifactmanager","description":"Artifact Manager"},{"name":"distributed-lock-operator","description":"Distributed Lock Operator"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[{"resourceType":"INFRA","required":true,"resourceId":"STORAGE","type":"Storage Class"}]}}'
WHERE CAPABILITY_ID = 'INTEGRATIONCORE' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'INFRA';

-- Update OAUTH2PROXY Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"oauth2-proxy","flags":{"install":true,"createNamespace":false,"dependencyUpdate":true},"values":[{"content":"global:     #global section can be removed once CP is having these values passed down through capability\n  cp:\n    cpHostName: \"${CP_HOST_NAME}\"\n    instanceId: \"${CP_CAPABILITY_INSTANCE_ID}\"\n    capability:\n      pathPrefix: \"${CAPABILITY_PATH_PREFIX}\"\n    resources:\n      ingress:\n        fqdn: \"${INGRESS_FQDN}\"\n        ingressClassName: \"${INGRESS_CLASSNAME}\"\n        secrets:\n          iat: \"${SECRETS_IAT}\"\nserviceAccount:\n  enabled: false\n  name: ${SERVICE_ACCOUNT_NAME}   #CP global var? \nimage:\n  repository: \"${IMAGE_REPOSITORY}/stratosphere/oauth2-proxy-tibx\"\n  tag: \"v7.4.0-tibx-prod-1\"\nconfig:\n  existingSecret: \"oauth2proxy-${CP_CAPABILITY_INSTANCE_ID}\" ### can be the release name to make it unique\nextraArgs:\n  oidc-issuer-url: \"https://${CP_HOST_NAME}\"\n  cookie-path: ${CAPABILITY_PATH_PREFIX}      ### ${global.cp.capability.pathPrefix}\n  proxy-prefix: ${CAPABILITY_PATH_PREFIX}/oauth2   ### ${global.cp.capability.pathPrefix}/oauth2\ningress:\n  className: ${INGRESS_CLASSNAME} ### ${global.cp.resources.ingress.ingressClassName}\n  hosts: \n    - ${INGRESS_FQDN} ### ${global.cp.resources.ingress.fqdn}\n  path: \"${CAPABILITY_PATH_PREFIX}/oauth2\" ### ${global.cp.capability.pathPrefix}/oauth2\nenableLogging: true\n"}],"version":"6.17.0-tibx-20","namespace":"${NAMESPACE}","repository":{"chartMuseum":{"host":"${HELM_REPO}"}}}]}}}'
WHERE CAPABILITY_ID = 'OAUTH2PROXY' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'INFRA_SIDECAR';

-- Update CPPROXY Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"tp-cp-proxy","namespace":"${NAMESPACE}","version":"1.0.110","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"cp-proxy","description":"CP Proxy"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[]}}'
WHERE CAPABILITY_ID = 'CPPROXY' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'INFRA';

-- Update EMS Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"allowMultipleInstances":true,"capabilityResourceDependencies":[{"required":false,"resourceId":"STORAGE","resourceType":"PLATFORM","type":"Message Storage","description":"Select a resource for the storage-class of EMS data store"},{"required":false,"resourceId":"STORAGE","resourceType":"PLATFORM","type":"Log Storage","description":"Select a resource for the storage-class of EMS logs store"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"recipe":{"helmCharts":[{"name":"msg-ems-tp","flags":{"install":true,"createNamespace":false},"values":[{"content":"emsVersion: \"10.2.1-9\"\nems:\n    name: ${EMS_NAME}\n    use: ${EMS_USE}\n    sizing: ${EMS_SIZE}\n"}],"version":"1.0.23","namespace":"${NAMESPACE}","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"releaseName":"${EMS_NAME}"}]},"services":[{"description":"EMS Service","name":"ems"}]}}',
DISPLAY_NAME = 'TIBCO Enterprise Message Service™', DESCRIPTION = 'TIBCO Enterprise Message Service (EMS) allows you to send messages from your applications in a format that conforms to the Jakarta Messaging (JMS) specification. The software also extends the JMS specification with a reliable delivery mode and a no-acknowledge acknowledgement mode.'
WHERE CAPABILITY_ID = 'EMS' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'PLATFORM';

-- Update FLOGO Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"flogoprovisioner","namespace":"${NAMESPACE}","version":"1.0.22","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"global:\n  flogoprovisioner:\n    image:\n      tag: 168\nconfig:\n  APP_INIT_IMAGE_TAG: \"22\"\npublicApi:\n  ingress:\n    controllerName: ${INGRESS_CONTROLLER_NAME}\n    nginx:\n      className: ${INGRESS_CLASS_NAME}\n      pathPrefix: ${INGRESS_PATH_PREFIX}\n      fqdn: ${INGRESS_FQDN}\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"flogoprovisioner","description":"Flogo Provisioner Service"},{"name":"oauth2-proxy","description":"OAuth2 Proxy"}],"dependsOn":[{"capabilityId":"INTEGRATIONCORE","version":[1,0,0],"capabilityType":"INFRA"},{"version":[1,0,0],"capabilityId":"OAUTH2PROXY","capabilityType":"INFRA_SIDECAR"}],"provisioningRoles":["DEV_OPS"],"capabilityResourceDependencies":[{"required":true,"resourceId":"INGRESS","resourceType":"PLATFORM","type":"Ingress Controller"}],"allowMultipleInstances":false}}'
WHERE CAPABILITY_ID = 'FLOGO' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'PLATFORM';

-- Update MONITORINGAGENT Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"tp-dp-monitor-agent","namespace":"${NAMESPACE}","version":"1.0.92","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"flags":{"install":true,"createNamespace":false}}]},"services":[{"name":"tp-dp-monitor-agent","description":"Monitoring Agent Service"}],"dependsOn":[],"provisioningRoles":[],"allowMultipleInstances":false}}'
WHERE CAPABILITY_ID = 'MONITORINGAGENT' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'INFRA';

-- Update O11Y INFRA Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package": {"recipe": {"helmCharts": [{"name": "o11yservice", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "version": "1.0.48", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-userapp\npodLabels:\n  networking.platform.tibco.com/kubernetes-api: enable\n  egress.networking.platform.tibco.com/internet-all: enable\nautoscaling:\n  enabled: false\n  minReplicas: 1\n  maxReplicas: 10\n  behavior:\n    scaleUp:\n      stabilizationWindowSeconds: 15\n    scaleDown:\n      stabilizationWindowSeconds: 15\n  targetCPUUtilizationPercentage: 80\n  targetMemoryUtilizationPercentage: 80\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter: null\n    batch: {}\n    filter/devnull:\n      error_mode: ignore\n      traces:\n        span:\n          - ''name != \"\"''\n      metrics:\n        metric:\n          - ''name != \"\"''\n        datapoint:\n          - ''metric.name != \"\"''\n      logs:\n        log_record:\n          - ''IsMatch(body, \"\")''\n    memory_limiter:\n      check_interval: 5s\n      limit_percentage: 80\n      spike_limit_percentage: 25\n  exporters:\n    logging: {}\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n      metrics:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n      traces:\n        exporters:\n          - logging\n        processors:\n          - filter/devnull\n        receivers:\n          - otlp\n"}], "version": "0.69.6", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "otel-userapp"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-finops\npodLabels:\n  networking.platform.tibco.com/kubernetes-api: enable\n  egress.networking.platform.tibco.com/internet-all: enable\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    prometheus/finops:\n      config:\n        scrape_configs:\n          - job_name: monitoring-agent\n            scrape_interval: 60s\n            kubernetes_sd_configs:\n            - role: service\n            relabel_configs:\n            - action: keep\n              source_labels: [__meta_kubernetes_service_label_platform_tibco_com_scrape_finops]\n              regex: \"true\"\n            - action: keep\n              regex: \"true\"\n              source_labels:\n              - __meta_kubernetes_service_label_prometheus_io_scrape\n            - action: keep\n              regex: ${DATAPLANE-ID}\n              source_labels:\n              - __meta_kubernetes_service_label_platform_tibco_com_dataplane_id\n            - action: replace\n              regex: (.+)\n              source_labels:\n              - __meta_kubernetes_service_annotation_prometheus_io_path\n              target_label: __metrics_path__\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n    attributes/finops:\n      actions:\n      - key: dataplane_id\n        action: insert\n        value: ${DATAPLANE-ID}\n  exporters:\n    logging: {}\n    otlphttp/finops:\n      metrics_endpoint: http://cp-proxy/finops/finops-service/api/v1/proxy\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      metrics:\n        exporters:\n          - logging\n          - otlphttp/finops\n        processors:\n          - memory_limiter\n          - batch\n          - attributes/finops\n        receivers:\n          - prometheus/finops\n"}], "version": "0.69.6", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "otel-finops"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-services\npodLabels:\n  networking.platform.tibco.com/kubernetes-api: enable\n  egress.networking.platform.tibco.com/internet-all: enable\nserviceAccount:\n  create: false\n  annotations: {}\n  name: ${SERVICE-ACCOUNT}\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: false\n    containerPort: 8888\n    servicePort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n  exporters:\n    logging: {}\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - logging\n        processors:\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.69.6", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "otel-services"}, {"name": "jaeger", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "provisionDataStore:\n  cassandra: false\n  elasticsearch: false\nstorage:\n  type: memory\nagent:\n  enabled: false\nquery:\n  fullnameOverride: jaeger-query\n  podLabels:\n    networking.platform.tibco.com/kubernetes-api: enable\n    egress.networking.platform.tibco.com/internet-all: enable\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  ingress:\n    enabled: true\n    ingressClassName: haproxy-dp-${DATAPLANE-ID}\n    annotations:\n      haproxy.org/cors-enable: \"true\"\n      haproxy.org/load-balance: leastconn\n      haproxy.org/src-ip-header: X-Real-IP\n      haproxy.org/timeout-http-request: 600s\n      ingress.kubernetes.io/rewrite-target: /\n      meta.helm.sh/release-name: jaeger\n    pathType: Prefix\n    hosts:\n      -\n  oAuthSidecar:\n    enabled: false\n  agentSidecar:\n    enabled: false\ncollector:\n  fullnameOverride: jaeger-collector\n  podLabels:\n    networking.platform.tibco.com/kubernetes-api: enable\n    egress.networking.platform.tibco.com/internet-all: enable\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  autoscaling:\n    enabled: false\n    minReplicas: 2\n    maxReplicas: 10\n    behavior:\n      targetCPUUtilizationPercentage: 80\n      targetMemoryUtilizationPercentage: 80\n  service:\n    otlp:\n      grpc:\n        name: otlp-grpc\n        port: 4317\n      http:\n        name: otlp-http\n        port: 4318\n"}], "version": "0.71.21", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "jaeger"}], "deploymentStrategy": "weighted-concurrency"}, "services": [{"name": "o11y-service", "description": "o11y Service"}, {"name": "jaeger-collector", "description": "jaeger collector"}, {"name": "jaeger-query", "description": "jaeger query"}, {"name": "otel-userapp", "description": "otel userapp"}, {"name": "otel-finops", "description": "otel finops"}, {"name": "otel-services", "description": "otel services"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false}}'
WHERE CAPABILITY_ID = 'O11Y' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'INFRA';

-- Update O11Y PLATFORM Recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package": {"recipe": {"helmCharts": [{"name": "o11yservice", "flags": {"install": true, "createNamespace": false, "dependencyUpdate": true}, "version": "1.0.48", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-userapp\npodLabels:\n  networking.platform.tibco.com/kubernetes-api: enable\n  egress.networking.platform.tibco.com/internet-all: enable\n  prometheus.io/scrape: \"true\"\n  prometheus.io/path: \"metrics\"\n  prometheus.io/port: \"4319\"\nautoscaling:\n  enabled: false\n  minReplicas: 1\n  maxReplicas: 10\n  behavior:\n    scaleUp:\n      stabilizationWindowSeconds: 15\n    scaleDown:\n      stabilizationWindowSeconds: 15\n  targetCPUUtilizationPercentage: 80\n  targetMemoryUtilizationPercentage: 80\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nextraEnvs:\n  - name: KUBE_NODE_NAME\n    valueFrom:\n      fieldRef:\n        apiVersion: v1\n        fieldPath: spec.nodeName\nextraEnvsFrom:\n  - secretRef:\n      name: o11y-service\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n    prometheus:\n      config:\n        scrape_configs:\n         - job_name: monitoring-agent\n           scrape_interval: 20s\n           kubernetes_sd_configs:\n           - role: service\n           relabel_configs:\n           - action: keep\n             source_labels: [__meta_kubernetes_service_label_prometheus_io_scrape]\n             regex: \"true\"\n           - action: keep\n             source_labels: [__meta_kubernetes_service_label_platform_tibco_com_dataplane_id]\n             regex: \"${DATAPLANE-ID}\"\n           - action: replace\n             source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]\n             target_label: __metrics_path__\n             regex: (.+)\n         - job_name: envoy-stats\n           scrape_interval: 20s\n           kubernetes_sd_configs:\n           - role: pod\n           relabel_configs:\n           - action: keep\n             source_labels: [__meta_kubernetes_pod_label_prometheus_io_scrape]\n             regex: \"true\"\n           - action: keep\n             source_labels: [__meta_kubernetes_pod_container_port_name]\n             regex: \".*-envoy-prom\"\n           - action: keep\n             source_labels: [__meta_kubernetes_pod_label_platform_tibco_com_dataplane_id]\n             regex: \"${DATAPLANE-ID}\"\n           - action: replace\n             source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]\n             target_label: __metrics_path__\n             regex: (.+)\n  processors:\n    memory_limiter:\n      check_interval: 5s\n      limit_percentage: 80\n      spike_limit_percentage: 25\n    batch: {}\n    k8sattributes/general:\n      auth_type: \"serviceAccount\"\n      passthrough: false\n      extract:\n        metadata:\n          - k8s.pod.name\n          - k8s.pod.uid\n          - k8s.namespace.name\n        annotations:\n          - tag_name: connectors\n            key: platform.tibco.com/connectors\n            from: pod\n        labels:\n          - tag_name: app_id\n            key: platform.tibco.com/app-id\n            from: pod\n          - tag_name: app_type\n            key: platform.tibco.com/app-type\n            from: pod\n          - tag_name: dataplane_id\n            key: platform.tibco.com/dataplane-id\n            from: pod\n          - tag_name: workload_type\n            key: platform.tibco.com/workload-type\n            from: pod\n          - tag_name: app_name\n            key: platform.tibco.com/app-name\n            from: pod\n          - tag_name: app_version\n            key: platform.tibco.com/app-version\n            from: pod\n          - tag_name: app_tags\n            key: platform.tibco.com/tags\n            from: pod\n          - tag_name: capability_instance_id\n            key: platform.tibco.com/capability-instance-id\n            from: pod\n    transform/logs:\n      log_statements:\n      - context: log\n        statements:\n        - set(resource.attributes[\"pod_namespace\"], resource.attributes[\"k8s.namespace.name\"])\n        - set(resource.attributes[\"pod_name\"], resource.attributes[\"k8s.pod.name\"])\n        - set(resource.attributes[\"pod_uid\"], resource.attributes[\"k8s.pod.uid\"])\n        - delete_key(resource.attributes, \"k8s.namespace.name\")\n        - delete_key(resource.attributes, \"k8s.pod.name\")\n        - delete_key(resource.attributes, \"k8s.pod.uid\")\n        - delete_key(resource.attributes, \"k8s.pod.ip\")\n    transform/traces:\n      trace_statements:\n      - context: span\n        statements:\n          - set(attributes[\"pod_name\"], resource.attributes[\"k8s.pod.name\"])\n          - set(attributes[\"pod_namespace\"], resource.attributes[\"k8s.namespace.name\"])\n          - set(attributes[\"app_id\"], resource.attributes[\"app_id\"])\n          - set(attributes[\"app_type\"], resource.attributes[\"app_type\"])\n          - set(attributes[\"dataplane_id\"], resource.attributes[\"dataplane_id\"])\n          - set(attributes[\"workload_type\"], resource.attributes[\"workload_type\"])\n          - set(attributes[\"app_tags\"], resource.attributes[\"app_tags\"])\n          - set(attributes[\"app_name\"], resource.attributes[\"app_name\"])\n          - set(attributes[\"app_version\"], resource.attributes[\"app_version\"])\n          - set(attributes[\"capability_instance_id\"], resource.attributes[\"capability_instance_id\"])\n  exporters:\n    elasticsearch/log:\n      endpoints:\n      - ${env:ES_SERVER_EXPORTER_ENDPOINT}\n      logs_index: ${env:ES_EXPORTER_LOG_INDEX_NAME}\n      user: ${env:ES_EXPORTER_LOG_INDEX_USERNAME}\n      password: ${env:ES_EXPORTER_LOG_INDEX_PASSWORD}\n      retry:\n        enabled: false\n      tls:\n        insecure: false\n        insecure_skip_verify: true\n    otlp/trace:\n      endpoint: ${env:JAEGER_COLLECTOR_ENDPOINT}\n      tls:\n        insecure: true\n    prometheus/user:\n      endpoint: 0.0.0.0:4319\n      enable_open_metrics: true\n      resource_to_telemetry_conversion:\n        enabled: true\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        receivers:\n          - otlp\n        processors:\n          - k8sattributes/general\n          - transform/logs\n          - memory_limiter\n          - batch\n        exporters:\n          - elasticsearch/log\n      metrics/appengines:\n        receivers:\n          - otlp\n          - prometheus\n        processors:\n          - k8sattributes/general\n          - memory_limiter\n          - batch\n        exporters:\n          - prometheus/user\n      traces:\n        receivers:\n          - otlp\n        processors:\n          - k8sattributes/general\n          - transform/traces\n          - memory_limiter\n          - batch\n        exporters:\n          - otlp/trace\n"}], "version": "0.69.6", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "otel-userapp"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-finops\npodLabels:\n  networking.platform.tibco.com/kubernetes-api: enable\n  egress.networking.platform.tibco.com/internet-all: enable\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nextraEnvsFrom:\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    prometheus/finops:\n      config:\n        scrape_configs:\n          - job_name: monitoring-agent\n            scrape_interval: 60s\n            kubernetes_sd_configs:\n            - role: service\n            relabel_configs:\n            - action: keep\n              source_labels: [__meta_kubernetes_service_label_platform_tibco_com_scrape_finops]\n              regex: \"true\"\n            - action: keep\n              regex: \"true\"\n              source_labels:\n              - __meta_kubernetes_service_label_prometheus_io_scrape\n            - action: keep\n              regex: ${DATAPLANE-ID}\n              source_labels:\n              - __meta_kubernetes_service_label_platform_tibco_com_dataplane_id\n            - action: replace\n              regex: (.+)\n              source_labels:\n              - __meta_kubernetes_service_annotation_prometheus_io_path\n              target_label: __metrics_path__\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    batch: {}\n    attributes/finops:\n      actions:\n      - key: dataplane_id\n        action: insert\n        value: ${DATAPLANE-ID}\n  exporters:\n    logging: {}\n    otlphttp/finops:\n      metrics_endpoint: http://cp-proxy/finops/finops-service/api/v1/proxy\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      metrics:\n        exporters:\n          - logging\n          - otlphttp/finops\n        processors:\n          - memory_limiter\n          - batch\n          - attributes/finops\n        receivers:\n          - prometheus/finops\n"}], "version": "0.69.6", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "otel-finops"}, {"name": "opentelemetry-collector", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "mode: \"deployment\"\nfullnameOverride: otel-services\npodLabels:\n  networking.platform.tibco.com/kubernetes-api: enable\n  egress.networking.platform.tibco.com/internet-all: enable\nserviceAccount:\n  create: false\n  name: ${SERVICE-ACCOUNT}\nextraEnvsFrom:\n  - secretRef:\n      name: o11y-service\n  - configMapRef:\n      name: o11y-service\nports:\n  otlp:\n    enabled: true\n    containerPort: 4317\n    servicePort: 4317\n    hostPort: 4317\n    protocol: TCP\n    # nodePort: 30317\n    appProtocol: grpc\n  otlp-http:\n    enabled: true\n    containerPort: 4318\n    servicePort: 4318\n    hostPort: 4318\n    protocol: TCP\n  metrics:\n    enabled: true\n    containerPort: 8888\n    servicePort: 8888\n    hostPort: 8888\n    protocol: TCP\n  prometheus:\n    enabled: true\n    containerPort: 4319\n    servicePort: 4319\n    hostPort: 4319\n    protocol: TCP\nconfig:\n  receivers:\n    otlp:\n      protocols:\n        grpc:\n          endpoint: 0.0.0.0:4317\n        http:\n          cors:\n            allowed_origins:\n              - http://*\n              - https://*\n          endpoint: 0.0.0.0:4318\n  processors:\n    memory_limiter:\n      check_interval: 1s\n      limit_mib: 2000\n    k8sattributes/general:\n      auth_type: \"serviceAccount\"\n      passthrough: false\n      extract:\n        metadata:\n          - k8s.pod.name\n          - k8s.pod.uid\n          - k8s.namespace.name\n        labels:\n          - tag_name: dataplane_id\n            key: platform.tibco.com/dataplane-id\n            from: pod\n          - tag_name: workload_type\n            key: platform.tibco.com/workload-type\n            from: pod\n    batch: {}\n  exporters:\n    elasticsearch/log:\n      endpoints:\n      - ${env:ES_SERVER_SERVICE_ENDPOINT}\n      logs_index: ${env:ES_SERVICE_LOG_INDEX_NAME}\n      user: ${env:ES_SERVICE_LOG_INDEX_USERNAME}\n      password: ${env:ES_SERVICE_LOG_INDEX_PASSWORD}\n      retry:\n        enabled: false\n      tls:\n        insecure: false\n        insecure_skip_verify: true\n  extensions:\n    health_check: {}\n    memory_ballast:\n      size_in_percentage: 40\n  service:\n    telemetry:\n      logs: {}\n      metrics:\n        address: :8888\n    extensions:\n      - health_check\n      - memory_ballast\n    pipelines:\n      logs:\n        exporters:\n          - elasticsearch/log\n        processors:\n          - k8sattributes/general\n          - memory_limiter\n          - batch\n        receivers:\n          - otlp\n"}], "version": "0.69.6", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "otel-services"}, {"name": "jaeger", "flags": {"install": true, "isDevTesting": true, "createNamespace": false, "dependencyUpdate": true}, "values": [{"content": "provisionDataStore:\n  cassandra: false\n  elasticsearch: false\nstorage:\n  type: elasticsearch\n  elasticsearch:\n    cmdlineParams:\n      es.server-urls: ${ES-SERVER-ENDPOINT}\n      es.username: ${ES-SERVER-USERNAME}\n      es.password: ${ES-SERVER-PASSWORD}\n    tags-as-fields:\n      all: true\n    tls:\n      enabled: false\n      secretName: jaeger-elasticsearch\nagent:\n  enabled: false\nquery:\n  fullnameOverride: jaeger-query\n  basePath: /o11y/v1/traceproxy/${DATAPLANE-ID}\n  podLabels:\n    networking.platform.tibco.com/kubernetes-api: enable\n    egress.networking.platform.tibco.com/internet-all: enable\n  extraConfigmapMounts:\n    - name: jaeger-config\n      mountPath: /jaeger/config\n      subPath: \"\"\n      configMap: o11y-service\n      readOnly: true\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  ingress:\n    enabled: false\n    ingressClassName: haproxy-dp-${DATAPLANE-ID}\n    annotations:\n      haproxy.org/cors-enable: \"true\"\n      haproxy.org/load-balance: leastconn\n      haproxy.org/src-ip-header: X-Real-IP\n      haproxy.org/timeout-http-request: 600s\n      ingress.kubernetes.io/rewrite-target: /\n      meta.helm.sh/release-name: jaeger\n    pathType: Prefix\n    hosts:\n      -\n  oAuthSidecar:\n    enabled: false\n  agentSidecar:\n    enabled: false\n  cmdlineParams:\n    es.version: 7\n    es.tls.enabled: true\n    es.tls.skip-host-verify: true\n    query.ui-config: /jaeger/config/jaeger-ui-config.json\ncollector:\n  fullnameOverride: jaeger-collector\n  podLabels:\n    networking.platform.tibco.com/kubernetes-api: enable\n    egress.networking.platform.tibco.com/internet-all: enable\n  serviceAccount:\n    create: false\n    name: ${SERVICE-ACCOUNT}\n  autoscaling:\n    enabled: false\n    minReplicas: 2\n    maxReplicas: 10\n    behavior:\n      targetCPUUtilizationPercentage: 80\n      targetMemoryUtilizationPercentage: 80\n  cmdlineParams:\n    es.version: 7\n    es.create-index-templates: \"false\"\n    es.tls.enabled: true\n    es.tls.skip-host-verify: true\n  service:\n    otlp:\n      grpc:\n        name: otlp-grpc\n        port: 4317\n      http:\n        name: otlp-http\n        port: 4318\n"}], "version": "0.71.21", "namespace": "${NAMESPACE}", "repository": {"chartMuseum": {"host": "${HELM_REPO}"}}, "releaseName": "jaeger"}], "deploymentStrategy": "weighted-concurrency"}, "services": [{"name": "o11y-service", "description": "o11y Service"}, {"name": "jaeger-collector", "description": "jaeger collector"}, {"name": "jaeger-query", "description": "jaeger query"}, {"name": "otel-userapp", "description": "otel userapp"}, {"name": "otel-finops", "description": "otel finops"}, {"name": "otel-services", "description": "otel services"}], "dependsOn": [], "provisioningRoles": ["DEV_OPS"], "allowMultipleInstances": false, "capabilityResourceDependencies": [{"type": "Observability", "required": true, "resourceId": "O11Y", "resourceType": "PLATFORM"}]}}'
WHERE CAPABILITY_ID = 'O11Y' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'PLATFORM';

-- Update SECRETCONTROLLER recipe
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"recipe":{"helmCharts":[{"name":"tp-dp-secret-controller","namespace":"${NAMESPACE}","version":"1.0.41","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"name":"dp-secret-controller","description":"Secret Controller"}],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"allowMultipleInstances":false,"capabilityResourceDependencies":[]}}'
WHERE CAPABILITY_ID = 'SECRETCONTROLLER' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE='INFRA';

-- Update TIBCOHUB capability package
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"allowMultipleInstances":false,"capabilityResourceDependencies":[{"required":true,"resourceId":"INGRESS","resourceType":"PLATFORM","type":"Ingress Controller"},{"required":true,"resourceId":"STORAGE","resourceType":"PLATFORM","type":"Storage Class"}],"dependsOn":[{"capabilityId":"OAUTH2PROXY","version":[1,0,0],"capabilityType":"INFRA_SIDECAR"}],"provisioningRoles":["DEV_OPS"],"recipe":{"helmCharts":[{"name":"tibco-developer-hub","version":"1.0.27","namespace":"${NAMESPACE}","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"baseUrlKeyPath: backstage.appConfig.app.baseUrl\nbackstage:\n  appConfig:\n    app:\n      baseUrl: ${PUBLIC_URL}\n    backend:\n      baseUrl: ${PUBLIC_URL}\n    auth:\n      providers:\n        oauth2Proxy:\n          development: {}\n      enableAuthProviders: [oauth2Proxy]    \n  # only if user provides a secrets reference \n  # extraEnvVarsSecrets:\n  #  - ${SECRETS_NAME}\npostgresql:\n  enabled: true\ningress:\n  enabled: true\n  className: ${INGRESS_CLASSNAME}\n  host: ${HOSTNAME}\n"}],"flags":{"install":true,"createNamespace":false,"dependencyUpdate":true}}]},"services":[{"description":"Postgres Database","name":"postgresql"},{"description":"NodeJs backend and UI hosting service","name":"tibco-developer-hub"},{"name":"oauth2-proxy","description":"OAuth2 Proxy"}]}}'
WHERE CAPABILITY_ID = 'TIBCOHUB' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'PLATFORM';

-- Update ISTIO capability
UPDATE V3_CAPABILITY_METADATA SET PACKAGE = '{"package":{"allowMultipleInstances":false,"capabilityResourceDependencies":[],"dependsOn":[],"provisioningRoles":["DEV_OPS"],"recipe":{"helmCharts":[{"name":"istio-crd","namespace":"${NAMESPACE}","version":"1.0.18","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"serviceAccount:\n  create: false\nglobal:\n  istioNamespace: ${NAMESPACE}\n"}],"flags":{"install":true,"createNamespace":false}},{"name":"istio-istiod","namespace":"${NAMESPACE}","version":"1.0.18","repository":{"chartMuseum":{"host":"${HELM_REPO}"}},"values":[{"content":"serviceAccount:\n  create: false\npilot:\n  autoscaleEnabled: true\n  autoscaleMin: 1\n  autoscaleMax: 5\n  replicaCount: 1\n  traceSampling: 25.0\n  resources:\n    requests:\n      cpu: 200m\n      memory: 256Mi\n    limits:\n      cpu: 500m\n      memory: 512Mi\nglobal:\n  istioNamespace: ${NAMESPACE}\n  meshID: ${DATAPLANE-ID}\n  cp:\n    dataplaneId: ${DATAPLANE-ID}\n  security:\n     peerAuthentication: PERMISSIVE\n  proxy:\n    resources:\n      requests:\n        cpu: 100m\n        memory: 128Mi\n      limits:\n        cpu: 250m\n        memory: 256Mi\nmeshConfig:\n  accessLogFile: /dev/stdout\n  defaultConfig:\n    tracing:\n      zipkin:\n        address: otel-userapp.${NAMESPACE}.svc.cluster.local:9411\n  defaultProviders:\n    tracing:\n    - opentelemetry\n  extensionProviders:\n    - name: opentelemetry\n      opentelemetry:\n        port: 4317\n        service: otel-userapp.${NAMESPACE}.svc.cluster.local\n"}],"flags":{"install":true,"createNamespace":false}}]},"services":[{"description":"istiod","name":"istio-istiod"}]}}',
DESCRIPTION = 'Deploy Service Mesh to ​simplify the observation, monitoring, and control of microservice traffic.'
WHERE CAPABILITY_ID = 'ISTIO' AND VERSION = '{1,0,0}' AND CAPABILITY_TYPE = 'PLATFORM';
----------------- END OF SECTION -----------------------

------- EDIT THIS SECTION FOR UPDATING ENTRIES IN V3_RESOURCES ----------------
-- Update MSGSTORAGE resource_metadata
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"storageClassName","name":"Storage Class Name","dataType":"string","required":true},{"key":"type","enum":["not-shared"],"name":"Type","dataType":"string","required":true}]}'
WHERE RESOURCE_ID = 'MSGSTORAGE' AND RESOURCE_LEVEL = 'PLATFORM';

--Update O11Y resource_metadata
UPDATE V3_RESOURCES SET RESOURCE_METADATA = '{"fields":[{"key":"logsServers","name":"O11Y logsServers","value":{"servers":[{"kind":"elasticSearch","name":"ES-Log-Server","label":"Elastic Search","type":"logsServer","fields":[{"key":"kind","name":"logsServer kind","value":"elasticSearch","dataType":"string","required":true},{"key":"config.userapp.logindex","name":"User App Log Index","dataType":"string","required":true},{"key":"config.services.logindex","name":"Services Log Index","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.endpoint","name":"Proxy User App Log Index Endpoint","dataType":"string","required":true},{"key":"config.proxy.userapp.logindex.username","name":"config.Proxy User App Log Index Username","dataType":"string","required":false},{"key":"config.exporter.userapp.logindex.endpoint","name":"Exporter User App LogINdex Endpoint","dataType":"string","required":true},{"key":"config.exporter.userapp.logindex.username","name":"Exporter User App Log Index Username","dataType":"string","required":false},{"key":"config.exporter.services.logindex.username","name":"Exporter Services Log Index Username","dataType":"string","required":false},{"key":"config.exporter.services.logindex.endpoint","name":"Exporter Services Log Index Endpoint","dataType":"string","required":true},{"key":"secret.proxy.userapp.logindex.password","name":"User App Proxy Password","dataType":"string","required":false},{"key":"secret.exporter.userapp.logindex.password","name":"Exporter User App Log Index Password","dataType":"string","required":false},{"key":"secret.exporter.services.logindex.password","name":"Services Exporter Password","dataType":"string","required":false}]}]},"dataType":"map","required":true},{"key":"tracesServers","name":"O11Y tracesServers","value":{"servers":[{"kind":"jaeger","name":"Jaeger-Traces-Server","label":"Jaeger","type":"tracesServer","fields":[{"key":"kind","name":"tracesServer kind","value":"jaeger","dataType":"string","required":true},{"key":"config.es.endpoint","name":"Jaeger Endpoint","dataType":"string","required":true},{"key":"config.es.username","name":"Jaeger Username","dataType":"string","required":false},{"key":"secret.es.password","name":"Jaeger Password","dataType":"string","required":false}]}]},"dataType":"map","required":true},{"key":"metricsServers","name":"O11Y metricsServers","value":{"servers":[{"kind":"prometheus","name":"Prometheus-Metrics-Server","label":"Prometheus","type":"metricsServer","fields":[{"key":"kind","name":"metricsServer kind","value":"prometheus","dataType":"string","required":true},{"key":"config.proxy.endpoint","name":"Proxy Endpoint","dataType":"string","required":true},{"key":"config.proxy.username","name":"Proxy Username","dataType":"string","required":false},{"key":"config.exporter.endpoint","name":"Exporter Endpoint","dataType":"string","required":true},{"key":"secret.proxy.password","name":"Proxy Password","dataType":"string","required":false},{"key":"secret.exporter.token","name":"Exporter Token","dataType":"string","required":false}]}]},"dataType":"map","required":true}]}'
WHERE RESOURCE_ID = 'O11Y' AND RESOURCE_LEVEL = 'PLATFORM';

-- Delete MSGSTORAGE resource
DELETE FROM v3_resources WHERE resource_id = 'MSGSTORAGE' AND resource_level = 'PLATFORM';

-- Delete LOGSTORAGE resource
DELETE FROM v3_resources WHERE resource_id = 'LOGSTORAGE' AND resource_level = 'PLATFORM';

-- Update INFRA and PLATFORM STORAGE resource's type
UPDATE v3_resources SET TYPE = 'Storage Class' WHERE resource_id = 'STORAGE' AND resource_level IN ('INFRA','PLATFORM');
------- END -----------

-- Update TIB_CLD_TP_PAID_CPASS plan's display_name
UPDATE v2_tenant_plans SET display_name = 'TIBCO<sup>&reg;</sup> Platform Base' WHERE tenant_id = 'TP' AND tenant_plan_id = 'peiwdffhfo2jwkdjeu2wdq2lhi42ga00';

-- Update TIB_CLD_ADMIN_TIB_CLOUDOPS plan's display_name
UPDATE v2_tenant_plans SET display_name = 'TIBCO<sup>&reg;</sup> Platform Admin CloudOps Plan' WHERE tenant_id = 'ADMIN' AND tenant_plan_id = 'peiwdffhfo2jwkdjeu2wdq2lhi42gn21';

-- Disable all CIndex Audit related triggers
ALTER TABLE TSCUTDB_AUDIT.V2_CINDEX_UTD_AUDIT DISABLE TRIGGER V2_CINDEX_UTD_AUDIT_EVENT_NOTIFIER;
ALTER TABLE V2_ACCOUNTS DISABLE TRIGGER Z_V2_CINDEX_AUDIT_ACCOUNTS;
ALTER TABLE V2_TENANTS  DISABLE TRIGGER Z_V2_CINDEX_AUDIT_TENANTS;
ALTER TABLE V2_EXTERNAL_ACCOUNTS DISABLE TRIGGER Z_V2_CINDEX_AUDIT_EXTERNAL_ACCOUNTS;
ALTER TABLE V2_TENANT_PLANS DISABLE TRIGGER Z_V2_CINDEX_AUDIT_TENANT_PLANS;
ALTER TABLE V2_SUBSCRIPTIONS DISABLE TRIGGER Z_V2_CINDEX_AUDIT_SUBSCRIPTIONS;