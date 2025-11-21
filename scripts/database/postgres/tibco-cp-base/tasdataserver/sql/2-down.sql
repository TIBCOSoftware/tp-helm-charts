-----------------------------------------------------------------------------
-- SQL statements for rolling back migration 2 (reverting to version 1)
-----------------------------------------------------------------------------

-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 1;

-- Drop all tables and objects created in migration 2
-- Note: the operation of dropping parent partition table also drop all partition tables
DROP TABLE IF EXISTS TCTA_TRANSACTION_PAYLOAD;
DROP TABLE IF EXISTS TCTA_TRANSACTION;

DROP TABLE IF EXISTS TCTA_HISTORY_LOCK;
DROP TABLE IF EXISTS TCTA_CAPACITY_USAGE_HISTORY;
DROP TABLE IF EXISTS TCTA_BC_POLLER_LOCK;
DROP TABLE IF EXISTS TCTA_BC_POLLER_INFO;
DROP TABLE IF EXISTS TCTA_KEY_STORE;
DROP TABLE IF EXISTS TCTA_AUDIT_LIMIT;
DROP TABLE IF EXISTS TCTA_SEARCH_HISTORY;
DROP TABLE IF EXISTS TCTA_UI_COLUMN;
DROP TABLE IF EXISTS TCTA_COLUMN_VISIBILITY;
DROP TABLE IF EXISTS TCTA_SETTING;
DROP TABLE IF EXISTS TCTA_PROPERTY;
DROP TABLE IF EXISTS TCTA_STATE;
DROP TABLE IF EXISTS TCTA_STATUS;

-- Drop function
DROP FUNCTION IF EXISTS UPDATE_TIMESTAMP_FOR_CHANGE();

-- Drop extension (if no other objects depend on it)
-- Note: Only drop if this was the migration that created it
-- DROP EXTENSION IF EXISTS "uuid-ossp";
