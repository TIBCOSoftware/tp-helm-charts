-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Database schema changes for 1.19.0

-- GIN indexes on RESOURCE_INSTANCE_IDS arrays to support fast @> lookups in the
-- delete-validation trigger. V3_CAPABILITY_INSTANCES already has one (21-up.sql).
CREATE INDEX IF NOT EXISTS idx_data_planes_resource_instance_ids_gin
    ON V3_DATA_PLANES USING GIN (RESOURCE_INSTANCE_IDS);

CREATE INDEX IF NOT EXISTS idx_apps_resource_instance_ids_gin
    ON V3_APPS USING GIN (RESOURCE_INSTANCE_IDS);

-- BEFORE DELETE trigger on V3_RESOURCE_INSTANCES.
--
-- Deletion is blocked based on the resource instance's scope:
--
--   scope = DATAPLANE  : blocked if actively used by V3_CAPABILITY_INSTANCES or V3_APPS.
--                        V3_DATA_PLANES is the scope-link table (populated at creation)
--                        and is intentionally NOT checked.
--
--   scope = SUBSCRIPTION: blocked if referenced by V3_DATA_PLANES (data planes explicitly
--                          pull in subscription-level resources), V3_CAPABILITY_INSTANCES,
--                          or V3_APPS.
--
-- Uses @> (array containment) so GIN indexes are always chosen.
-- Uses UNION ALL with per-subquery LIMIT 1 so PostgreSQL short-circuits on the
-- first match without scanning remaining tables.
DROP FUNCTION IF EXISTS V3_VALIDATE_RESOURCE_INSTANCE_DELETE() CASCADE;

CREATE FUNCTION V3_VALIDATE_RESOURCE_INSTANCE_DELETE()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $FUNCTION$
DECLARE
    ref_table TEXT;
BEGIN
    SELECT tbl INTO ref_table FROM (
        (SELECT 'V3_DATA_PLANES' AS tbl
            FROM V3_DATA_PLANES
            WHERE OLD.SCOPE = 'SUBSCRIPTION'
              AND RESOURCE_INSTANCE_IDS @> ARRAY[OLD.RESOURCE_INSTANCE_ID::TEXT]
            LIMIT 1)
        UNION ALL
        (SELECT 'V3_CAPABILITY_INSTANCES'
            FROM V3_CAPABILITY_INSTANCES
            WHERE RESOURCE_INSTANCE_IDS @> ARRAY[OLD.RESOURCE_INSTANCE_ID::TEXT]
            LIMIT 1)
        UNION ALL
        (SELECT 'V3_APPS'
            FROM V3_APPS
            WHERE RESOURCE_INSTANCE_IDS @> ARRAY[OLD.RESOURCE_INSTANCE_ID::TEXT]
            LIMIT 1)
    ) refs LIMIT 1;

    IF ref_table IS NOT NULL THEN
        RAISE EXCEPTION 'RESOURCE_INSTANCE_ID % is still in use by %',
            OLD.RESOURCE_INSTANCE_ID, ref_table;
    END IF;

    RETURN OLD;
END;
$FUNCTION$
;

DROP TRIGGER IF EXISTS V3_VALIDATE_RESOURCE_INSTANCE_DELETE_TRIGGER ON V3_RESOURCE_INSTANCES;

CREATE TRIGGER V3_VALIDATE_RESOURCE_INSTANCE_DELETE_TRIGGER
    BEFORE DELETE ON V3_RESOURCE_INSTANCES
    FOR EACH ROW EXECUTE PROCEDURE V3_VALIDATE_RESOURCE_INSTANCE_DELETE();


DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE AS
WITH
ns_ri AS (
    SELECT
        RI.RESOURCE_INSTANCE_ID,
        RI.RESOURCE_INSTANCE_NAME   AS namespace_name,
        CASE WHEN RI.RESOURCE_INSTANCE_METADATA->'fields'
                  @> '[{"key":"isPrimary","value":true}]'::jsonb
             THEN 0 ELSE 1 END      AS primary_order
    FROM V3_RESOURCE_INSTANCES RI
    WHERE RI.RESOURCE_ID = 'NAMESPACE'
      AND RI.SCOPE       = 'DATAPLANE'
),
ci_ns AS (
    SELECT DISTINCT ON (CI.CAPABILITY_INSTANCE_ID)
        CI.CAPABILITY_INSTANCE_ID,
        NS.namespace_name
    FROM  V3_CAPABILITY_INSTANCES CI,
          unnest(CI.RESOURCE_INSTANCE_IDS) AS ri_id
    JOIN  ns_ri NS ON NS.resource_instance_id = ri_id
    ORDER BY CI.CAPABILITY_INSTANCE_ID, NS.primary_order
)
SELECT
    DP.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAME AS DP_NAME,
    CI.CAPABILITY_ID,
    cn.namespace_name AS NAMESPACE,
    CI.VERSION,
    CI.STATUS,
    CI.MONITORING_STATUS,
    CI.REGION,
    CI.CREATED_TIME,
    CI.MODIFIED_TIME,
    (select CONCAT(U.firstname || ' ',lastname) from v2_users U where U.USER_ENTITY_ID = CI.MODIFIED_BY)
            as MODIFIED_BY,
    (select CONCAT(U.firstname|| ' ',lastname) from v2_users U where U.USER_ENTITY_ID = CI.CREATED_BY)
            as CREATED_BY,
    CI.TAGS,
    CI.CAPABILITY_INSTANCE_ID,
    CI.CAPABILITY_INSTANCE_NAME,
    CI.CAPABILITY_INSTANCE_DESCRIPTION,
    COALESCE(
            (
                SELECT JSON_AGG(
                               JSON_BUILD_OBJECT(
                                       'id', RI.RESOURCE_INSTANCE_ID,
                                       'name', RI.RESOURCE_INSTANCE_NAME
                               )
                       )
                FROM V3_RESOURCE_INSTANCES RI
                WHERE RI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS)
            ),
            '[]'::JSON
    ) AS "resource_instances",
    CI.CAPABILITY_TYPE
