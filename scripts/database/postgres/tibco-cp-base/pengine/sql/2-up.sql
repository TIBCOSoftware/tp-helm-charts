---------------------------------------------------
-- Database schema changes for 1.1.0
---------------------------------------------------

------------------------------------------------------------------------
--
--  Update permission descriptions only if CASBIN_RULE table exists otherwise updated descriptions will be added to the table
------------------------------------------------------------------------
DO $$ BEGIN
            -- BROWSE_ASSIGNMENTS permissions applies to CP (PCP-3643: It was wrongly added as applies DP); no need to revert this in 2-down.sql file
            UPDATE CASBIN_RULE SET V1 = 'CP' WHERE V0 = 'BROWSE_ASSIGNMENTS';

            UPDATE CASBIN_RULE SET V5 = '{''assign'':[''SRE'';''ENGG'';''PM'';''PROVISIONER'';''OWNER'';''IDP_MANAGER'';''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''TAG_MANAGER'';''BROWSE_ASSIGNMENTS'';''FIN_OPS'']}' WHERE V0 = 'SRE';

            -- PCP-3774: Remove "Manage Tags" permission from UI
            DELETE FROM CASBIN_RULE WHERE V1 = 'TAG_MANAGER';

            -- Add details and sortKey in metadata
            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Add users and assign permissions to other users including other owners.''; ''Assign `Manage users and user permissions` permission.''; ''Assign `Manage IdP Configuration` permission.'']; ''assign'':[''OWNER'';''IDP_MANAGER'';''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''BROWSE_ASSIGNMENTS'';''FIN_OPS''];''sortKey'':1}' WHERE V0 = 'OWNER';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Configure Single Sign On for the enterprise.''];''sortKey'':2}' WHERE V0 = 'IDP_MANAGER';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Add; edit; and remove other users except owners or IdP managers.''; ''Assign; update; and remove permissions to other users except owners or IdP managers.''; ''View permissions assigned to users.'']; ''assign'':[''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''BROWSE_ASSIGNMENTS''];''sortKey'':3}' WHERE V0 = 'TEAM_ADMIN';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Register; Manage; or De-register a data plane.''];''sortKey'':4}' WHERE V0 = 'PLATFORM_OPS';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Provision or de-provision a Capability.''];''sortKey'':5}' WHERE V0 = 'DEV_OPS';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Deploy; edit; or delete applications for a selected Capability.''];''sortKey'':6}' WHERE V0 = 'CAPABILITY_ADMIN';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Have read-only access to all the applications of Capability.''];''sortKey'':7}' WHERE V0 = 'CAPABILITY_USER';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''View the assigned permissions of all users.''];''sortKey'':8}' WHERE V0 = 'BROWSE_ASSIGNMENTS';

            UPDATE CASBIN_RULE SET V5 = '{''details'': [''Access the FinOps dashboard.''];''sortKey'':9}' WHERE V0 = 'FIN_OPS';

            RAISE NOTICE 'Table CASBIN_RULE exists, hence updated permissions successfully';

    EXCEPTION

            -- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
	        WHEN sqlstate '42P01' THEN

                RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions update';

END $$;

-- Update database schema at the end (earlier version is 1.0.0 i.e. 1)
UPDATE SCHEMA_VERSION SET version = 2;
