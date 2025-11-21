------------------------------------------------------------------------
--
--  Update permission descriptions only if CASBIN_RULE table exists otherwise updated descriptions will be added to the table
------------------------------------------------------------------------
DO $$ BEGIN
            UPDATE CASBIN_RULE SET V4 = 'Manage Subscriptions (Provision; Update; Delete; View); Manage Users (View); Manage User Permissions (Assign Update)' WHERE V0 = 'SRE';

            UPDATE CASBIN_RULE SET V4 = 'View subscriptions; users; and permissions' WHERE V0 = 'ENGG';

            UPDATE CASBIN_RULE SET V4 = 'Provision and view Subscriptions' WHERE V0 = 'PROVISIONER';

            UPDATE CASBIN_RULE SET V4 = 'Assign TeamAdmin; or Owner permission' WHERE V0 = 'OWNER';

            UPDATE CASBIN_RULE SET V4 = 'Manage Dataplanes (Register; De-register)' WHERE V0 = 'PLATFORM_OPS';

            UPDATE CASBIN_RULE SET V4 = 'Manage Capabilities (Provision; De-provision)' WHERE V0 = 'DEV_OPS';

            UPDATE CASBIN_RULE SET V4 = 'Manage applications (Deploy; Undeploy; View; Delete)' WHERE V0 = 'CAPABILITY_ADMIN';

            UPDATE CASBIN_RULE SET V4 = 'View applications' WHERE V0 = 'CAPABILITY_USER';

            UPDATE CASBIN_RULE SET V4 = 'Manage Tags (Create; Update; Delete)' WHERE V0 = 'TAG_MANAGER';

            UPDATE CASBIN_RULE SET V4 = 'View permissions' WHERE V0 = 'BROWSE_ASSIGNMENTS';

            UPDATE CASBIN_RULE SET V4 = 'View FinOps dashboard' WHERE V0 = 'FIN_OPS';

            -- Update metadata, allow OWNER to assign any permission
            UPDATE CASBIN_RULE SET V5 = '{''assign'':[''OWNER'';''IDP_MANAGER'';''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''TAG_MANAGER'';''BROWSE_ASSIGNMENTS'';''FIN_OPS'']}' WHERE V0 = 'OWNER';

            -- Update metadata, allow TEAM_ADMIN to assign only new TEAM_ADMIN, PLATFORM_OPS, DEV_OPS, CAPABILITY_ADMIN, CAPABILITY_USER, TAG_MANAGER and BROWSE_ASSIGNMENTS permission
            -- i.e. Prohibit assigning OWNER, IDP_MANAGER or DIN_OPS, these can be assigned only by OWNER
            UPDATE CASBIN_RULE SET V5 = '{''assign'':[''TEAM_ADMIN'';''PLATFORM_OPS'';''DEV_OPS'';''CAPABILITY_ADMIN'';''CAPABILITY_USER'';''TAG_MANAGER'';''BROWSE_ASSIGNMENTS'']}' WHERE V0 = 'TEAM_ADMIN';

            RAISE NOTICE 'Table CASBIN_RULE exists, hence updated permissions successfully';

      EXCEPTION
		-- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
		WHEN sqlstate '42P01' THEN

                  RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions update';
END $$;


------------------------------------------------------------------------
--
--  Name: SCHEMA_VERSION
--
------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS SCHEMA_VERSION (
      ID SERIAL PRIMARY KEY,
      VERSION INTEGER NOT NULL,

      CONSTRAINT SCHEMA_VERSION_UNIQUE_CONSTRAINT UNIQUE (VERSION)
);

INSERT INTO SCHEMA_VERSION (VERSION) VALUES (1) ON CONFLICT DO NOTHING;
