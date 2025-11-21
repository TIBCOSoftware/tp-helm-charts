-----------------------------------------------------------------------------
-- SQL statements for rolling back tasdomainserver migration 1
-----------------------------------------------------------------------------

-- Drop tables in reverse order of creation (respecting foreign key dependencies)
DROP TABLE IF EXISTS TCTA_USER CASCADE;
DROP TABLE IF EXISTS TCTA_USER_HISTORY CASCADE;
DROP TABLE IF EXISTS TCTA_USER_QUOTA CASCADE;
DROP TABLE IF EXISTS TCTA_ERROR_QUEUE CASCADE;
DROP TABLE IF EXISTS TCTA_ROLE CASCADE;
DROP TABLE IF EXISTS TCTA_COMPONENT CASCADE;
DROP TABLE IF EXISTS TCTA_TSC_USER CASCADE;
DROP TABLE IF EXISTS TCTA_SUB CASCADE;

-- Drop schema version table
DROP TABLE IF EXISTS SCHEMA_VERSION;

