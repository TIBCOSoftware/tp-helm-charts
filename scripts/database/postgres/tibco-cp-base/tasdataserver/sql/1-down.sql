-----------------------------------------------------------------------------
-- SQL statements for deleting all tables created for TCTA DataServer
-----------------------------------------------------------------------------

-- NOTE: Please keep on adding DROP TABLE SQL query if any new table is been added.

DROP TABLE IF EXISTS SCHEMA_VERSION;

-- Note: the operation of dropping parent partition table also drop all partition tables
DROP TABLE IF EXISTS TCTA_TRANSACTION_PAYLOAD;
DROP TABLE IF EXISTS TCTA_TRANSACTION;

DROP TABLE IF EXISTS TCTA_AUDIT_LIMIT;
DROP TABLE IF EXISTS TCTA_SEARCH_HISTORY;
DROP TABLE IF EXISTS TCTA_UI_COLUMN;
DROP TABLE IF EXISTS TCTA_COLUMN_VISIBILITY;
DROP TABLE IF EXISTS TCTA_SETTING;
DROP TABLE IF EXISTS TCTA_PROPERTY;
DROP TABLE IF EXISTS TCTA_STATE;
DROP TABLE IF EXISTS TCTA_STATUS;

DROP FUNCTION IF EXISTS UPDATE_TIMESTAMP_FOR_CHANGE();

-- Drop extension (if no other objects depend on it)
-- Note: Be careful with extension cleanup - only drop if this migration created it
-- and no other database objects depend on it
-- DROP EXTENSION IF EXISTS "uuid-ossp";
