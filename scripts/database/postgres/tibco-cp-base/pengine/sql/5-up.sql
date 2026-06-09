---------------------------------------------------
-- Database schema changes for PCP-10813
-- Add 'ns-allowed':true metadata to CAPABILITY_ADMIN and CAPABILITY_USER
-- to enable namespace-scoped permission assignments for these roles.
---------------------------------------------------

------------------------------------------------------------------------
--
--  Update CAPABILITY_ADMIN and CAPABILITY_USER metadata to include 'ns-allowed':true
--  only if CASBIN_RULE table exists
------------------------------------------------------------------------
DO $$ BEGIN

            -- Add 'ns-allowed':true to CAPABILITY_ADMIN metadata
            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Deploy; edit; or delete applications for a selected Capability.''];''sortKey'':6;''ns-allowed'':true}' WHERE V0 = 'CAPABILITY_ADMIN';

            -- Add 'ns-allowed':true to CAPABILITY_USER metadata
            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Have read-only access to all the applications of Capability.''];''sortKey'':7;''ns-allowed'':true}' WHERE V0 = 'CAPABILITY_USER';

            RAISE NOTICE 'Table CASBIN_RULE exists, hence updated CAPABILITY_ADMIN and CAPABILITY_USER metadata with ns-allowed successfully';

EXCEPTION

            -- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
                WHEN sqlstate '42P01' THEN

                RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions update';

END $$;


-- Update database schema at the end (earlier version is 1.14.0 i.e. 4)
UPDATE SCHEMA_VERSION SET version = 5;
