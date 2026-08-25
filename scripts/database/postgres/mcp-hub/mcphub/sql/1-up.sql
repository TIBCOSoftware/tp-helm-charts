-- Copyright (c) 2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Bootstrap trigger functions required by 1-up.sql
-- Sourced from tibco-cp-base/tscutd/sql/1-up.sql

CREATE OR REPLACE FUNCTION TRIGGER_SET_MODIFIED_TIME()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    NEW.MODIFIED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION TRIGGER_SET_CREATED_TIME()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $function$
BEGIN
    NEW.CREATED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    NEW.MODIFIED_TIME = (select cast(EXTRACT(EPOCH FROM NOW()) as bigint));
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION TRIGGER_SET_MODIFIER()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $function$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        NEW.CREATED_BY = (select coalesce(current_setting('cp.userId', true), 'platform-default'));
        NEW.MODIFIED_BY = (select coalesce(current_setting('cp.userId', true), 'platform-default'));
    ELSEIF (TG_OP = 'UPDATE') THEN
        NEW.MODIFIED_BY = (select coalesce(current_setting('cp.userId', true), 'platform-default'));
    END IF;
    RETURN NEW;
END;
$function$;

------------------------
-- Table Setup
------------------------

-- ============================================================
-- GATEWAYS
-- ============================================================
CREATE TABLE IF NOT EXISTS GATEWAYS (
    ID                      VARCHAR(255)  NOT NULL,
    NAME                    VARCHAR(255)  NOT NULL,
    GATEWAY_ID           VARCHAR(255)  NOT NULL,
    DESCRIPTION             TEXT          DEFAULT '',
    MCPGATEWAY_PATH       VARCHAR(255)  DEFAULT '/tibco/agent/integration/mcp-gateway/',
    TAGS                    TEXT          DEFAULT '[]',
    STATUS                  VARCHAR(64)   DEFAULT 'unknown',
    SYNC_STATUS             VARCHAR(64)   DEFAULT 'unknown',
    LAST_HEALTH_CHECK       VARCHAR(255),
    MCPGATEWAY_VERSION    VARCHAR(255),
    MCPGATEWAY_URL        TEXT          DEFAULT '',
    MCPGATEWAY_TOKEN      TEXT          DEFAULT '',
    MCPGATEWAY_DEPLOYED   BOOLEAN       DEFAULT FALSE,
    CONNECTION_MODE         VARCHAR(64)   DEFAULT 'tunnel',
    SUBSCRIPTION_ID         VARCHAR(255)  DEFAULT '',
    -- PCP-22686: the SECOND tenancy axis, alongside SUBSCRIPTION_ID above. In multi-region
    -- SaaS every region's Hub pod shares ONE database (under is_replica_region the chart
    -- points PGHOST at the MASTER region's MasterWriterHost, and {cpId}_mcphubdb carries no
    -- region component) -- and a subscription SPANS regions, so SUBSCRIPTION_ID alone let a
    -- gateway registered in EU be listed AND mutated from US. Stamped from the pod's own
    -- DEPLOYMENT_REGION (config.currentRegion()) on every write, matched exactly on every
    -- scoped read. Data planes never had the bug because they are not persisted -- they come
    -- live from region-local CP services on each request.
    --   * NOT NULL -- a NULLable region compares DISTINCT in the unique index below (true in
    --     Postgres AND SQLite), silently voiding the duplicate-registration backstop.
    --   * 'global' rather than '' -- the Hub's UTM filter layer coerces any Number()-parsable
    --     value and Number('') is 0, so an empty sentinel binds as the integer 0 and matches
    --     nothing, blanking standalone entirely. 'global' is NaN-safe and is already
    --     getDpRegion()'s fallback for an unknown region (cp-api/discovery.ts).
    -- Single-region CP, standalone and on-prem never carry a region: currentRegion()
    -- short-circuits to 'global' off the CP path, which is also this default, so the
    -- predicate matches every row and the whole axis is inert for them.
    REGION                  TEXT          NOT NULL DEFAULT 'global',
    CAPABILITY_INSTANCE_ID  VARCHAR(255)  DEFAULT '',
    CAPABILITY_INSTANCE_NAME VARCHAR(255) DEFAULT '',
    DP_NAMESPACE            VARCHAR(255)  DEFAULT '',
    BASE_HELM_VALUES        TEXT          DEFAULT '',
    GATEWAY_RELEASE_NAME    VARCHAR(255)  DEFAULT '',
    GATEWAY_INGRESS_HOST    VARCHAR(255)  DEFAULT '',
    CHART_VERSION           VARCHAR(64)   DEFAULT '',
    INGRESS_HOST            VARCHAR(255)  DEFAULT '',
    PATH_PREFIX             VARCHAR(255)  DEFAULT '',
    GATEWAY_CONFIG          TEXT          DEFAULT '',
    -- PCP-20288 (C1) — dial-home / standalone gateway origin (design §9.2). The
    -- 'dialhome' CONNECTION_MODE/ORIGIN values are free-text (no DDL); these 7
    -- columns persist the WS control-channel liveness + bootstrap-token state that
    -- A2/A6/C4 populate. WS_STATUS is distinct from the health STATUS enum above.
    -- Mirrors backend/src/sqlite-schema.ts (BOOLEAN here ≙ INTEGER 0/1 in sqlite).
    WS_STATUS               TEXT          DEFAULT 'offline',
    WS_SESSION_ID           TEXT          DEFAULT '',
    WS_LAST_SEEN            TEXT,
    WS_CONNECTED_AT         TEXT,
    BOOTSTRAP_TOKEN_HASH    TEXT          DEFAULT '',
    BOOTSTRAP_TOKEN_REVOKED BOOLEAN       DEFAULT FALSE,
    BOOTSTRAP_TOKEN_EXPIRES_AT TEXT,

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT GATEWAYS_PKEY PRIMARY KEY (ID),
    CONSTRAINT GATEWAYS_GATEWAY_ID_KEY UNIQUE (GATEWAY_ID)
);

ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS GATEWAY_ID VARCHAR(255);
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS MCPGATEWAY_URL TEXT DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS MCPGATEWAY_TOKEN TEXT DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS MCPGATEWAY_DEPLOYED BOOLEAN DEFAULT FALSE;
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS CONNECTION_MODE VARCHAR(64) DEFAULT 'tunnel';
-- How the gateway entered the Hub (PCP-19625 WS2): 'cp_dp' = discovered via a Data
-- Plane (CP mode); 'direct' = registered by URL+token (Hub mints its own id).
-- Mirrors backend/src/sqlite-schema.ts default 'cp_dp'.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS ORIGIN VARCHAR(64) NOT NULL DEFAULT 'cp_dp';
-- Genuine CP Data Plane id — populated ONLY for cp_dp rows (CP discovery), NULL for
-- direct gateways. Read via cpDpId() for any CP-DP-scoped call. Distinct from GATEWAY_ID
-- (universal identity) and from the child tables' DP_ID FK (= GATEWAYS.ID, the gateway PK).
-- Mirrors backend/src/sqlite-schema.ts. PCP-19769 Option 1.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS DP_ID VARCHAR(255);
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS SUBSCRIPTION_ID VARCHAR(255) DEFAULT '';
-- PCP-22686 region axis (see the column comment in the CREATE TABLE above). Idempotent
-- backfill for the self-heal path -- manageDbSchemaCommand re-runs this whole file when the
-- tables exist but SCHEMA_VERSION does not -- and mirrors the SUBSCRIPTION_ID line above.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS REGION TEXT NOT NULL DEFAULT 'global';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS CAPABILITY_INSTANCE_ID VARCHAR(255) DEFAULT '';
-- PCP-19802: per-instance friendly name (EMS1/EMS2 style). Mirrors backend/src/sqlite-schema.ts.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS CAPABILITY_INSTANCE_NAME VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS GATEWAY_INGRESS_HOST VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS CHART_VERSION VARCHAR(64) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS INGRESS_HOST VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS PATH_PREFIX VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS GATEWAY_CONFIG TEXT DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS CREATED_AT TEXT NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS UPDATED_AT TEXT NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
-- PCP-20288 (C1) — dial-home / standalone gateway origin (design §9.2). Idempotent
-- fold-in to the UNRELEASED PCP-17906 1-up.sql (no 2-up.sql; CURRENT_VERSION stays 1).
-- Mirrors backend/src/sqlite-schema.ts. The 'dialhome' CONNECTION_MODE/ORIGIN values
-- are free-text (no DDL); these 7 columns hold WS control-channel liveness +
-- bootstrap-token state. WS_STATUS is distinct from the health STATUS enum.
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS WS_STATUS TEXT DEFAULT 'offline';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS WS_SESSION_ID TEXT DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS WS_LAST_SEEN TEXT;
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS WS_CONNECTED_AT TEXT;
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS BOOTSTRAP_TOKEN_HASH TEXT DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS BOOTSTRAP_TOKEN_REVOKED BOOLEAN DEFAULT FALSE;
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS BOOTSTRAP_TOKEN_EXPIRES_AT TEXT;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gateways_gateway_id_key') THEN
    ALTER TABLE GATEWAYS ADD CONSTRAINT GATEWAYS_GATEWAY_ID_KEY UNIQUE (GATEWAY_ID);
  END IF;
