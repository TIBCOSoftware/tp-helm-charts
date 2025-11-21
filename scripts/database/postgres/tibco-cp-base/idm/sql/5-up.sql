---------------------------------------------------
-- Database schema changes for 1.8.0
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

-- PCP-11845: Support longer group names
-- Increase the length of KNOWN_GROUPS column in IDP_DETAILS table to 96.

ALTER TABLE IDP_DETAILS
    ALTER COLUMN KNOWN_GROUPS TYPE VARCHAR(96)[];

-- Update database schema at the end (earlier version is 1.7.0 i.e. 3)
UPDATE SCHEMA_VERSION SET version = 5;