FROM V3_CAPABILITY_INSTANCES CI
         LEFT JOIN ci_ns cn         USING (CAPABILITY_INSTANCE_ID)
         LEFT JOIN V3_DATA_PLANES DP USING (DP_ID)
-- No CAPABILITY_TYPE filter: view returns both PLATFORM and INFRA rows.
    WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_INDEX ON V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
    (SUBSCRIPTION_ID, DP_ID,CAPABILITY_INSTANCE_ID);

DROP FUNCTION IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE;
RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_CI_TRIGGER AFTER
    INSERT OR DELETE
    OR UPDATE OF DP_ID, CAPABILITY_ID, CAPABILITY_TYPE, VERSION, STATUS,
                 MONITORING_STATUS, REGION, CREATED_TIME, MODIFIED_TIME, CREATED_BY,
                 MODIFIED_BY, TAGS, CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME,
                 CAPABILITY_INSTANCE_DESCRIPTION, RESOURCE_INSTANCE_IDS
    ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT
    EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();


DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_DP_TRIGGER
    AFTER INSERT OR DELETE
OR UPDATE OF NAME, SUBSCRIPTION_ID, DP_ID
   ON V3_DATA_PLANES
       FOR EACH STATEMENT
       EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

--
-- New consolidated view that merges V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_DATAPLANES
-- and V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_CAPABILITIES into a single materialized view.
-- The two source views are disjoint by RI.SCOPE ('SUBSCRIPTION' vs 'DATAPLANE'), so a
-- UNION ALL preserves all rows without duplication. SCOPE_ID is kept as-is (not aliased
-- to SUBSCRIPTION_ID / DP_ID) so a single (RESOURCE_INSTANCE_ID, RESOURCE_ID, SCOPE,
-- SCOPE_ID) tuple uniquely identifies every row across both branches and can back the
-- unique index required for CONCURRENT refresh.
--
-- Scope differences vs the original two views:
--   * RESOURCE_LEVEL = 'INFRA' rows are excluded (except RESOURCE_ID = 'STORAGE').
--     This is intentional - INFRA rows are not surfaced to any caller of this view.
--
-- Performance shape:
--   * ri_filtered CTE is MATERIALIZED so V3_RESOURCE_INSTANCES is scanned once across
--     both UNION branches (PG >= 12 would otherwise inline and double-scan).
--   * dp_ri / ci_ri unnest RESOURCE_INSTANCE_IDS with DISTINCT inside LATERAL, turning
--     each = ANY(array) into a hash/merge equality join.
--
-- The original two views (V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_DATAPLANES and
-- V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_CAPABILITIES) are removed below as they are
-- fully replaced by V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES.
--

-- Remove the old materialized views, their refresh functions and associated triggers.
-- DROP MATERIALIZED VIEW ... CASCADE removes dependent indexes; DROP FUNCTION ... CASCADE
-- removes the triggers that reference these refresh functions.
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_DATAPLANES CASCADE;
DROP FUNCTION IF EXISTS V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_DATAPLANES_REFRESH() CASCADE;

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_CAPABILITIES CASCADE;
DROP FUNCTION IF EXISTS V3_VIEW_RESOURCE_INSTANCE_WITH_LINKED_CAPABILITIES_REFRESH() CASCADE;

-- Supporting indexes for the joins below. All IF NOT EXISTS — they benefit other queries
-- on the same tables too, so it's fine if a future migration created them already.
CREATE INDEX IF NOT EXISTS idx_data_planes_subscription_id
    ON V3_DATA_PLANES (SUBSCRIPTION_ID);
CREATE INDEX IF NOT EXISTS idx_capability_instances_dp_id
    ON V3_CAPABILITY_INSTANCES (DP_ID);