END $$;

DROP TRIGGER IF EXISTS SET_CREATED_BY ON GATEWAYS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON GATEWAYS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON GATEWAYS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON GATEWAYS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON GATEWAYS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON GATEWAYS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON GATEWAYS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON GATEWAYS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- PCP-21378: gateway-name uniqueness at the DB layer — the concurrency backstop for the route
-- pre-checks in the Hub (double-submit / TOCTOU can otherwise create two same-named gateways in
-- the same second). Scope differs by ORIGIN, so two PARTIAL indexes:
--   - cp_dp rows (auto-installed on a DP): unique per (DP_ID, name) — a DP hosts many gateways,
--     names unique per DP.
--   - direct / dialhome rows (registered by URL / dial-home): unique per
--     (SUBSCRIPTION_ID, REGION, name) — see the REGION note below.
-- Case-insensitive + trimmed via an EXPRESSION index (LOWER()/TRIM() are IMMUTABLE → index-safe)
-- so the DB scope exactly matches the Hub pre-check's normalized compare. Mirrors
-- backend/src/sqlite-schema.ts (idx_gateways_cpdp_name / idx_gateways_direct_name).
--
-- PCP-22686: REGION is in the direct/dialhome key because SUBSCRIPTION_ID spans regions —
-- without it a tenant could not reuse a gateway name in a second region (an EU-registered
-- name 409'd a US registration), which is a second user-visible symptom of the same root
-- cause. IDX_GATEWAYS_CPDP_NAME is deliberately left alone: its key is DP_ID, a CP
-- data-plane id that is ALREADY region-local (a DP belongs to exactly one region), so adding
-- REGION would widen the key and weaken the backstop for no isolation gain.
-- The index NAME is preserved deliberately — the Hub's lib/gateway-name-dup.ts keys on it to
-- turn a violation into a friendly 409.
CREATE UNIQUE INDEX IF NOT EXISTS IDX_GATEWAYS_CPDP_NAME ON GATEWAYS (DP_ID, LOWER(TRIM(NAME))) WHERE ORIGIN = 'cp_dp';
-- DROP before CREATE: on the self-heal path (tables present, SCHEMA_VERSION missing) this file
-- re-runs against a database that may still hold the pre-PCP-22686 two-column definition, and
-- CREATE UNIQUE INDEX IF NOT EXISTS does NOT replace an index that already exists under this
-- name — it would silently keep the old key and REGION would never enter it. A no-op on a fresh
-- install, and atomic either way: createTables applies this file with --single-transaction.
DROP INDEX IF EXISTS IDX_GATEWAYS_DIRECT_NAME;
CREATE UNIQUE INDEX IF NOT EXISTS IDX_GATEWAYS_DIRECT_NAME ON GATEWAYS (SUBSCRIPTION_ID, REGION, LOWER(TRIM(NAME))) WHERE ORIGIN IN ('direct', 'dialhome');

-- PCP-22686: serves the equality predicate every scoped read now carries, which is
-- (SUBSCRIPTION_ID, REGION) TOGETHER — never REGION alone. Leading with SUBSCRIPTION_ID keeps
-- the selective column first (REGION is low-cardinality) and covers ALL origins, including
-- 'cp_dp', which the partial-unique index above does not. Deliberately NOT partial on
-- REGION <> 'global': the planner can only use a partial index when it can PROVE the predicate,
-- which it cannot for a parameterised REGION = $1 under the generic plan Postgres adopts after
-- ~5 executions of a prepared statement — the index would quietly stop being used on exactly
-- the hot path it exists for. Note GATEWAYS has no other plain SUBSCRIPTION_ID index (both
-- indexes above are partial), so this also serves subscription-scoped reads that predate region.
CREATE INDEX IF NOT EXISTS IDX_GATEWAYS_SUB_REGION ON GATEWAYS (SUBSCRIPTION_ID, REGION);

-- ============================================================
-- CP_SERVERS
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_SERVERS (
    ID          VARCHAR(255)  NOT NULL,
    DP_ID       VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID) ON DELETE CASCADE,
    NAME        VARCHAR(255)  NOT NULL,
    URL         TEXT          DEFAULT '',
    TRANSPORT   VARCHAR(64)   DEFAULT 'streamable-http',
    AUTH_TYPE   VARCHAR(64)   DEFAULT 'none',
    TOKEN       TEXT          DEFAULT '',
    HEADERS     TEXT          DEFAULT '{}',
    ENABLED     BOOLEAN       DEFAULT TRUE,
    DESCRIPTION TEXT          DEFAULT '',
    DISCOVERY_SOURCE   TEXT   DEFAULT '',
    DISCOVERY_APP_ID   TEXT   DEFAULT '',
    DISCOVERY_APP_TYPE TEXT   DEFAULT '',
    OAUTH_CONFIG       TEXT   DEFAULT '{}',
    -- PCP-21374: HMAC fingerprint of the full desired body last pushed (incl. non-observable
    -- fields) for Hub-side skip-if-unchanged. No index (read by (DP_ID,NAME)); NO backfill.
    LAST_PUSHED_FINGERPRINT VARCHAR(64),

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT CP_SERVERS_PKEY PRIMARY KEY (ID)
);

CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_SERVERS_DP_NAME ON CP_SERVERS (DP_ID, NAME);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON CP_SERVERS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON CP_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON CP_SERVERS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON CP_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON CP_SERVERS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON CP_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON CP_SERVERS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON CP_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- Discovery columns (PCP-18432)
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS DISCOVERY_SOURCE   TEXT DEFAULT '';
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS DISCOVERY_APP_ID   TEXT DEFAULT '';
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS DISCOVERY_APP_TYPE TEXT DEFAULT '';

