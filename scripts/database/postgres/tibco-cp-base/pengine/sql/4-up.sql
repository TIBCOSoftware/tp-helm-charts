---------------------------------------------------
-- Database schema changes for 1.14.0
---------------------------------------------------

------------------------------------------------------------------------
--
--  Update permission descriptions only if CASBIN_RULE table exists otherwise updated descriptions will be added to the table
------------------------------------------------------------------------
DO $$ BEGIN

            -- Update details
UPDATE CASBIN_RULE SET V5 = '{''details'': [''Manage Subscriptions (Provision; Update; Delete; View)''; ''Manage Console Users (Add; Remove)''; ''Manage User Permissions (Assign; Update)''; ''Manage Teams Permissions (Assign; Update)''; ''and Manage Single Sign On (Configure; Update; View; Delete)'']; ''assign'':[''SRE'';''VIEWER'';''PM'';''PROVISIONER'';''OWNER'';''IDP_MANAGER'';''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''BROWSE_ASSIGNMENTS'';''FIN_OPS''];''sortKey'':1}' WHERE V0 = 'SRE';

UPDATE CASBIN_RULE SET V5 = '{''details'': [''Add users and assign permissions to other users including other owners.''; ''Assign `Manage users and user permissions` permission.''; ''Create and manage teams; assign and manage teams permissions.''; ''Assign `Manage IdP Configuration` permission.'']; ''assign'':[''OWNER'';''IDP_MANAGER'';''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''BROWSE_ASSIGNMENTS'';''FIN_OPS''];''sortKey'':1}' WHERE V0 = 'OWNER';

UPDATE CASBIN_RULE SET V5 = '{''details'': [''Add; edit; and remove other users except owners or IdP managers.''; ''Assign; update; and remove permissions to other users except owners or IdP managers.''; ''View permissions assigned to users.''; ''Create and manage teams; assign and manage teams permissions.'']; ''assign'':[''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''BROWSE_ASSIGNMENTS''];''sortKey'':3}' WHERE V0 = 'TEAM_ADMIN';

RAISE NOTICE 'Table CASBIN_RULE exists, hence updated permissions successfully';

EXCEPTION

            -- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
                WHEN sqlstate '42P01' THEN

                RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions update';

END $$;


-- Update database schema at the end (earlier version is 1.13.0 i.e. 3)
UPDATE SCHEMA_VERSION SET version = 4;