-- Partial index mirrors the WHERE clause of ri_filtered below; lets the planner read only
-- the SUBSCRIPTION/DATAPLANE-scoped, non-INFRA (or STORAGE) rows of V3_RESOURCE_INSTANCES.
CREATE INDEX IF NOT EXISTS idx_resource_instances_scope_for_linked_entities
    ON V3_RESOURCE_INSTANCES (SCOPE, SCOPE_ID)
    WHERE SCOPE IN ('SUBSCRIPTION', 'DATAPLANE')
    AND (RESOURCE_LEVEL <> 'INFRA' OR RESOURCE_ID = 'STORAGE');

DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES CASCADE;

CREATE MATERIALIZED VIEW V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES AS
WITH
-- ri_filtered: single scan over V3_RESOURCE_INSTANCES with the shared scope+level filter.
-- MATERIALIZED is required: on PG >= 12 the planner inlines CTEs by default, which would
-- scan the source table once per UNION branch. MATERIALIZED forces a single scan.
ri_filtered AS MATERIALIZED (
    SELECT
        RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_NAME,
        RESOURCE_INSTANCE_DESCRIPTION, SCOPE, SCOPE_ID, REGION,
        RESOURCE_INSTANCE_METADATA, CREATED_BY, MODIFIED_BY,
        CREATED_TIME, MODIFIED_TIME, RESOURCE_LEVEL, CAPABILITY_ID, RESOURCE_TYPE
    FROM V3_RESOURCE_INSTANCES
    WHERE SCOPE IN ('SUBSCRIPTION', 'DATAPLANE')
      AND (RESOURCE_LEVEL <> 'INFRA' OR RESOURCE_ID = 'STORAGE')
),
-- dp_ri / ci_ri: unnest RESOURCE_INSTANCE_IDS so the join can be a hash/merge equality
-- join instead of a per-row array scan from = ANY(). DISTINCT is applied INSIDE the
-- LATERAL so it dedupes only repeated ids within a single source row's array; it does
-- NOT collapse two distinct CI rows that happen to share the projected columns. This
-- preserves the original = ANY() row count.
dp_ri AS (
    SELECT DP.DP_ID, DP.NAME, DP.SUBSCRIPTION_ID, U.RESOURCE_INSTANCE_ID
    FROM V3_DATA_PLANES DP,
         LATERAL (SELECT DISTINCT UNNEST(DP.RESOURCE_INSTANCE_IDS) AS RESOURCE_INSTANCE_ID) U
),
ci_ri AS (
    SELECT CI.CAPABILITY_INSTANCE_ID, CI.CAPABILITY_INSTANCE_NAME, CI.CAPABILITY_ID,
           CI.DP_ID, U.RESOURCE_INSTANCE_ID
    FROM V3_CAPABILITY_INSTANCES CI,
         LATERAL (SELECT DISTINCT UNNEST(CI.RESOURCE_INSTANCE_IDS) AS RESOURCE_INSTANCE_ID) U
)

-- SUBSCRIPTION-scoped RIs: aggregate linked data planes (SCOPE_ID is the subscription_id)
SELECT
    RI.RESOURCE_INSTANCE_ID,
    RI.RESOURCE_ID,
    RI.RESOURCE_INSTANCE_NAME,
    RI.RESOURCE_INSTANCE_DESCRIPTION,
    RI.SCOPE,
    RI.SCOPE_ID,
    RI.SCOPE_ID                              AS SUBSCRIPTION_ID,
    NULL::TEXT                               AS DP_NAME,
    RI.REGION,
    RI.RESOURCE_INSTANCE_METADATA,
    RI.CREATED_BY,
    RI.MODIFIED_BY,
    RI.CREATED_TIME,
    RI.MODIFIED_TIME,
    RI.RESOURCE_LEVEL,
    RI.CAPABILITY_ID,
    RI.RESOURCE_TYPE,
    COALESCE(
            JSON_AGG(JSON_BUILD_OBJECT('id', DP.DP_ID, 'name', DP.NAME))
            FILTER (WHERE DP.DP_ID IS NOT NULL),
            '[]'::JSON
    )                                        AS LINKED_DATAPLANES,
    '[]'::JSON                               AS LINKED_CAPABILITIES
FROM ri_filtered RI
         LEFT JOIN dp_ri DP
                   ON  RI.SCOPE_ID             = DP.SUBSCRIPTION_ID
                       AND RI.RESOURCE_INSTANCE_ID = DP.RESOURCE_INSTANCE_ID
WHERE RI.SCOPE = 'SUBSCRIPTION'
GROUP BY
    RI.RESOURCE_INSTANCE_ID,
    RI.RESOURCE_ID,
    RI.RESOURCE_INSTANCE_NAME,
    RI.RESOURCE_INSTANCE_DESCRIPTION,
    RI.SCOPE,
    RI.SCOPE_ID,
    RI.REGION,
    RI.RESOURCE_INSTANCE_METADATA,
    RI.CREATED_BY,
    RI.MODIFIED_BY,
    RI.CREATED_TIME,
    RI.MODIFIED_TIME,
    RI.RESOURCE_LEVEL,
    RI.CAPABILITY_ID,
    RI.RESOURCE_TYPE