-- Upstream OAuth proxy config (PCP-18426) — JSON; client secrets encrypted at rest by the app
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS OAUTH_CONFIG TEXT DEFAULT '{}';
-- PCP-21374: last-pushed fingerprint (HMAC of the full desired body; Hub-side skip-if-unchanged).
-- Folded into the unreleased 1-up.sql — CURRENT_VERSION stays 1. Pre-release → NO backfill
-- (NULL = never pushed → treated as changed). No index (read by (DP_ID,NAME)). SQLite mirror:
-- backend/src/sqlite-schema.ts.
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS LAST_PUSHED_FINGERPRINT VARCHAR(64);
-- PCP-22853 follow-up: authoritative per-SERVER push health — the peer twin of
-- CP_VIRTUAL_SERVERS.PUSH_ERROR (PCP-22096), and it exists for the same reason. A server can be
-- ENABLED, registered on the gateway, `status: 'connected'`, and have federated NOTHING; every
-- later push then re-reports 'synced' because the peer object still exists. `ENABLED` is the
-- DESIRED state, not a health signal — this column carries the verdict. Measured on a real CP
-- (ins-syan-22853, 2026-08-02). Pre-release fold-in → NO backfill (existing rows stay NULL =
-- healthy). No index (read by (DP_ID,NAME)). SQLite mirror: backend/src/sqlite-schema.ts
-- cp_servers.push_error.
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS PUSH_ERROR TEXT;

-- ============================================================
-- CP_TOOLS
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_TOOLS (
    ID               VARCHAR(255)  NOT NULL,
    DP_ID            VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID) ON DELETE CASCADE,
    NAME             VARCHAR(255)  NOT NULL,
    DISPLAY_NAME     VARCHAR(255)  DEFAULT '',
    DESCRIPTION      TEXT          DEFAULT '',
    INTEGRATION_TYPE VARCHAR(255)  DEFAULT 'MCP',
    REQUEST_TYPE     VARCHAR(64)   DEFAULT 'streamable-http',
    URL              TEXT          DEFAULT '',
    INPUT_SCHEMA     TEXT          DEFAULT '{}',
    OUTPUT_SCHEMA    TEXT          DEFAULT '{}',
    GATEWAY_NAME     VARCHAR(255)  DEFAULT '',
    IS_ACTIVE        BOOLEAN       DEFAULT TRUE,
    TAGS             TEXT          DEFAULT '[]',
    AUTH_TYPE        VARCHAR(64)   DEFAULT 'none',
    AUTH_VALUE       TEXT          DEFAULT '',
    HEADERS          TEXT          DEFAULT '{}',
    JSONPATH_FILTER  VARCHAR(512)  DEFAULT '',
    ANNOTATIONS      TEXT          DEFAULT '{}',
    TIMEOUT_MS       INTEGER       DEFAULT 60000,
    SOURCE           VARCHAR(255)  DEFAULT '',
    SOURCE_URL       TEXT          DEFAULT '',
    -- SOAP/WSDL routing fields (PCP-18693). Populated when INTEGRATION_TYPE='SOAP'
    -- to identify the parent WsdlService on the gateway side and the SOAP
    -- routing values; null for REST/MCP rows.
    WSDL_SERVICE_ID  VARCHAR(36),
    SOAP_ACTION      TEXT,
    OPERATION_QNAME  TEXT,
    -- PCP-21059 FU-1 Expand: immutable entity-id mirror of ID (gateway-assigned id).
    GATEWAY_ENTITY_ID VARCHAR(255),
    -- PCP-21374: HMAC fingerprint of the full desired body last pushed (Hub-side skip-if-unchanged).
    LAST_PUSHED_FINGERPRINT VARCHAR(64),
    -- PCP-21864: canonical MCP-protocol name captured verbatim at pull/refresh
    -- ({gateway.slug}{sep}{slugify(tool_name)}, incl. the collision-disambiguation -N suffix
    -- that cannot be recomputed Hub-side); null until first written. SQLite mirror: backend/src/sqlite-schema.ts.
    PROTOCOL_NAME TEXT,

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT CP_TOOLS_PKEY PRIMARY KEY (ID)
);

ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS AUTH_TYPE VARCHAR(64) DEFAULT 'none';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS AUTH_VALUE TEXT DEFAULT '';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS HEADERS TEXT DEFAULT '{}';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS JSONPATH_FILTER VARCHAR(512) DEFAULT '';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS ANNOTATIONS TEXT DEFAULT '{}';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS TIMEOUT_MS INTEGER DEFAULT 60000;
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS SOURCE VARCHAR(255) DEFAULT '';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS SOURCE_URL TEXT DEFAULT '';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS CREATED_AT TEXT NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS UPDATED_AT TEXT NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
-- SOAP/WSDL routing fields (PCP-18693).
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS WSDL_SERVICE_ID VARCHAR(36);
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS SOAP_ACTION TEXT;
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS OPERATION_QNAME TEXT;
-- PCP-21059: gateway_entity_id (immutable entity ids; folded into the unreleased 1-up.sql —
-- CURRENT_VERSION stays 1). Pre-release → NO backfill: no existing rows; realign writes it on push,
-- `id` stays the immutable Hub UUID. The partial unique index excludes NULLs; each non-NULL value is
-- the gateway id (unique per dp). SQLite mirror: backend/src/sqlite-schema.ts.
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS GATEWAY_ENTITY_ID VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_TOOLS_DP_GW_ENTITY ON CP_TOOLS (DP_ID, GATEWAY_ENTITY_ID) WHERE GATEWAY_ENTITY_ID IS NOT NULL;
-- PCP-21374: last-pushed fingerprint (see CP_SERVERS note; no index, no backfill).
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS LAST_PUSHED_FINGERPRINT VARCHAR(64);
-- PCP-21864: protocol_name (verbatim MCP-protocol tool slug; folded into the unreleased 1-up.sql —
-- CURRENT_VERSION stays 1). Pre-release → NO backfill; the Hub pull/refresh mapper writes it.
-- No index. SQLite mirror: backend/src/sqlite-schema.ts (schema-parity gate, PCP-20147 AC#10).
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS PROTOCOL_NAME TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_TOOLS_DP_NAME ON CP_TOOLS (DP_ID, NAME);
CREATE INDEX IF NOT EXISTS IDX_CP_TOOLS_WSDL_SERVICE_ID ON CP_TOOLS (WSDL_SERVICE_ID);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON CP_TOOLS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON CP_TOOLS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON CP_TOOLS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON CP_TOOLS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON CP_TOOLS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON CP_TOOLS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON CP_TOOLS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON CP_TOOLS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- CP_VIRTUAL_SERVERS
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_VIRTUAL_SERVERS (
    ID           VARCHAR(255)  NOT NULL,
    DP_ID        VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID) ON DELETE CASCADE,
    NAME         VARCHAR(255)  NOT NULL,
    DESCRIPTION  TEXT          DEFAULT '',
    TOOL_IDS     TEXT          DEFAULT '[]',
    RESOURCE_IDS TEXT          DEFAULT '[]',
    PROMPT_IDS   TEXT          DEFAULT '[]',
    IS_ACTIVE    BOOLEAN       DEFAULT TRUE,
    TAGS         TEXT          DEFAULT '[]',
    REQUIRE_AUTH BOOLEAN       DEFAULT FALSE,
    PERMISSIONS  TEXT          DEFAULT '[]',
    OAUTH_CONFIG TEXT          DEFAULT '{}',
    -- PCP-21059 FU-1 Expand: immutable entity-id mirror of ID (gateway-assigned id).
    GATEWAY_ENTITY_ID VARCHAR(255),
    -- PCP-21374: HMAC fingerprint of the full desired body last pushed (Hub-side skip-if-unchanged).
    LAST_PUSHED_FINGERPRINT VARCHAR(64),
    -- PCP-22096: authoritative per-VS push health. NULL = healthy; non-NULL = the last push
    -- failed (guard-skipped for a broken child / push / realign failure) and the VS is unusable
    -- despite a possibly-stale GATEWAY_ENTITY_ID. The Hub drives NEEDS ATTENTION from this so a
    -- pushed-then-broken VS (non-empty endpoint) is no longer shown as a false ACTIVE.
    PUSH_ERROR TEXT,

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT CP_VIRTUAL_SERVERS_PKEY PRIMARY KEY (ID)
);

ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS REQUIRE_AUTH BOOLEAN DEFAULT FALSE;
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS PERMISSIONS TEXT DEFAULT '[]';
-- Inbound (resource-server) OAuth metadata (PCP-18426) — JSON; no secrets
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS OAUTH_CONFIG TEXT DEFAULT '{}';
-- PCP-21059: gateway_entity_id (see CP_TOOLS note above; pre-release → NO backfill).
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS GATEWAY_ENTITY_ID VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_VIRTUAL_SERVERS_DP_GW_ENTITY ON CP_VIRTUAL_SERVERS (DP_ID, GATEWAY_ENTITY_ID) WHERE GATEWAY_ENTITY_ID IS NOT NULL;
-- PCP-21374: last-pushed fingerprint (see CP_SERVERS note; no index, no backfill).
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS LAST_PUSHED_FINGERPRINT VARCHAR(64);
-- PCP-22096: authoritative per-VS push health (pre-release fold-in → no backfill; existing rows
-- stay NULL = healthy). Mirrors backend/src/sqlite-schema.ts cp_virtual_servers.push_error.
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS PUSH_ERROR TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_VIRTUAL_SERVERS_DP_NAME ON CP_VIRTUAL_SERVERS (DP_ID, NAME);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON CP_VIRTUAL_SERVERS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON CP_VIRTUAL_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON CP_VIRTUAL_SERVERS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON CP_VIRTUAL_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON CP_VIRTUAL_SERVERS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON CP_VIRTUAL_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON CP_VIRTUAL_SERVERS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON CP_VIRTUAL_SERVERS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- CP_PROMPTS
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_PROMPTS (
    ID           VARCHAR(255)  NOT NULL,
    DP_ID        VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID) ON DELETE CASCADE,
    NAME         VARCHAR(255)  NOT NULL,
    DESCRIPTION  TEXT          DEFAULT '',
    TEMPLATE     TEXT          DEFAULT '',
    INPUT_SCHEMA TEXT          DEFAULT '{}',
    GATEWAY_NAME VARCHAR(255)  DEFAULT '',
    IS_ACTIVE    BOOLEAN       DEFAULT TRUE,
    TAGS         TEXT          DEFAULT '[]',

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    -- PCP-21059 FU-1 Expand: immutable entity-id mirror of ID (gateway-assigned id).
    GATEWAY_ENTITY_ID VARCHAR(255),
    -- PCP-21374: HMAC fingerprint of the full desired body last pushed (Hub-side skip-if-unchanged).
    LAST_PUSHED_FINGERPRINT VARCHAR(64),

    CONSTRAINT CP_PROMPTS_PKEY PRIMARY KEY (ID)
);

