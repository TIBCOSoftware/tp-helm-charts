---------------------------------------------------
-- Database schema changes for 1.3.0
---------------------------------------------------
------------------------------------------------------------------------
-- REMEMBER to update the metadata.sh when adding a new n-up.sql file 
------------------------------------------------------------------------
------------------------------------------------------------------------
--  TABLE NAME: DATA
--  PCP-6266: Increase the key size to 128
------------------------------------------------------------------------
ALTER TABLE DATA
ALTER COLUMN KEY TYPE VARCHAR(128);

------------------------------------------------------------------------
--  TABLE NAME: ARCHIVED_DATA
--  PCP-6266: Increase the key size to 128
------------------------------------------------------------------------
ALTER TABLE ARCHIVED_DATA
ALTER COLUMN KEY TYPE VARCHAR(128);

UPDATE SCHEMA_VERSION SET version = 2;
