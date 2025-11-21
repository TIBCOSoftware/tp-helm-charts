-----------------------------------------------------------------------------
-- SQL statements for rolling back tasdomainserver migration 2 (reverting to version 1)
-----------------------------------------------------------------------------

-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 1;

-- Drop all tables and objects created/recreated in migration 2
-- Drop in reverse order respecting foreign key dependencies
DROP TABLE IF EXISTS TCTA_USER CASCADE;
DROP TABLE IF EXISTS TCTA_USER_HISTORY CASCADE;
DROP TABLE IF EXISTS TCTA_USER_QUOTA CASCADE;
DROP TABLE IF EXISTS TCTA_ERROR_QUEUE CASCADE;
DROP TABLE IF EXISTS TCTA_ROLE CASCADE;
DROP TABLE IF EXISTS TCTA_COMPONENT CASCADE;
DROP TABLE IF EXISTS TCTA_TSC_USER CASCADE;
DROP TABLE IF EXISTS TCTA_SUB CASCADE;