-- PCP-21059: gateway_entity_id (see CP_TOOLS note above; pre-release → NO backfill).
ALTER TABLE CP_PROMPTS ADD COLUMN IF NOT EXISTS GATEWAY_ENTITY_ID VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_PROMPTS_DP_GW_ENTITY ON CP_PROMPTS (DP_ID, GATEWAY_ENTITY_ID) WHERE GATEWAY_ENTITY_ID IS NOT NULL;
-- PCP-21374: last-pushed fingerprint (see CP_SERVERS note; no index, no backfill).
ALTER TABLE CP_PROMPTS ADD COLUMN IF NOT EXISTS LAST_PUSHED_FINGERPRINT VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_PROMPTS_DP_NAME ON CP_PROMPTS (DP_ID, NAME);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON CP_PROMPTS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON CP_PROMPTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON CP_PROMPTS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON CP_PROMPTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON CP_PROMPTS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON CP_PROMPTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON CP_PROMPTS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON CP_PROMPTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- CP_RESOURCES
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_RESOURCES (
    ID           VARCHAR(255)  NOT NULL,
    DP_ID        VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID) ON DELETE CASCADE,
    URI          VARCHAR(255)  NOT NULL,
    -- Resource templates (PCP-20037 §3.1). URI_TEMPLATE is the static-vs-template
    -- distinction (TEXT, not VARCHAR(255), so template URIs aren't length-capped);
    -- SIZE is the gateway-computed byte count (nullable, read-only).
    URI_TEMPLATE TEXT          DEFAULT '',
    NAME         VARCHAR(255)  NOT NULL,
    DESCRIPTION  TEXT          DEFAULT '',
    MIME_TYPE    VARCHAR(128)  DEFAULT 'text/plain',
    CONTENT      TEXT          DEFAULT '',
    SIZE         BIGINT,
    GATEWAY_NAME VARCHAR(255)  DEFAULT '',
    IS_ACTIVE    BOOLEAN       DEFAULT TRUE,
    TAGS         TEXT          DEFAULT '[]',

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    -- PCP-21059 FU-1 Expand: immutable entity-id mirror of ID (gateway-assigned id).
    GATEWAY_ENTITY_ID VARCHAR(255),
    -- PCP-21374: HMAC fingerprint of the full desired body last pushed (Hub-side skip-if-unchanged).
    LAST_PUSHED_FINGERPRINT VARCHAR(64),

    CONSTRAINT CP_RESOURCES_PKEY PRIMARY KEY (ID)
);

