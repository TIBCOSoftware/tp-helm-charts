-- Database schema changes for 1.14.0

-- PCP-14408: [CP-script] Support team resources storage in UTD DB
-- Teams carry their own resource lists: users and idp groups
-- Ensures teams are automatically removed when the owning account is deleted
CREATE TABLE IF NOT EXISTS  v3_teams (
                                         team_id        INT NOT NULL,
                                         tsc_account_id VARCHAR(255) NOT NULL,
    name           VARCHAR(96) NOT NULL,
    description    VARCHAR(255),
    users          TEXT[] DEFAULT '{}',      -- user IDs directly in this team
    idp_groups     JSONB DEFAULT '{}'::jsonb, -- idp group IDs directly in this team

    PRIMARY KEY (tsc_account_id, team_id),
    FOREIGN KEY (tsc_account_id)
    REFERENCES v2_accounts (tsc_account_id)
    ON DELETE CASCADE
    );

CREATE OR REPLACE FUNCTION assign_team_id()
RETURNS trigger AS $$
BEGIN
  IF NEW.team_id IS NULL THEN
SELECT COALESCE(MAX(team_id), 0) + 1
INTO NEW.team_id
FROM v3_teams
WHERE tsc_account_id = NEW.tsc_account_id;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_team_id_trigger ON v3_teams;
CREATE TRIGGER set_team_id_trigger BEFORE INSERT ON v3_teams FOR EACH row EXECUTE FUNCTION assign_team_id();

-- Only describes team nesting relationships
CREATE TABLE IF NOT EXISTS v3_teams_relations (
                                                  parent_team_id INT NOT NULL,
                                                  child_team_id  INT NOT NULL,
                                                  tsc_account_id VARCHAR(255) NOT NULL,
    PRIMARY KEY (tsc_account_id, parent_team_id, child_team_id),
    FOREIGN KEY (tsc_account_id, parent_team_id)
    REFERENCES v3_teams (tsc_account_id, team_id)
    ON DELETE CASCADE,
    FOREIGN KEY (tsc_account_id, child_team_id)
    REFERENCES v3_teams (tsc_account_id, team_id)
    ON DELETE CASCADE
    );

CREATE OR REPLACE FUNCTION get_children(parent_id INT, parent_account_id VARCHAR)
RETURNS JSONB LANGUAGE sql AS $$
SELECT COALESCE(jsonb_agg(
                        jsonb_build_object(
                                'team_id', c.team_id,
                                'tsc_account_id', c.tsc_account_id,
                                'name', c.name,
                                'description', c.description,
                                'users', c.users,
                                'idp_groups', c.idp_groups,
                                'teams', COALESCE(get_children(c.team_id, c.tsc_account_id), '[]'::jsonb)
                        )
                ), '[]'::jsonb)
FROM v3_teams c
         JOIN v3_teams_relations r
              ON r.child_team_id = c.team_id
                  AND r.tsc_account_id = c.tsc_account_id
WHERE r.parent_team_id = parent_id
  AND r.tsc_account_id = parent_account_id;
$$;

CREATE OR REPLACE FUNCTION get_team_hierarchy(p_team_id BIGINT, p_tsc_account_id VARCHAR)
RETURNS jsonb LANGUAGE plpgsql STABLE
AS $$
BEGIN
RETURN (
    WITH RECURSIVE traversal AS (
        -- Start from the root
        SELECT
            t.team_id AS root_id,
            t.team_id,
            t.tsc_account_id,
            0 AS depth
        FROM v3_teams t
        WHERE t.team_id = p_team_id
          AND t.tsc_account_id = p_tsc_account_id

        UNION ALL

        -- Traverse down
        SELECT
            tr.root_id,
            c.team_id,
            c.tsc_account_id,
            tr.depth + 1
        FROM traversal tr
                 JOIN v3_teams_relations r
                      ON tr.team_id = r.parent_team_id
                          AND tr.tsc_account_id = r.tsc_account_id
                 JOIN v3_teams c
                      ON r.child_team_id = c.team_id
                          AND r.tsc_account_id = c.tsc_account_id
    ),
                   max_depth AS (
                       SELECT root_id, MAX(depth) AS depth
                       FROM traversal
                       GROUP BY root_id
                   )
    -- Build JSON recursively
    SELECT jsonb_build_object(
                   'team_id', root.team_id,
                   'tsc_account_id', root.tsc_account_id,
                   'name', root.name,
                   'description', root.description,
                   'depth', md.depth,  -- only root has depth
                   'users', root.users,
                   'idp_groups', root.idp_groups,
                   'teams', COALESCE(get_children(root.team_id, root.tsc_account_id), '[]'::jsonb)
           ) AS team_hierarchy
    FROM v3_teams root
             JOIN max_depth md
                  ON root.team_id = md.root_id
                      AND root.tsc_account_id = p_tsc_account_id
    WHERE root.team_id = p_team_id
      AND root.tsc_account_id = p_tsc_account_id
);
END;
$$;

