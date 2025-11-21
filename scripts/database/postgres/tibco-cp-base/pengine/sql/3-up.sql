---------------------------------------------------
-- Database schema changes for 1.2.0
-- cic-2/docker/tsc/scripts/postgres/pengine/scripts/metadata.bash should be updated whenever a new file is added
---------------------------------------------------

------------------------------------------------------------------------
--
--  Update permission descriptions only if CASBIN_RULE table exists otherwise updated descriptions will be added to the table
------------------------------------------------------------------------
DO $$ BEGIN

        -- Add details and sortKey in metadata
        UPDATE CASBIN_RULE SET V4 = 'Owner' WHERE V0 = 'OWNER';

        UPDATE CASBIN_RULE SET V4 = 'Team Admin' WHERE V0 = 'TEAM_ADMIN';

        UPDATE CASBIN_RULE SET V4 = 'IdP Manager' WHERE V0 = 'IDP_MANAGER';

        UPDATE CASBIN_RULE SET V4 = 'Data plane Manager' WHERE V0 = 'PLATFORM_OPS';

        UPDATE CASBIN_RULE SET V4 = 'Capability Manager' WHERE V0 = 'DEV_OPS';

        UPDATE CASBIN_RULE SET V4 = 'Application Manager' WHERE V0 = 'CAPABILITY_ADMIN';

        UPDATE CASBIN_RULE SET V4 = 'Application Viewer' WHERE V0 = 'CAPABILITY_USER';

        RAISE NOTICE 'Table CASBIN_RULE exists, hence updated permissions successfully';

    EXCEPTION
			-- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
			WHEN sqlstate '42P01' THEN

                    RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions update';
END $$;

-- Update database schema at the end (earlier version is 1.1.0 i.e. 2)
UPDATE SCHEMA_VERSION SET version = 3;