-- Idempotent fold-in for existing CP_RESOURCES tables (PCP-20037 §3.1). Folded into
-- the unreleased PCP-17906 1-up.sql (no 2-up.sql; CURRENT_VERSION stays 1).
ALTER TABLE CP_RESOURCES ADD COLUMN IF NOT EXISTS URI_TEMPLATE TEXT DEFAULT '';
ALTER TABLE CP_RESOURCES ADD COLUMN IF NOT EXISTS SIZE BIGINT;
-- PCP-21059: gateway_entity_id (see CP_TOOLS note above; pre-release → NO backfill).
ALTER TABLE CP_RESOURCES ADD COLUMN IF NOT EXISTS GATEWAY_ENTITY_ID VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_RESOURCES_DP_GW_ENTITY ON CP_RESOURCES (DP_ID, GATEWAY_ENTITY_ID) WHERE GATEWAY_ENTITY_ID IS NOT NULL;
-- PCP-21374: last-pushed fingerprint (see CP_SERVERS note; no index, no backfill).
ALTER TABLE CP_RESOURCES ADD COLUMN IF NOT EXISTS LAST_PUSHED_FINGERPRINT VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_RESOURCES_DP_NAME ON CP_RESOURCES (DP_ID, NAME);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON CP_RESOURCES;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON CP_RESOURCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON CP_RESOURCES;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON CP_RESOURCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON CP_RESOURCES;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON CP_RESOURCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON CP_RESOURCES;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON CP_RESOURCES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- GOVERNANCE_PROFILES
-- ============================================================
CREATE TABLE IF NOT EXISTS GOVERNANCE_PROFILES (
    ID          VARCHAR(255)  NOT NULL,
    NAME        VARCHAR(255)  NOT NULL,
    DESCRIPTION TEXT          DEFAULT '',
    CONFIG      TEXT          DEFAULT '{}',
    BUILT_IN    BOOLEAN       DEFAULT FALSE,
    -- PCP-22861 D1-impl(a): the tenant axis this table never had. Until now ownership was
    -- stamped into a reserved key INSIDE `CONFIG` (routes/governance.ts stampOwner/stripOwner),
    -- which that file's own header called a placeholder: "If a column is ever added, migrate
    -- this key into it and delete the strip/stamp pair below." This is that column.
    -- Built-in rows keep 'default' and stay readable by every tenant (see the UNIQUE note).
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL DEFAULT 'default',

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT GOVERNANCE_PROFILES_PKEY PRIMARY KEY (ID),
    -- PCP-22861 D1-impl(a): REPLACES `GOVERNANCE_PROFILES_NAME_KEY UNIQUE (NAME)`. Identical
    -- defect class to PCP-22826/f008 on MCP_TOKENS below: a GLOBAL name-unique makes the Hub's
    -- own uniqueness pre-check tenant-blind BY CONSTRUCTION, so `POST /governance/profiles`
    -- answers 409 for a name another tenant already took — a cross-tenant existence oracle,
    -- plus a name-squat one tenant can never recover from. It is also what created the
    -- "OPEN TRADE-OFF ... awaiting a decision" recorded at routes/governance.ts: a fail-closed
    -- unowned row was uneditable, undeletable AND unrecreatable precisely because NAME was
    -- global. Scoping the constraint dissolves that dilemma rather than picking a side of it.
    -- Keyed on SUBSCRIPTION_ID only, no REGION: same reasoning as MCP_TOKENS_SUB_NAME_UQ, and
    -- this table has no REGION column at all — a governance profile is CP-level configuration
    -- that exists once per tenant, not once per (tenant, region).
    CONSTRAINT GOVERNANCE_PROFILES_SUB_NAME_UQ UNIQUE (SUBSCRIPTION_ID, NAME)
);

-- PCP-22861 D1-impl(a) — folded into the still-unreleased 1-up.sql by the same convention as
-- PCP-22826/f008 on MCP_TOKENS (deliberate: no 2-up.sql, no CURRENT_VERSION bump). These ALTERs
-- make the fold reach an env that already provisioned GOVERNANCE_PROFILES with the old shape.
--
-- ⚠️ ORDER IS LOAD-BEARING: the ADD COLUMN must precede anything that NAMES that column. On an
-- already-provisioned table `CREATE TABLE IF NOT EXISTS` is a no-op, so a
-- `CREATE INDEX ... (SUBSCRIPTION_ID)` placed above would abort the whole script with
-- "column subscription_id does not exist" and never reach the ALTER that adds it —
-- IF NOT EXISTS guards the INDEX NAME, not the column. (Caught by cross-review, GPT-5.6 Sol.)
--
-- NOTE for pre-GA dev environments: backend/src/pg-migrate.ts keeps a sha256 of every applied
-- migration and REFUSES TO START when an applied file changes, so a database that already ran
-- 1-up.sql must be RESET, not upgraded — exactly what that guard's message tells you to do for
-- an intentional in-place fold. These ALTERs therefore cover an env provisioned from an OLDER
-- 1-up.sql, not an in-place upgrade of this one.
--
-- The DEFAULT is 'default' because that is the value the seeded built-ins carry, i.e. the global
-- product plane. It is NOT a back-compat story for pre-existing CUSTOM rows: those would land in
-- 'default' with no CP tenant owning them and become immutable. That is acceptable ONLY because
-- the reset above means no such row survives — do not read this default as "legacy rows keep
-- working". Nothing backfills the old routes/governance.ts `_mcpHubOwnerSubscriptionId` blob key,
-- deliberately: after a reset there is nothing to backfill.
ALTER TABLE GOVERNANCE_PROFILES ADD COLUMN IF NOT EXISTS SUBSCRIPTION_ID VARCHAR(255) NOT NULL DEFAULT 'default';
ALTER TABLE GOVERNANCE_PROFILES DROP CONSTRAINT IF EXISTS GOVERNANCE_PROFILES_NAME_KEY;
DO $$ BEGIN
    ALTER TABLE GOVERNANCE_PROFILES ADD CONSTRAINT GOVERNANCE_PROFILES_SUB_NAME_UQ UNIQUE (SUBSCRIPTION_ID, NAME);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;  -- already present on a fresh create
END $$;

-- AFTER the ALTER, for the reason above: the tenant-scoped read path filters on SUBSCRIPTION_ID.
CREATE INDEX IF NOT EXISTS IDX_GOVERNANCE_PROFILES_SUBSCRIPTION_ID ON GOVERNANCE_PROFILES (SUBSCRIPTION_ID);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON GOVERNANCE_PROFILES;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON GOVERNANCE_PROFILES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON GOVERNANCE_PROFILES;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON GOVERNANCE_PROFILES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON GOVERNANCE_PROFILES;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON GOVERNANCE_PROFILES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON GOVERNANCE_PROFILES;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON GOVERNANCE_PROFILES FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- Seed built-in governance profiles
INSERT INTO GOVERNANCE_PROFILES (ID, NAME, DESCRIPTION, CONFIG, BUILT_IN)
VALUES
    ('profile-strict',      'Strict',      'Maximum security — PII filter, rate limiting, SQL sanitization all enabled', '{"piiFilter":true,"rateLimiting":true,"sqlSanitization":true}',   TRUE),
    ('profile-standard',    'Standard',    'Balanced — PII filter and rate limiting enabled',                             '{"piiFilter":true,"rateLimiting":true,"sqlSanitization":false}',  TRUE),
    ('profile-development', 'Development', 'Minimal restrictions for dev/test environments',                              '{"piiFilter":false,"rateLimiting":false,"sqlSanitization":false}', TRUE)
ON CONFLICT (ID) DO NOTHING;

-- ============================================================
-- GATEWAYS — additional columns added in 1.17.0
-- ============================================================
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS GATEWAY_INGRESS_HOST  VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS CHART_VERSION         VARCHAR(64)  DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS INGRESS_HOST          VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS PATH_PREFIX           VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS DP_NAMESPACE          VARCHAR(255) DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS BASE_HELM_VALUES      TEXT         DEFAULT '';
ALTER TABLE GATEWAYS ADD COLUMN IF NOT EXISTS GATEWAY_RELEASE_NAME  VARCHAR(255) DEFAULT '';

-- ============================================================
-- CP_TOOLS — source tracking columns added in 1.17.0
-- ============================================================
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS SOURCE     VARCHAR(255) DEFAULT '';
ALTER TABLE CP_TOOLS ADD COLUMN IF NOT EXISTS SOURCE_URL TEXT         DEFAULT '';