UNION ALL

-- DATAPLANE-scoped RIs: aggregate linked capability instances (SCOPE_ID is the dp_id)
SELECT
    RI.RESOURCE_INSTANCE_ID,
    RI.RESOURCE_ID,
    RI.RESOURCE_INSTANCE_NAME,
    RI.RESOURCE_INSTANCE_DESCRIPTION,
    RI.SCOPE,
    RI.SCOPE_ID,
    DP.SUBSCRIPTION_ID,
    DP.NAME                                  AS DP_NAME,
    RI.REGION,
    RI.RESOURCE_INSTANCE_METADATA,
    RI.CREATED_BY,
    RI.MODIFIED_BY,
    RI.CREATED_TIME,
    RI.MODIFIED_TIME,
    RI.RESOURCE_LEVEL,
    RI.CAPABILITY_ID,
    RI.RESOURCE_TYPE,
    '[]'::JSON                               AS LINKED_DATAPLANES,
    COALESCE(
            JSON_AGG(JSON_BUILD_OBJECT(
                    'id',         CI.CAPABILITY_INSTANCE_ID,
                    'name',       CI.CAPABILITY_INSTANCE_NAME,
                    'capability', CI.CAPABILITY_ID))
            FILTER (WHERE CI.CAPABILITY_INSTANCE_ID IS NOT NULL),
            '[]'::JSON
    )                                        AS LINKED_CAPABILITIES
FROM ri_filtered RI
         LEFT JOIN V3_DATA_PLANES DP
                   ON RI.SCOPE_ID = DP.DP_ID
         LEFT JOIN ci_ri CI
                   ON  RI.SCOPE_ID             = CI.DP_ID
                       AND RI.RESOURCE_INSTANCE_ID = CI.RESOURCE_INSTANCE_ID
WHERE RI.SCOPE = 'DATAPLANE'
GROUP BY
    RI.RESOURCE_INSTANCE_ID,
    RI.RESOURCE_ID,
    RI.RESOURCE_INSTANCE_NAME,
    RI.RESOURCE_INSTANCE_DESCRIPTION,
    RI.SCOPE,
    RI.SCOPE_ID,
    DP.SUBSCRIPTION_ID,
    DP.NAME,
    RI.REGION,
    RI.RESOURCE_INSTANCE_METADATA,
    RI.CREATED_BY,
    RI.MODIFIED_BY,
    RI.CREATED_TIME,
    RI.MODIFIED_TIME,
    RI.RESOURCE_LEVEL,
    RI.CAPABILITY_ID,
    RI.RESOURCE_TYPE
    WITH DATA;


CREATE UNIQUE INDEX IF NOT EXISTS V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_INDEX
    ON V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES (RESOURCE_INSTANCE_ID);

DROP FUNCTION IF EXISTS V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH() CASCADE;
CREATE FUNCTION V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES;
RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_RI_TRIGGER
    AFTER INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_NAME,
                 RESOURCE_INSTANCE_DESCRIPTION, SCOPE, SCOPE_ID, REGION,
                 RESOURCE_INSTANCE_METADATA, CREATED_BY, MODIFIED_BY, CREATED_TIME,
                 MODIFIED_TIME, RESOURCE_LEVEL, CAPABILITY_ID, RESOURCE_TYPE
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT
    EXECUTE PROCEDURE V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH();


DROP TRIGGER IF EXISTS V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_DP_TRIGGER
    AFTER INSERT OR DELETE
OR UPDATE OF NAME, SUBSCRIPTION_ID, DP_ID, RESOURCE_INSTANCE_IDS
   ON V3_DATA_PLANES
       FOR EACH STATEMENT
       EXECUTE PROCEDURE V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH();


DROP TRIGGER IF EXISTS V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_CI_TRIGGER
    AFTER INSERT OR DELETE
OR UPDATE OF CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_ID, DP_ID, RESOURCE_INSTANCE_IDS
   ON V3_CAPABILITY_INSTANCES
       FOR EACH STATEMENT
       EXECUTE PROCEDURE V3_VIEW_RESOURCE_INSTANCE_LINKED_ENTITIES_REFRESH();

-- PCP-15443 : Add SQL statement for inserting Spring Boot capability metadata
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('SB','Spring Boot','Spring Boot, an open-source, Java-based framework used to create stand-alone, production-grade Spring applications.','PLATFORM')
    ON CONFLICT DO NOTHING;

-- PCP-18723, PCP-21006, PCP-21144 :
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('AS','TIBCO ActiveSpaces®','TIBCO ActiveSpaces® is a distributed, in-memory data grid that provides high availability and low latency access to data for real-time applications.','PLATFORM')
    ON CONFLICT DO NOTHING;

INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('FTL','TIBCO FTL®','TIBCO FTL® is a lightweight high-performance messaging platform providing reliable, high volume, low latency messaging.','PLATFORM')
    ON CONFLICT DO NOTHING;

UPDATE V3_CAPABILITY_METADATA SET DISPLAY_NAME = 'TIBCO ActiveSpaces®', DESCRIPTION = 'TIBCO ActiveSpaces® is a distributed, in-memory data grid that provides high availability and low latency access to data for real-time applications.' WHERE CAPABILITY_ID = 'AS';
UPDATE V3_CAPABILITY_METADATA SET DISPLAY_NAME = 'TIBCO FTL®', DESCRIPTION = 'TIBCO FTL® is a lightweight high-performance messaging platform providing reliable, high volume, low latency messaging.' WHERE CAPABILITY_ID = 'FTL';

-- PCP-17906 : Add MCPGATEWAY as a PLATFORM Capability
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('MCPGATEWAY', 'MCP Gateway', 'MCP Gateway enables Model Context Protocol (MCP) integration on data planes', 'PLATFORM')
    ON CONFLICT DO NOTHING;

-- PCP-20465 : Add INFRAMCPSERVER as a PLATFORM Capability (Infra MCP Server)
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('INFRAMCPSERVER', 'TIBCO® Platform Infra Model Context Protocol (MCP) Server', 'A secure, read-only Model Context Protocol (MCP) server for each TIBCO Platform Data Plane that lets TESSA run kubectl and helm commands for real-time, AI-driven troubleshooting, to diagnose and provide root cause analysis without direct cluster access for end users.', 'PLATFORM')
    ON CONFLICT DO NOTHING;

-- PCP-19083 : Register Spring Boot as a Control Plane feature so it can be enabled/disabled
-- per subscription from the Admin UI "Control Plane Features" page (reuses the framework
-- introduced in PCP-16364 for the TESSA AI Agent).
INSERT INTO V3_FEATURE_METADATA(FEATURE_ID, VERSION, DISPLAY_NAME, DESCRIPTION)
VALUES ('SB', '{1,0,0}', 'Springboot', 'Springboot')
    ON CONFLICT DO NOTHING;

-- Fix remaining unfiltered matview-refresh triggers on v3_resource_instances
-- (all defined in 21-up.sql without OF column clause).

-- V3_VIEW_DATA_PLANE_MONITOR_DETAILS
-- Query reads from v3_resource_instances:
--   namespace subquery  : SCOPE_ID, RESOURCE_ID, SCOPE, RESOURCE_INSTANCE_NAME, RESOURCE_INSTANCE_METADATA
--   CI namespace lookup : RESOURCE_INSTANCE_ID, RESOURCE_ID, RESOURCE_INSTANCE_METADATA
--   VRI resource list   : SCOPE, SCOPE_ID, RESOURCE_ID, RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_METADATA
DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER AFTER
    INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME, RESOURCE_INSTANCE_METADATA,
                 RESOURCE_ID, SCOPE, SCOPE_ID
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- V4_VIEW_DATA_PLANE_MONITOR_DETAILS
-- Query reads from v3_resource_instances (dp_namespaces, ns_ri, dp_resources CTEs):
--   same six columns as V3 monitor details above
DROP TRIGGER IF EXISTS V4_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V4_VIEW_DATA_PLANE_MONITOR_DETAILS_RI_TRIGGER AFTER
    INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME, RESOURCE_INSTANCE_METADATA,
                 RESOURCE_ID, SCOPE, SCOPE_ID
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V4_VIEW_DATA_PLANE_MONITOR_DETAILS_REFRESH();

-- V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE
-- Query reads from v3_resource_instances:
--   ns_ri CTE (PCP-20891) : RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME,
--                           RESOURCE_INSTANCE_METADATA, RESOURCE_ID, SCOPE
--   resource_instances JSON: RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME
--                            WHERE RI.RESOURCE_INSTANCE_ID = ANY(CI.RESOURCE_INSTANCE_IDS)
DROP TRIGGER IF EXISTS V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_RI_TRIGGER AFTER
    INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_INSTANCE_NAME,
                 RESOURCE_INSTANCE_METADATA, RESOURCE_ID, SCOPE
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE_REFRESH();

-- V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES
-- Query reads from v3_resource_instances:
--   WHERE RESOURCE_ID='NAMESPACE' AND SCOPE='DATAPLANE' AND SCOPE_ID=DP_ID
--   extracts namespaceName from RESOURCE_INSTANCE_METADATA->'fields'
DROP TRIGGER IF EXISTS V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_RI_TRIGGER AFTER
    INSERT OR DELETE
    OR UPDATE OF RESOURCE_INSTANCE_ID, RESOURCE_ID, SCOPE, SCOPE_ID, RESOURCE_INSTANCE_METADATA
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_USER_ACCOUNT_SUBSCRIPTION_DATA_PLANES_REFRESH();

