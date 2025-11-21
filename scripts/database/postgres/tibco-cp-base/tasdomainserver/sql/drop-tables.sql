-----------------------------------------------------------------------------
-- SQL statements for deleting all tables created for TCTA Use Team Directory
-----------------------------------------------------------------------------

-- NOTE: Please keep on adding DROP TABLE SQL query if any new table is been added.

DROP TABLE IF EXISTS TCTA_USER CASCADE;

DROP TABLE IF EXISTS TCTA_TSC_USER CASCADE;

DROP TABLE IF EXISTS TCTA_SUB CASCADE;

DROP TABLE IF EXISTS TCTA_USER_HISTORY CASCADE;

DROP TABLE IF EXISTS TCTA_USER_QUOTA CASCADE;

DROP TABLE IF EXISTS TCTA_ERROR_QUEUE CASCADE;

DROP TABLE IF EXISTS TCTA_ROLE CASCADE;

DROP TABLE IF EXISTS TCTA_COMPONENT CASCADE;

DROP TABLE IF EXISTS SCHEMA_VERSION;