-- ============================================================
-- CP_VIRTUAL_SERVERS — auth columns added in 1.17.0
-- ============================================================
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS REQUIRE_AUTH BOOLEAN DEFAULT FALSE;
ALTER TABLE CP_VIRTUAL_SERVERS ADD COLUMN IF NOT EXISTS PERMISSIONS  TEXT    DEFAULT '[]';

-- ============================================================
-- MCP_TOKENS (new in 1.17.0)
-- ============================================================
CREATE TABLE IF NOT EXISTS MCP_TOKENS (
    ID              VARCHAR(255) NOT NULL,
    NAME            VARCHAR(255) NOT NULL,
    OWNER_EMAIL     VARCHAR(255) NOT NULL,
    DP_ID           VARCHAR(255) REFERENCES GATEWAYS(ID) ON DELETE SET NULL,
    -- PCP-22826 (f008): the tenancy columns MCP_TOKENS never had. Every sibling child table
    -- carries tenancy one of two ways: transitively via a NOT NULL DP_ID (CP_SERVERS, CP_TOOLS,
    -- CP_PROMPTS, CP_RESOURCES, CP_VIRTUAL_SERVERS — all `(DP_ID, NAME)`), or directly via a
    -- SUBSCRIPTION_ID column (CP_CATALOG_ENTRIES, CP_CATALOG_SEED_TOMBSTONES). MCP_TOKENS cannot
    -- use the first: its DP_ID is NULLable ON DELETE SET NULL, because a DP-less token is a
    -- legitimate shape — and NULLs are DISTINCT in a unique index, so `(DP_ID, NAME)` would leave
    -- DP-less tokens with no uniqueness at all and would silently unconstrain any row whose
    -- gateway is deleted. So it takes the second, direct form.
    -- 'default' (not '') is the single-tenant sentinel used by the catalog family above and named
    -- as such in the code (lib/rbac/subscription.ts: "standalone … serves a single 'default'
    -- tenant"). In standalone every row lands in that one bucket, so the composite below collapses
    -- to plain NAME uniqueness — i.e. today's behaviour, unchanged.
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL DEFAULT 'default',
    -- REGION is carried for parity with GATEWAYS (PCP-22686 made region a co-equal tenancy axis and
    -- warns that a subscription SPANS regions), but it is deliberately NOT in the uniqueness key —
    -- see the constraint note below.
    REGION          VARCHAR(255) NOT NULL DEFAULT 'global',
    CF_SERVER_ID    VARCHAR(255),
    CF_TOKEN_ID     VARCHAR(255),
    PERMISSIONS     TEXT,
    IP_RESTRICTIONS TEXT,
    CREATED_AT      INTEGER      NOT NULL,   -- epoch seconds; application-managed
    EXPIRES_AT      INTEGER,                  -- epoch seconds; application-managed
    REVOKED         BOOLEAN      DEFAULT FALSE,
    REVOKED_AT      INTEGER,                  -- epoch seconds; Hub-stamped at every revoke site
    LAST_USED_AT    INTEGER,                  -- epoch seconds; mirrored from gateway last_used at reconcile

    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT MCP_TOKENS_PKEY PRIMARY KEY (ID),
    -- PCP-22826 (f008): REPLACES `MCP_TOKENS_NAME_UQ UNIQUE (NAME)`. A global name-unique made the
    -- Hub's own uniqueness pre-check and its revoked-row purge tenant-blind BY CONSTRUCTION: a
    -- tenant could probe another tenant's token names (409 oracle) and, worse, DELETE another
    -- tenant's revoked audit row simply by minting a name-colliding token. Scoping the constraint
    -- is what makes scoping the queries coherent — predicate and constraint have to move together.
    -- Keyed on SUBSCRIPTION_ID (not REGION too): the security boundary is the tenant, and a region
    -- sits INSIDE a subscription, so subscription alone closes the cross-tenant hole. Putting
    -- REGION in the key would additionally allow the same tenant to reuse one name per region —
    -- a user-visible naming change, not a security one. Matches CP_CATALOG_SEED_TOMBSTONES.
    CONSTRAINT MCP_TOKENS_SUB_NAME_UQ UNIQUE (SUBSCRIPTION_ID, NAME)
);

CREATE INDEX IF NOT EXISTS IDX_MCP_TOKENS_DP_ID ON MCP_TOKENS (DP_ID);
-- IDX_MCP_TOKENS_SUBSCRIPTION_ID moved BELOW the ALTERs — see the ordering note there.

-- Lifecycle/usage columns (PCP-21768) — folded into the unreleased 1-up.sql.
-- REVOKED_AT: Hub-stamped epoch seconds at every revoke site (records WHEN, not just THAT).
-- LAST_USED_AT: mirrored from the gateway's last_used at reconcile (cache as of last reconcile).
-- Idempotent ALTERs for any env that already provisioned MCP_TOKENS before these columns.
ALTER TABLE MCP_TOKENS ADD COLUMN IF NOT EXISTS REVOKED_AT INTEGER;
ALTER TABLE MCP_TOKENS ADD COLUMN IF NOT EXISTS LAST_USED_AT INTEGER;

-- PCP-22826 (f008) — tenancy columns + the constraint swap, folded into the still-unreleased
-- 1-up.sql per the same convention as PCP-21768 above (deliberate: no 2-up.sql, no CURRENT_VERSION
-- bump). These ALTERs make the fold reach an env that already provisioned MCP_TOKENS with the old
-- shape. NOTE for pre-GA dev environments: backend/src/pg-migrate.ts keeps a sha256 of every
-- applied migration and REFUSES TO START when an applied file changes, so a database that already
-- ran 1-up.sql must be RESET rather than upgraded — exactly what that guard's own message tells
-- you to do for an intentional in-place fold. Existing rows land in the 'default' single-tenant
-- bucket, which is the back-compatible value.
--
-- ⚠️ ORDERING FIX (PCP-22861, cross-review GPT-5.6 Sol). IDX_MCP_TOKENS_SUBSCRIPTION_ID used to
-- sit above, next to IDX_MCP_TOKENS_DP_ID — i.e. BEFORE the ADD COLUMN that creates the column it
-- indexes. On an already-provisioned MCP_TOKENS that aborts the whole script with "column
-- subscription_id does not exist" and never reaches these ALTERs; IF NOT EXISTS guards the INDEX
-- NAME, not the column. Only the mandatory reset above kept it from being hit. Found while
-- copying this block for GOVERNANCE_PROFILES — the copy inherited the defect, so both are fixed
-- here rather than leaving a known-broken block in place.
ALTER TABLE MCP_TOKENS ADD COLUMN IF NOT EXISTS SUBSCRIPTION_ID VARCHAR(255) NOT NULL DEFAULT 'default';
ALTER TABLE MCP_TOKENS ADD COLUMN IF NOT EXISTS REGION          VARCHAR(255) NOT NULL DEFAULT 'global';
ALTER TABLE MCP_TOKENS DROP CONSTRAINT IF EXISTS MCP_TOKENS_NAME_UQ;
DO $$ BEGIN
    ALTER TABLE MCP_TOKENS ADD CONSTRAINT MCP_TOKENS_SUB_NAME_UQ UNIQUE (SUBSCRIPTION_ID, NAME);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;  -- already present on a fresh create
END $$;

-- AFTER the ALTER, per the ordering note above: the tenant-scoped read/purge paths filter on it.
CREATE INDEX IF NOT EXISTS IDX_MCP_TOKENS_SUBSCRIPTION_ID ON MCP_TOKENS (SUBSCRIPTION_ID);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON MCP_TOKENS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON MCP_TOKENS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON MCP_TOKENS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON MCP_TOKENS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON MCP_TOKENS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON MCP_TOKENS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON MCP_TOKENS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON MCP_TOKENS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- CP_CATALOG_ENTRIES (new in 1.17.0) — bundled seeds + customer-authored
-- catalog entries. SERVER_DETAIL stored as JSON blob; lifecycle metadata
-- (status, *_AT, IS_LATEST) projected into columns for filtering / indexing.
-- Spec: SPEC-catalog-crud.md §7.1.
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_CATALOG_ENTRIES (
    SUBSCRIPTION_ID    VARCHAR(255) NOT NULL DEFAULT 'default',
    NAME               VARCHAR(255) NOT NULL,
    VERSION            VARCHAR(64)  NOT NULL DEFAULT '1.0.0',
    SERVER_DETAIL_JSON TEXT         NOT NULL,
    STATUS             VARCHAR(64)  NOT NULL DEFAULT 'active',
    STATUS_MESSAGE     TEXT,
    STATUS_CHANGED_AT  TEXT         NOT NULL,
    IS_LATEST          BOOLEAN      NOT NULL DEFAULT TRUE,
    PUBLISHED_AT       TEXT         NOT NULL,
    UPDATED_AT         TEXT         NOT NULL,

    CONSTRAINT CP_CATALOG_ENTRIES_PKEY PRIMARY KEY (SUBSCRIPTION_ID, NAME, VERSION)
);

CREATE INDEX IF NOT EXISTS IDX_CATALOG_STATUS  ON CP_CATALOG_ENTRIES (SUBSCRIPTION_ID, STATUS);
CREATE INDEX IF NOT EXISTS IDX_CATALOG_UPDATED ON CP_CATALOG_ENTRIES (UPDATED_AT);

-- ============================================================
-- CP_CATALOG_SEED_TOMBSTONES (new in 1.17.0) — prevents resurrection of
-- user-deleted bundled seeds on next boot. Spec: SPEC-catalog-crud.md §7.2.
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_CATALOG_SEED_TOMBSTONES (
    SUBSCRIPTION_ID VARCHAR(255) NOT NULL DEFAULT 'default',
    NAME            VARCHAR(255) NOT NULL,
    DELETED_AT      TEXT         NOT NULL,

    CONSTRAINT CP_CATALOG_SEED_TOMBSTONES_PKEY PRIMARY KEY (SUBSCRIPTION_ID, NAME)
);

-- ============================================================
-- CP_PLUGIN_ASSIGNMENTS (new in 1.17.0) — per-VS plugin pipeline
-- entries authored in Command Center. On Push, these are projected onto
-- Gateway via POST /v1/tools/plugin_bindings under the fixed MCP Hub system
-- team (gateway bootstraps it; Hub never negotiates a per-DP team id).
-- (see backend/src/routes/sync.ts pushPluginAssignments). SCOPE='vs' fans out
-- one policy per VS tool; SCOPE='tool' uses TOOL_NAME verbatim.
-- ============================================================
CREATE TABLE IF NOT EXISTS CP_PLUGIN_ASSIGNMENTS (
    ID            VARCHAR(255)  NOT NULL,
    DP_ID         VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID)          ON DELETE CASCADE,
    VS_ID         VARCHAR(255)  NOT NULL REFERENCES CP_VIRTUAL_SERVERS(ID)  ON DELETE CASCADE ON UPDATE CASCADE,
    PLUGIN_ID     VARCHAR(255)  NOT NULL,
    HOOK          VARCHAR(64)   NOT NULL,
    SCOPE         VARCHAR(16)   NOT NULL DEFAULT 'vs' CHECK (SCOPE IN ('vs', 'tool')),
    TOOL_NAME     VARCHAR(255)  NOT NULL DEFAULT '',
    MODE          VARCHAR(32)   NOT NULL DEFAULT 'enforce',
    PRIORITY      INTEGER       NOT NULL DEFAULT 50,
    CONFIG        TEXT          NOT NULL DEFAULT '{}',
    ON_ERROR      VARCHAR(16),

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT CP_PLUGIN_ASSIGNMENTS_PKEY PRIMARY KEY (ID)
);