-- Fix unfiltered matview-refresh triggers.
--
-- Triggers defined in 4-up.sql for V3_VIEW_TAGS_DATA_PLANES and
-- V3_VIEW_TAGS_CAPABILITY_INSTANCES, and in 21-up.sql for
-- V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (RI trigger), had no UPDATE
-- column filter. Any write to the table — even touching columns irrelevant
-- to the view — caused a full REFRESH MATERIALIZED VIEW CONCURRENTLY, which
-- competes for locks with concurrent writers on all contributing tables and
-- causes the deadlocks/slowness observed under multi-threaded write load.
--
-- Each trigger is redefined here with an OF column list derived from the
-- columns the view query actually reads from that table. The OF clause
-- restricts firing on UPDATE only; INSERT and DELETE still fire unconditionally.

-- V3_VIEW_TAGS_DATA_PLANES
-- Query reads: v3_apps(DP_ID, TAGS), v3_capability_instances(DP_ID, TAGS),
--              v3_data_planes(DP_ID, TAGS, SUBSCRIPTION_ID)
DROP TRIGGER IF EXISTS V3_VIEW_TAGS_DATA_PLANES_APP_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_TAGS_DATA_PLANES_APP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, TAGS
    ON V3_APPS
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_DATA_PLANES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_TAGS_DATA_PLANES_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, TAGS
    ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_DATA_PLANES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_DATA_PLANES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_TAGS_DATA_PLANES_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF DP_ID, TAGS, SUBSCRIPTION_ID
    ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_DATA_PLANES_REFRESH();

-- V3_VIEW_TAGS_CAPABILITY_INSTANCES
-- Query reads: v3_capability_instances(CAPABILITY_INSTANCE_ID, TAGS),
--              v3_apps(CAPABILITY_INSTANCE_ID, TAGS)
DROP TRIGGER IF EXISTS V3_VIEW_TAGS_CAPABILITY_INSTANCES_APP_TRIGGER ON V3_APPS;
CREATE TRIGGER V3_VIEW_TAGS_CAPABILITY_INSTANCES_APP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF CAPABILITY_INSTANCE_ID, TAGS
    ON V3_APPS
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH();

DROP TRIGGER IF EXISTS V3_VIEW_TAGS_CAPABILITY_INSTANCES_CI_TRIGGER ON V3_CAPABILITY_INSTANCES;
CREATE TRIGGER V3_VIEW_TAGS_CAPABILITY_INSTANCES_CI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF CAPABILITY_INSTANCE_ID, TAGS
    ON V3_CAPABILITY_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_TAGS_CAPABILITY_INSTANCES_REFRESH();

-- V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (RI trigger only)
-- The triggers on v3_apps, v3_capability_instances, v3_data_planes for this
-- view already have column filters from 21-up.sql. Only the RI trigger was
-- left unfiltered.
-- Query reads from v3_resource_instances:
--   ns_ri CTE  : RESOURCE_INSTANCE_ID, SCOPE_ID, RESOURCE_INSTANCE_NAME,
--                RESOURCE_INSTANCE_METADATA, RESOURCE_ID, SCOPE
--   final join : SCOPE, SCOPE_ID, RESOURCE_ID, RESOURCE_LEVEL,
--                RESOURCE_INSTANCE_METADATA
DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER ON V3_RESOURCE_INSTANCES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF RESOURCE_INSTANCE_ID, SCOPE_ID, RESOURCE_INSTANCE_NAME,
                                  RESOURCE_INSTANCE_METADATA, RESOURCE_ID, SCOPE, RESOURCE_LEVEL
    ON V3_RESOURCE_INSTANCES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

--
-- PCP-18507 : [tp-helm-charts] Prepare feature branch and register BCCE as a new capability
--
INSERT INTO V3_CAPABILITY_METADATA(CAPABILITY_ID, DISPLAY_NAME, DESCRIPTION, CAPABILITY_TYPE)
VALUES('BCCE', 'BusinessConnect Container Edition', 'BusinessConnect Container Edition, a containerized runtime for deploying and managing TIBCO BusinessConnect', 'PLATFORM')
    ON CONFLICT DO NOTHING;

-- ============================================================================
-- PCP-20891: Complete the namespace-storage migration started by PCP-10813
-- (21-up.sql). Six NAMESPACE / NAMESPACES columns were made nullable in
-- 21-up.sql:67-75 with a comment stating column drops were deferred to 22-up.
-- Code has not written to any of them since PCP-10813 — namespaces now live in
-- V3_RESOURCE_INSTANCES (SCOPE='DATAPLANE', RESOURCE_ID='NAMESPACE'). No Bean
-- struct in tp-cp-user-subscriptions/types/dbtypes.go carries a
-- column:"namespace*" tag for the dead columns; no INSERT/UPDATE targets them.
-- The CI view earlier in this file was already updated to derive NAMESPACE
-- from RIs via the ns_ri / ci_ns CTE pattern (supersedes the duplicate
-- PCP-20982 fix that previously lived here).
-- ============================================================================

