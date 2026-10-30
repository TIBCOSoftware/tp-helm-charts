-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------
-- Database schema changes for PCP-23463 (parent PCP-23170)
--
-- 1. Allow OWNER, TEAM_ADMIN and SRE to assign the new APPLICATION_OPERATOR role
--    by appending it to the 'assign' array in their metadata.
-- 2. Order Application Operator between Application Manager and Application Viewer in
--    the console: APPLICATION_OPERATOR 10 -> 7, shifting CAPABILITY_USER 7 -> 8,
--    BROWSE_ASSIGNMENTS 8 -> 9 and FIN_OPS 9 -> 10 to make room. The relative order of
--    the shifted roles is unchanged.
-- 3. Reword the APPLICATION_OPERATOR details string shown in the console.
--
-- AMENDED IN PLACE (review follow-up). Items 2 and 3 were added after 1.21.0-alpha.001
-- and -alpha.002 had already shipped schema 6. A Control Plane already at schema 6 will
-- NOT re-run this file, so it picks the new ordering up from policy.csv on the next
-- pengine restart instead. Acceptable here because those are feature-branch alphas; on a
-- released line this would have required a new 7-up.sql.
--
-- SCOPE NOTE. This migration deliberately updates ONLY rows that already exist in
-- CASBIN_RULE. The APPLICATION_OPERATOR rows themselves are NOT inserted here: casbin's
-- primary key is a Meow hash of the row's own content, computed in Go
-- (casbin-pg-adapter/adapter.go policyID()), so it cannot be produced correctly from
-- SQL. Those rows are seeded by PEngine itself, which on every start removes all p-rows
-- from the database and re-adds them from policy.csv (enforcer/enforcer.go
-- RemovePolicies -> AddPoliciesEx). Where the rows DO already exist, the sortKey and
-- details updates below correct them in place.
--
-- The metadata blob is duplicated on every action row of a role, so these statements
-- intentionally match on V0 alone and update all of a role's rows. Targeted REPLACEs are
-- used rather than rewriting the whole blob so that the deliberate SaaS vs self-hosted
-- differences in these rows are preserved. Every REPLACE is a no-op when its pattern is
-- absent, so this file is safe to re-run.
---------------------------------------------------

------------------------------------------------------------------------
--
--  Grant assignment rights, reorder the role and reword its description,
--  only if CASBIN_RULE table exists
------------------------------------------------------------------------
DO $$ BEGIN

            -- SRE and OWNER: their assign array ends with ...;'BROWSE_ASSIGNMENTS';'FIN_OPS']
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5,
                                '''BROWSE_ASSIGNMENTS'';''FIN_OPS'']',
                                '''BROWSE_ASSIGNMENTS'';''FIN_OPS'';''APPLICATION_OPERATOR'']')
             WHERE V0 IN ('SRE', 'OWNER')
               AND V5 LIKE '%''assign''%'
               AND V5 NOT LIKE '%APPLICATION_OPERATOR%';

            -- TEAM_ADMIN: its assign array ends with ...;'BROWSE_ASSIGNMENTS']
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5,
                                '''BROWSE_ASSIGNMENTS'']',
                                '''BROWSE_ASSIGNMENTS'';''APPLICATION_OPERATOR'']')
             WHERE V0 = 'TEAM_ADMIN'
               AND V5 LIKE '%''assign''%'
               AND V5 NOT LIKE '%APPLICATION_OPERATOR%';

            -- Shift the roles that sit after Application Manager down by one so that
            -- Application Operator can take slot 7. Each UPDATE is scoped by V0, so the
            -- 7 -> 8 and 10 -> 7 moves cannot collide regardless of statement order.
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':7;''ns-allowed'':true}', '''sortKey'':8;''ns-allowed'':true}')
             WHERE V0 = 'CAPABILITY_USER';

            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':8}', '''sortKey'':9}')
             WHERE V0 = 'BROWSE_ASSIGNMENTS';

            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':9}', '''sortKey'':10}')
             WHERE V0 = 'FIN_OPS';

            -- Application Operator moves into slot 7, between Application Manager (6)
            -- and Application Viewer (now 8), and gets its reworded description.
            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5, '''sortKey'':10;''ns-allowed'':true}', '''sortKey'':7;''ns-allowed'':true}')
             WHERE V0 = 'APPLICATION_OPERATOR';

            UPDATE CASBIN_RULE
               SET V5 = REPLACE(V5,
                                '''View; start; stop; manually scale; and modify the environment variables of applications for a selected data plane or namespace.''',
                                '''View; start; stop; scale applications and edit their configurations''')
             WHERE V0 = 'APPLICATION_OPERATOR';

            RAISE NOTICE 'Table CASBIN_RULE exists, hence granted APPLICATION_OPERATOR assignment to OWNER, TEAM_ADMIN and SRE and applied the role ordering and description updates successfully';

EXCEPTION

            -- Handle sqlstate=42P01 i.e. undefined_table/relation "[Table]" does not exist. Ref: https://www.postgresql.org/docs/current/errcodes-appendix.html
                WHEN sqlstate '42P01' THEN

                RAISE NOTICE 'Table CASBIN_RULE does not exists, hence skipping permissions update';

END $$;


-- Update database schema at the end (earlier version is 1.18.0 i.e. 5)
UPDATE SCHEMA_VERSION SET version = 6;
