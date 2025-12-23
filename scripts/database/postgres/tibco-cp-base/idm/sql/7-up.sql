---------------------------------------------------
-- Database schema changes for 1.14.0
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

ALTER TYPE idp_type ADD VALUE IF NOT EXISTS 'LDAP';

-- Update database schema at the end (earlier version since 1.11.0 i.e. 6)
UPDATE SCHEMA_VERSION SET version = 7;