CREATE OR REPLACE FUNCTION get_team_depth(
    p_team_id BIGINT,
    p_tsc_account_id VARCHAR
)
RETURNS jsonb
LANGUAGE sql
STABLE AS
$$
WITH RECURSIVE traversal AS (
    -- Start from the root's children
    SELECT
        r.parent_team_id AS root_id,
        r.child_team_id  AS team_id,
        1 AS depth
    FROM v3_teams_relations r
    WHERE r.parent_team_id = p_team_id
      AND r.tsc_account_id = p_tsc_account_id

    UNION ALL

    -- Recurse down
    SELECT
        tr.root_id,
        r.child_team_id,
        tr.depth + 1
    FROM traversal tr
    JOIN v3_teams_relations r
      ON tr.team_id = r.parent_team_id
     AND r.tsc_account_id = p_tsc_account_id
),
max_depth AS (
    SELECT COALESCE(MAX(depth), 0) AS depth
    FROM traversal
)
SELECT CASE
           WHEN EXISTS (
               SELECT 1
               FROM v3_teams t
               WHERE t.team_id = p_team_id
                 AND t.tsc_account_id = p_tsc_account_id
           )
               THEN jsonb_build_object('team_id', p_team_id, 'depth', (SELECT depth FROM max_depth))
           ELSE jsonb_build_object('team_id', p_team_id, 'depth', -1)
           END;
$$;

CREATE OR REPLACE FUNCTION will_cause_cycle(
    p_parent_id BIGINT,
    p_child_id BIGINT,
    p_account_id VARCHAR
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE AS
$$
WITH RECURSIVE descendants AS (
    SELECT r.child_team_id
    FROM v3_teams_relations r
    WHERE r.parent_team_id = p_child_id
      AND r.tsc_account_id = p_account_id

    UNION ALL

    SELECT r.child_team_id
    FROM v3_teams_relations r
    INNER JOIN descendants d
      ON r.parent_team_id = d.child_team_id
    WHERE r.tsc_account_id = p_account_id
)
SELECT EXISTS (
    SELECT 1
    FROM descendants
    WHERE child_team_id = p_parent_id
);
$$;

-- PCP-15096 [CP-Orch] add an API to list a team's immediate parents
CREATE OR REPLACE FUNCTION get_parent_teams(target_team_id INT, target_account_id VARCHAR)
RETURNS SETOF JSONB
LANGUAGE plpgsql AS
$$
BEGIN
RETURN QUERY
    WITH RECURSIVE parent_hierarchy AS (
        -- Start with the given team
        SELECT
            t.team_id,
            t.name,
            NULL::INT AS parent_team_id,
            0 AS distance,
            t.tsc_account_id
        FROM v3_teams t
        WHERE t.team_id = target_team_id
          AND t.tsc_account_id = target_account_id

        UNION ALL

        -- Move upward to parents
        SELECT
            pt.team_id,
            pt.name,
            tr.parent_team_id,
            ph.distance + 1 AS distance,
            pt.tsc_account_id
        FROM v3_teams_relations tr
        JOIN v3_teams pt
          ON tr.parent_team_id = pt.team_id
         AND tr.tsc_account_id = pt.tsc_account_id
        JOIN parent_hierarchy ph
          ON tr.child_team_id = ph.team_id
         AND tr.tsc_account_id = ph.tsc_account_id
    )
SELECT jsonb_build_object(
               'team_id', team_id,
               'name', name,
               'distance', distance,
               'tsc_account_id', tsc_account_id
       )
FROM parent_hierarchy
WHERE distance > 0
ORDER BY distance;
END;
$$;

-- PCP-15230 : [CP-UserSubscriptions] Updated /v2/accounts/<accountId>/users API to include user's last known LDAP group and team membership
ALTER TABLE V2_ACCOUNT_USER_DETAILS ADD COLUMN IF NOT EXISTS TEAM_MEMBERSHIP JSONB DEFAULT '[]'::jsonb;

-- Update database schema at the end (earlier version is 1.13.0 i.e. 13)
UPDATE schema_version SET version = 17;