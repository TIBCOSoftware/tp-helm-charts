-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------------------------------
-- Rollback database schema changes for PCP-23463 / PCP-23170 (reverse of 6-up.sql).
--
-- 6-up.sql (a) appended 'APPLICATION_OPERATOR' to the 'assign' array in the metadata of
-- OWNER, TEAM_ADMIN and SRE, (b) moved APPLICATION_OPERATOR to sortKey 7 and shifted
-- CAPABILITY_USER / BROWSE_ASSIGNMENTS / FIN_OPS down by one, and (c) reworded the
-- APPLICATION_OPERATOR details string. This file reverses all three and rolls the schema
-- version back. Each UPDATE is scoped by V0 and every REPLACE is a no-op when its pattern
-- is absent, so the file is safe to re-run.
--
-- WHY THIS FILE MUST EXIST. downgradeDBSchema looks for <service>/sql/<N>-down.sql (and an
-- EFS fallback that is only populated from a shipped down script). When it finds none it
-- logs "WARNING: Rollback script not found", returns 0, and never writes SCHEMA_VERSION --
-- so the Job goes green while the database stays at 6. The older chart's pengine pod then
-- runs its check-sql-schema-version init container, which compares for EXACT equality
-- against its own CURRENT_VERSION=5, never matches, and the pod never becomes ready.
-- Before this change pengine resolved to 5 on both the 1.20 and 1.21 lines, so an
-- adjacent-version rollback was a no-op for pengine; introducing version 6 creates that
-- delta, so the matching down script is now required.
---------------------------------------------------------------------------

------------------------------------------------------------------------
--
--  Undo the assign-list, ordering and description changes,
--  only if CASBIN_RULE table exists
------------------------------------------------------------------------
DO $$ BEGIN

            -- SRE and OWNER: reverse of the 6-up.sql append
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5,
                                '''BROWSE_ASSIGNMENTS'';''FIN_OPS'';''APPLICATION_OPERATOR'']',
                                '''BROWSE_ASSIGNMENTS'';''FIN_OPS'']')
             WHERE V0 IN ('SRE', 'OWNER')
               AND V5 LIKE '%APPLICATION_OPERATOR%';

            -- TEAM_ADMIN: reverse of the 6-up.sql append
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5,
                                '''BROWSE_ASSIGNMENTS'';''APPLICATION_OPERATOR'']',
                                '''BROWSE_ASSIGNMENTS'']')
             WHERE V0 = 'TEAM_ADMIN'
               AND V5 LIKE '%APPLICATION_OPERATOR%';

            -- Restore the original description.
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5,
                                '''View; start; stop; scale applications and edit their configurations''',
                                '''View; start; stop; manually scale; and modify the environment variables of applications for a selected data plane or namespace.''')
             WHERE V0 = 'APPLICATION_OPERATOR';

            -- Restore the original ordering: Application Operator back to 10, and the
            -- three shifted roles back up by one.
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':7;''ns-allowed'':true}', '''sortKey'':10;''ns-allowed'':true}')
             WHERE V0 = 'APPLICATION_OPERATOR';

            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':8;''ns-allowed'':true}', '''sortKey'':7;''ns-allowed'':true}')
             WHERE V0 = 'CAPABILITY_USER';

            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':9}', '''sortKey'':8}')
             WHERE V0 = 'BROWSE_ASSIGNMENTS';

            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':10}', '''sortKey'':9}')
             WHERE V0 = 'FIN_OPS';

            RAISE NOTICE 'Table CASBIN_RULE exists, hence reverted the APPLICATION_OPERATOR assign list, role ordering and description successfully';

EXCEPTION

            -- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
                WHEN sqlstate '42P01' THEN

                RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions rollback';

END $$;


-- Roll back database schema version (going from 6 back to 5)
UPDATE SCHEMA_VERSION SET version = 5;