CREATE INDEX        IF NOT EXISTS IDX_CP_PLUGIN_ASSIGNMENTS_DP_VS  ON CP_PLUGIN_ASSIGNMENTS (DP_ID, VS_ID);
CREATE UNIQUE INDEX IF NOT EXISTS IDX_CP_PLUGIN_ASSIGNMENTS_UNIQUE ON CP_PLUGIN_ASSIGNMENTS (VS_ID, PLUGIN_ID, HOOK, SCOPE, TOOL_NAME);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON CP_PLUGIN_ASSIGNMENTS;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON CP_PLUGIN_ASSIGNMENTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON CP_PLUGIN_ASSIGNMENTS;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON CP_PLUGIN_ASSIGNMENTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON CP_PLUGIN_ASSIGNMENTS;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON CP_PLUGIN_ASSIGNMENTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON CP_PLUGIN_ASSIGNMENTS;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON CP_PLUGIN_ASSIGNMENTS FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- SYNC_HISTORY
-- Audit log of sync OPERATIONS between Hub and Gateway (database.md §3.8,
-- gateway-topology-model.md §5). One row per push/pull with the per-operation
-- OUTCOME 'success' | 'failed' | 'partial' — deliberately distinct from the
-- per-Gateway STATE ('unknown'|'pending'|'synced'|'error') on
-- GATEWAYS.SYNC_STATUS: a 'partial' operation leaves the STATE at 'error'.
-- Mirrors backend/src/sqlite-schema.ts (PCP-19627).
--
-- FK note: §3.8 specs a composite FK (SUBSCRIPTION_ID, GATEWAY_ID), but the
-- DP row is GATEWAYS keyed by the single-column PK ID (the pair is not a unique
-- key), so we FK GATEWAY_ID -> GATEWAYS(ID) ON DELETE CASCADE — the same
-- shape every sibling table uses; preserves cascade-on-DP-delete. SUBSCRIPTION_ID
-- is retained as a descriptive column.
-- ============================================================
CREATE TABLE IF NOT EXISTS SYNC_HISTORY (
    ID              VARCHAR(255)  NOT NULL,
    SUBSCRIPTION_ID VARCHAR(255)  NOT NULL DEFAULT 'default',
    GATEWAY_ID   VARCHAR(255)  NOT NULL REFERENCES GATEWAYS(ID) ON DELETE CASCADE,
    ACTION          VARCHAR(32)   NOT NULL,           -- 'push' | 'pull' | 'deploy' | 'undeploy'
    STATUS          VARCHAR(32)   NOT NULL,           -- 'success' | 'failed' | 'partial'
    DETAILS         TEXT          DEFAULT '{}',       -- JSON: per-item results, error messages
    ITEM_COUNT      INTEGER       DEFAULT 0,          -- number of items synced
    USER_ID         VARCHAR(255)  DEFAULT '',         -- who triggered (empty in Phase 0)

    CREATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    UPDATED_AT    TEXT          NOT NULL DEFAULT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    CREATED_TIME  BIGINT,
    MODIFIED_TIME BIGINT,
    CREATED_BY    VARCHAR(255),
    MODIFIED_BY   VARCHAR(255),

    CONSTRAINT SYNC_HISTORY_PKEY PRIMARY KEY (ID)
);