-- Remove the dead notify-on-namespaces-change trigger and function.
-- Created in 16-up.sql:282-288 to pg_notify whenever V3_DATA_PLANES.NAMESPACES
-- changed; stubbed to no-op in 21-up.sql:146; superseded for v3_resource_instances
-- by 21-up.sql:865-941. Now redundant.
DROP TRIGGER  IF EXISTS notify_dp_namespaces_change ON V3_DATA_PLANES;
DROP FUNCTION IF EXISTS notify_dp_namespaces_change() CASCADE;

-- Recreate V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES to add DP.CREATED_DATE.
-- The column was selected by every prior view definition (3-up.sql:46,
-- 6-up.sql:33, 7-up.sql:130, 9-up.sql:20) and was unintentionally dropped
-- during the 20-up/21-up rewrites. Web-server consumers display Created Time
-- (admin Subscription Details data planes table, admin DP details page,
-- CP /control-tower-data-planes). Otherwise byte-identical to 21-up.sql:439-562.
DROP MATERIALIZED VIEW IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES CASCADE;
CREATE MATERIALIZED VIEW V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES AS
WITH
ns_ri AS (
    SELECT
        RI.RESOURCE_INSTANCE_ID,
        RI.SCOPE_ID                 AS dp_id,
        RI.RESOURCE_INSTANCE_NAME   AS namespace_name,
        CASE WHEN RI.RESOURCE_INSTANCE_METADATA->'fields'
                  @> '[{"key":"isPrimary","value":true}]'::jsonb
             THEN 0 ELSE 1 END      AS primary_order
    FROM V3_RESOURCE_INSTANCES RI
    WHERE RI.RESOURCE_ID = 'NAMESPACE'
      AND RI.SCOPE       = 'DATAPLANE'
),
dp_ns AS (
    SELECT dp_id,
           ARRAY_AGG(namespace_name ORDER BY primary_order) AS namespaces
    FROM   ns_ri
    GROUP  BY dp_id
),
ci_ns AS (
    SELECT DISTINCT ON (CI.CAPABILITY_INSTANCE_ID)
        CI.CAPABILITY_INSTANCE_ID,
        NS.namespace_name
    FROM  V3_CAPABILITY_INSTANCES CI,
          unnest(CI.RESOURCE_INSTANCE_IDS) AS ri_id
    JOIN  ns_ri NS ON NS.resource_instance_id = ri_id
    ORDER BY CI.CAPABILITY_INSTANCE_ID, NS.primary_order
),
ci_flat AS (
    SELECT
        CI.DP_ID,
        CI.CAPABILITY_INSTANCE_ID,
        CI.CAPABILITY_INSTANCE_NAME,
        CI.CAPABILITY_INSTANCE_DESCRIPTION,
        CI.CAPABILITY_ID,
        CI.VERSION,
        CI.STATUS,
        CI.REGION,
        CI.TAGS,
        CI.MODIFIED_TIME,
        CI.MONITORING_STATUS,
        CR.DISPLAY_NAME,
        CR.CAPABILITY_TYPE,
        cn.namespace_name AS namespace
    FROM  V3_CAPABILITY_INSTANCES CI
    LEFT  JOIN V3_CAPABILITY_METADATA CR USING (CAPABILITY_ID, CAPABILITY_TYPE)
    LEFT  JOIN ci_ns cn            USING (CAPABILITY_INSTANCE_ID)
),
ci_agg AS (
    SELECT
        cf.DP_ID,
        json_agg(row_to_json((
            SELECT ColumnName
            FROM (
                SELECT cf.CAPABILITY_INSTANCE_ID,
                       cf.CAPABILITY_INSTANCE_NAME,
                       cf.CAPABILITY_INSTANCE_DESCRIPTION,
                       cf.CAPABILITY_ID,
                       cf.DISPLAY_NAME,
                       cf.CAPABILITY_TYPE,
                       cf.namespace,
                       cf.VERSION, cf.STATUS, cf.REGION, cf.TAGS,
                       cf.MODIFIED_TIME, cf.MONITORING_STATUS
            ) AS ColumnName (
                CAPABILITY_INSTANCE_ID, CAPABILITY_INSTANCE_NAME, CAPABILITY_INSTANCE_DESCRIPTION,
                CAPABILITY_ID, CAPABILITY_NAME, CAPABILITY_TYPE, NAMESPACE,
                VERSION, STATUS, REGION, TAGS, MODIFIED_TIME, MONITORING_STATUS
            )
        ))) AS CAPABILITIES
    FROM   ci_flat cf
    GROUP  BY cf.DP_ID
),
app_agg AS (
    SELECT DP_ID,
           json_agg(row_to_json((
               SELECT ColumnName
               FROM (SELECT A.APP_ID, A.APP_NAME, A.APP_VERSION,
                            A.CAPABILITY_INSTANCE_ID, A.CAPABILITY_ID,
                            A.CAPABILITY_VERSION, A.STATE, A.TAGS, A.MODIFIED_TIME)
                    AS ColumnName (APP_ID, APP_NAME, APP_VERSION,
                                   CAPABILITY_INSTANCE_ID, CAPABILITY_ID,
                                   CAPABILITY_VERSION, STATE, TAGS, MODIFIED_TIME)
           ))) AS APPS
    FROM   V3_APPS A
    GROUP  BY DP_ID
)
SELECT
    DP.SUBSCRIPTION_ID,
    DP.DP_ID,
    DP.NAME,
    DP.DESCRIPTION,
    DP.HOST_CLOUD_TYPE,
    DP.DP_CONFIG,
    DP.STATUS,
    DP.MONITORING_STATUS,
    DP.REGISTERED_REGION,
    DP.RUNNING_REGION,
    DP.CREATED_DATE,                                            -- PCP-20891: restored
    DP.MODIFIED_DATE,
    DP.TAGS,
    DP.CONTAINER_REGISTRY_CREDENTIAL,
    DP.CONNECTION_DETAILS,
    COALESCE(dn.namespaces, ARRAY[]::TEXT[]) AS NAMESPACES,
    ci_agg.CAPABILITIES,
    app_agg.APPS,
    RI.RESOURCE_INSTANCE_METADATA
