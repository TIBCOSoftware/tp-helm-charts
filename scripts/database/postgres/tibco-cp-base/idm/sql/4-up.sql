---------------------------------------------------
-- Database schema changes for 1.3.0
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

-- PCP-5688: Capture known/relevant group's key values
ALTER TABLE IDP_DETAILS
    ADD COLUMN IF NOT EXISTS KNOWN_GROUPS_KEY_VALUES JSON NOT NULL DEFAULT '{}';

-- PCP-5960: Script to modify the ENUM type "status" to replace the old and unused ENABLED with REQUIRED
DO $$ BEGIN
    ALTER TYPE STATUS RENAME VALUE 'ENABLED' TO 'REQUIRED';
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'type STATUS already modified to use REQUIRED instead of ENABLED';
END $$;

-- Update database schema at the end (earlier version is 1.2.0 i.e. 3)
UPDATE SCHEMA_VERSION SET version = 4;