CREATE INDEX IF NOT EXISTS IDX_SYNC_HISTORY_DP      ON SYNC_HISTORY (SUBSCRIPTION_ID, GATEWAY_ID);
CREATE INDEX IF NOT EXISTS IDX_SYNC_HISTORY_CREATED ON SYNC_HISTORY (CREATED_AT DESC);

DROP TRIGGER IF EXISTS SET_CREATED_BY ON SYNC_HISTORY;
CREATE TRIGGER SET_CREATED_BY BEFORE INSERT ON SYNC_HISTORY FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_MODIFIED_BY ON SYNC_HISTORY;
CREATE TRIGGER SET_MODIFIED_BY BEFORE UPDATE ON SYNC_HISTORY FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIER();
DROP TRIGGER IF EXISTS SET_CREATED_TIME ON SYNC_HISTORY;
CREATE TRIGGER SET_CREATED_TIME BEFORE INSERT ON SYNC_HISTORY FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_CREATED_TIME();
DROP TRIGGER IF EXISTS SET_MODIFIED_TIME ON SYNC_HISTORY;
CREATE TRIGGER SET_MODIFIED_TIME BEFORE UPDATE ON SYNC_HISTORY FOR EACH ROW EXECUTE PROCEDURE TRIGGER_SET_MODIFIED_TIME();

-- ============================================================
-- MCP_API_KEYS — Hub-managed API keys for external-client
-- authentication on the v1 public API (PCP-19949).
-- Raw key is never stored — only the SHA-256 hex hash.
-- ============================================================
CREATE TABLE IF NOT EXISTS MCP_API_KEYS (
    ID           VARCHAR(255)  NOT NULL,
    NAME         VARCHAR(255)  NOT NULL,
    KEY_HASH     VARCHAR(64)   NOT NULL,
    OWNER_EMAIL  VARCHAR(255)  NOT NULL,
    -- Tenant this key is scoped to; '' = untenanted. Only an 'admin'-scoped key is
    -- treated as global/cross-tenant on the /v1 plane (MCP Hub tenant isolation).
    SUBSCRIPTION_ID VARCHAR(255) DEFAULT '',
    SCOPES       TEXT          NOT NULL DEFAULT '[]',
    CREATED_AT   TEXT          NOT NULL,
    LAST_USED_AT TEXT,
    EXPIRES_AT   TEXT,

    CONSTRAINT MCP_API_KEYS_PKEY    PRIMARY KEY (ID),
    CONSTRAINT MCP_API_KEYS_NAME_UQ UNIQUE (NAME)
);

CREATE INDEX IF NOT EXISTS IDX_MCP_API_KEYS_KEY_HASH ON MCP_API_KEYS (KEY_HASH);

-- Idempotent backfill for environments created before the column existed (mirrors
-- GATEWAYS.SUBSCRIPTION_ID; folded into the unreleased 1-up.sql, no CURRENT_VERSION bump).
ALTER TABLE MCP_API_KEYS ADD COLUMN IF NOT EXISTS SUBSCRIPTION_ID VARCHAR(255) DEFAULT '';

-- PCP-22742 — durable HUB-ORIGIN provenance + explicit peer FEDERATION HEALTH.
-- Folded into the unreleased 1-up.sql, no CURRENT_VERSION bump — same convention as the
-- MCP_API_KEYS.SUBSCRIPTION_ID backfill above and the LAST_PUSHED_FINGERPRINT / PUSH_ERROR
-- columns earlier in this file.
--
-- WHY THESE COLUMNS EXIST. The Hub could not answer "did I put this gateway row here, or did
-- the gateway discover it from an upstream peer?" from durable local state:
--   * the gateway's own provenance stamps (created_via='federation' / federation_source) live
--     only in the LIVE gateway snapshot, and the failure mode to detect is precisely the one
--     where those stamps are missing or renamed — so keying off them goes blind exactly when
--     it matters;
--   * GATEWAY_ENTITY_ID cannot stand in: the PULL stamps it on upstream-DISCOVERED rows too
--     (routes/sync/pull.ts), so a non-null value means "the Hub knows this row's gateway id",
--     NOT "the Hub pushed it".
-- Consequence, observed on a real CP: a peer sits on the gateway registered and 'connected'
-- having federated NOTHING while every push re-reports 'synced', so the environment cannot
-- self-diagnose and the first human-visible symptom is a downstream consumer failing with
-- "ids that do not exist on this gateway".

-- HUB_ORIGIN — written by the Hub itself: 'native' (Hub authored it and pushes it) |
-- 'federated' (discovered on the gateway during a pull; gateway-owned, never pushed) |
-- '' (unknown). Default '' so pre-existing rows stay honestly unknown rather than being
-- silently asserted to be one or the other — consumers MUST fail open on '', never treat it
-- as 'native'. Plain defaulted TEXT with no CHECK, matching ORIGIN / DISCOVERY_SOURCE /
-- WS_STATUS: a CHECK would turn an unexpected future value into a failed INSERT on the hot
-- push path rather than a degraded-but-serving row.
ALTER TABLE CP_TOOLS     ADD COLUMN IF NOT EXISTS HUB_ORIGIN TEXT DEFAULT '';
ALTER TABLE CP_PROMPTS   ADD COLUMN IF NOT EXISTS HUB_ORIGIN TEXT DEFAULT '';
ALTER TABLE CP_RESOURCES ADD COLUMN IF NOT EXISTS HUB_ORIGIN TEXT DEFAULT '';

-- FEDERATION_HEALTH — the peer-federation verdict as an EXPLICIT state:
--   'pending'   created in this push; federation is asynchronous, so "nothing yet" is
--               expected and must NOT be reported as a fault
--   'healthy'   demonstrably contributed at least one tool/prompt/resource
--   'unknown'   no verdict could be reached (a read failed, or attribution resolved nothing)
--   'unhealthy' settled, and demonstrably federated nothing
--   ''          never evaluated (the default, for the same honesty reason as HUB_ORIGIN)
-- CP_SERVERS.PUSH_ERROR already exists but cannot carry this: a nullable error string encodes
-- two states, and reconcileServerPushErrors CLEARS it for every server on each push — so
-- "healthy", "not evaluated" and "could not tell" all collapse to NULL. That collapse IS the
-- defect being fixed.
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS FEDERATION_HEALTH TEXT DEFAULT '';
-- Timestamp of the last federation verdict, so a stale 'healthy' is recognisable as stale
-- rather than trusted indefinitely. TEXT ISO-8601 UTC, matching the CREATED_AT/UPDATED_AT
-- convention used throughout this file (these tables store timestamps as TEXT, not
-- TIMESTAMPTZ, so the two engines agree).
ALTER TABLE CP_SERVERS ADD COLUMN IF NOT EXISTS FEDERATION_CHECKED_AT TEXT;

CREATE TABLE IF NOT EXISTS SCHEMA_VERSION (
    ID SERIAL PRIMARY KEY,
    VERSION INTEGER NOT NULL UNIQUE
);

INSERT INTO SCHEMA_VERSION (VERSION) VALUES (1) ON CONFLICT DO NOTHING;