FROM  V3_DATA_PLANES DP
LEFT  JOIN dp_ns    dn    ON dn.dp_id     = DP.DP_ID
LEFT  JOIN ci_agg         ON ci_agg.DP_ID = DP.DP_ID
LEFT  JOIN app_agg        ON app_agg.DP_ID = DP.DP_ID
LEFT  JOIN V3_RESOURCE_INSTANCES RI
          ON RI.SCOPE          = 'DATAPLANE'
         AND RI.SCOPE_ID       = DP.DP_ID
         AND RI.RESOURCE_ID    = 'SERVICEACCOUNT'
         AND RI.RESOURCE_LEVEL = 'INFRA'
WITH DATA;

CREATE UNIQUE INDEX VIEW_DATA_PLANE_CAPABILITY_INSTANCE_INDEX
    ON V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (DP_ID);

-- DP trigger: add CREATED_DATE to the UPDATE OF list to keep it aligned with
-- the view's SELECT. CREATED_DATE is set once on INSERT and never mutates,
-- so this is purely defensive. Refresh function unchanged (21-up.sql:567-575);
-- RI trigger is already correct (set above for V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_RI_TRIGGER).
DROP TRIGGER IF EXISTS V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER ON V3_DATA_PLANES;
CREATE TRIGGER V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_DP_TRIGGER AFTER
    INSERT OR DELETE OR UPDATE OF SUBSCRIPTION_ID, DP_ID, NAME, DESCRIPTION,
                                  HOST_CLOUD_TYPE, DP_CONFIG, STATUS,
                                  REGISTERED_REGION, RUNNING_REGION,
                                  CREATED_DATE, MODIFIED_DATE, TAGS,
                                  CONTAINER_REGISTRY_CREDENTIAL,
                                  CONNECTION_DETAILS, RESOURCE_INSTANCE_IDS
    ON V3_DATA_PLANES
    FOR EACH STATEMENT EXECUTE PROCEDURE V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES_REFRESH();

-- Drop the six dead NAMESPACE / NAMESPACES columns.
-- Pre-conditions verified:
--   * No index references any of them.
--   * V3_CAPABILITY_INSTANCES.NAMESPACE was removed from the PK in 21-up.sql:68-71.
--   * V3_VIEW_DATA_PLANE_CAPABILITY_INSTANCES (recreated just above) does not
--     reference DP.NAMESPACES; V3_VIEW_CAPABILITY_INSTANCE_DATA_PLANE (recreated
--     earlier in this file) derives NAMESPACE from RIs.
--   * No CHECK / FOREIGN KEY constraints reference them.
ALTER TABLE V3_DATA_PLANES                     DROP COLUMN IF EXISTS NAMESPACES;
ALTER TABLE V3_ARCHIVED_DATA_PLANES            DROP COLUMN IF EXISTS NAMESPACES;
ALTER TABLE V3_CAPABILITY_INSTANCES            DROP COLUMN IF EXISTS NAMESPACE;
ALTER TABLE V3_ARCHIVED_CAPABILITY_INSTANCES   DROP COLUMN IF EXISTS NAMESPACE;
ALTER TABLE V3_APPS                            DROP COLUMN IF EXISTS NAMESPACE;
ALTER TABLE V3_ARCHIVED_APPS                   DROP COLUMN IF EXISTS NAMESPACE;

-- Update database schema at the end (earlier version is 1.18.0 i.e. 21)
UPDATE schema_version SET version = 22;
