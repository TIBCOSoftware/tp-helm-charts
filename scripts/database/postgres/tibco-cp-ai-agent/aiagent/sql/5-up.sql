---------------------------------------------------------------------------
-- AI Agent schema changes for version 5
-- TESSA-442 write-operations consent + TESSA-601/604/605/606 server access
-- + TESSA-613 settings change audit (epic TESSA-449)
-- + TESSA-627 persisted MCP tool catalog, folded in from the 1.21 line.
---------------------------------------------------------------------------
-- ONE FILE, BOTH LINES. The 1.21 line carried its own 5-up.sql for TESSA-627.
-- Rather than add a 6-up.sql to bridge the two, its statements are merged in
-- here: nothing is in production, and a QA database that ends up inconsistent
-- is destroyed and recreated rather than migrated in place. What must hold is
-- that a database rebuilt from this file matches scripts/schema.sql in the
-- agent repo — same columns, same index names, same constraint names.
---------------------------------------------------------------------------
-- REMEMBER to update metadata.bash when adding a new n-up.sql file.
-- PostgreSQL only (production). Mirrors scripts/schema.sql in the agent repo.
---------------------------------------------------------------------------
-- 4-up.sql IS FROZEN. It shipped with 1.21.0-alpha.5 (TESSA-610
-- tenant_user_notices) and QA is testing against it, so every table below is a
-- NEW file rather than an edit to that one. Re-running an already-applied n-up
-- against a database that has it is how a "small edit" becomes a failed upgrade.
--
-- Everything here is additive and idempotent: CREATE TABLE IF NOT EXISTS,
-- CREATE INDEX IF NOT EXISTS, and ADD COLUMN IF NOT EXISTS. Applying this to a
-- database that already has some of it (a cluster hand-patched during
-- development) is a no-op rather than an error.
---------------------------------------------------------------------------

-- ===================================================================
-- TESSA-604/605: identity and dependency columns on the existing
-- tenant_mcp_servers table.
--
-- server_id is the immutable public identity the 606 id-addressed routes use;
-- server_role is the opaque managed role the dependency graph is keyed on.
-- Both are ADDED to an existing table, so they must be nullable here even
-- though the agent's own schema declares server_id NOT NULL for a fresh
-- install - an ALTER on a populated table cannot demand a value that does not
-- exist yet. The agent backfills ids at startup for rows that lack one.
-- ===================================================================
-- ⚠️ WRAPPED IN A TRANSACTION, unlike the earlier n-up files.
-- postgres-helper.bash runs each migration with `psql -f ... -v ON_ERROR_STOP=1` and
-- NO transaction of its own, so a failure part-way leaves every statement before it
-- committed while schema_version still reads 4 - a half-migrated database that the
-- next run cannot distinguish from an un-migrated one. PostgreSQL is transactional
-- for DDL, so the migration becomes all-or-nothing. The trade-off is real but
-- small: DDL locks are held until COMMIT rather than released per statement.
BEGIN;

ALTER TABLE tenant_mcp_servers ADD COLUMN IF NOT EXISTS server_id VARCHAR(64);
ALTER TABLE tenant_mcp_servers ADD COLUMN IF NOT EXISTS server_role VARCHAR(64);

-- BACKFILL BEFORE CONSTRAINING. A fresh install declares server_id NOT NULL with a
-- UNIQUE and a CHECK; an ALTER on a populated table cannot, so the column is added
-- nullable and then filled here. Without this step an upgraded database would
-- permanently differ from a fresh one - no NOT NULL, no uniqueness, and the
-- id-addressed routes (TESSA-606) could match two rows for one id. Divergence
-- between fresh and upgraded is the worst outcome a migration can produce.
--
-- Format matches the agent's own new_server_id(): 'srv_' + uuid4 hex, no dashes.
-- gen_random_uuid() is built in from PostgreSQL 13; this platform is 16.
UPDATE tenant_mcp_servers
   SET server_id = 'srv_' || replace(gen_random_uuid()::text, '-', '')
 WHERE server_id IS NULL OR btrim(server_id) = '';

ALTER TABLE tenant_mcp_servers ALTER COLUMN server_id SET NOT NULL;

-- PostgreSQL has no ADD CONSTRAINT IF NOT EXISTS, so each is guarded by a catalogue
-- lookup. The constraint NAMES are the ones PostgreSQL itself generates for the
-- inline UNIQUE/CHECK in scripts/schema.sql, so an upgraded database ends up with
-- the same catalogue entries a fresh install has - not merely the same behaviour.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'tenant_mcp_servers_tenant_id_server_id_key'
           AND conrelid = 'tenant_mcp_servers'::regclass
    ) THEN
        ALTER TABLE tenant_mcp_servers
            ADD CONSTRAINT tenant_mcp_servers_tenant_id_server_id_key
            UNIQUE (tenant_id, server_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'tenant_mcp_servers_server_id_check'
           AND conrelid = 'tenant_mcp_servers'::regclass
    ) THEN
        ALTER TABLE tenant_mcp_servers
            ADD CONSTRAINT tenant_mcp_servers_server_id_check
            CHECK (length(trim(server_id)) > 0);
    END IF;
END $$;

-- Named to MATCH scripts/schema.sql. An earlier draft called this
-- idx_tenant_mcp_servers_server_id: same columns, different name, so a fresh and an
-- upgraded database would disagree in the catalogue and any later migration that
-- drops or rebuilds it by name would silently miss one of them.

-- ===================================================================
-- TESSA-606: give EXISTING managed servers their role.
--
-- Adding the column is not enough. server_dependencies.py treats a roleless server
-- as having no dependency requirements, so every pre-604 row would silently bypass
-- the TESSA-605 cascade - the Control Plane could be switched off while its
-- dependents stayed on, which is precisely the state 605 exists to prevent.
--
-- Mapping lifted verbatim from the reviewed scripts/tessa606_server_role_backfill.sql
-- rather than re-derived here. URL match first (survives a rename), display name
-- second. A custom or unknown server correctly stays roleless - a wrong role is
-- worse than none, because it would invent a dependency nobody declared.
-- ===================================================================
UPDATE tenant_mcp_servers SET server_role = 'observability'
 WHERE server_role IS NULL AND url LIKE '%o11y-mcp-server%';
UPDATE tenant_mcp_servers SET server_role = 'businessworks'
 WHERE server_role IS NULL AND url LIKE '%bw-mcpserver%';
UPDATE tenant_mcp_servers SET server_role = 'flogo'
 WHERE server_role IS NULL AND url LIKE '%flogo-mcpserver%';
UPDATE tenant_mcp_servers SET server_role = 'control-plane'
 WHERE server_role IS NULL AND url LIKE '%cp-mcp-server%';
UPDATE tenant_mcp_servers SET server_role = 'control-plane'
 WHERE server_role IS NULL AND trim(server_name) = 'Control Plane (Platform)';
UPDATE tenant_mcp_servers SET server_role = 'observability'
 WHERE server_role IS NULL AND trim(server_name) = 'Observability';
UPDATE tenant_mcp_servers SET server_role = 'businessworks'
 WHERE server_role IS NULL AND trim(server_name) = 'BusinessWorks';
UPDATE tenant_mcp_servers SET server_role = 'flogo'
 WHERE server_role IS NULL AND trim(server_name) = 'Flogo';
UPDATE tenant_mcp_servers SET server_role = 'code-execution'
 WHERE server_role IS NULL AND trim(server_name) = 'Code Executor';
UPDATE tenant_mcp_servers SET server_role = 'knowledge-base'
 WHERE server_role IS NULL AND trim(server_name) = 'TIBCO Knowledge';
UPDATE tenant_mcp_servers SET server_role = 'dataplane-aggregator'
 WHERE server_role IS NULL AND trim(server_name) = 'Data Plane MCP Aggregator';

CREATE INDEX IF NOT EXISTS idx_tenant_mcp_servers_sid
    ON tenant_mcp_servers(tenant_id, server_id);

CREATE TABLE IF NOT EXISTS tenant_tool_permissions (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    server_id VARCHAR(64) NOT NULL,            -- TESSA-604: tenant_mcp_servers.server_id
    tool_name VARCHAR(255) NOT NULL,
    mode VARCHAR(16) NOT NULL,                 -- allow | ask_session | ask_once | otp
    policy_version BIGINT NOT NULL DEFAULT 1,  -- bumped on every change (optimistic concurrency)
    def_hash VARCHAR(64),                       -- TESSA-442: sha256 of the tool DEFINITION at set-time
                                                --   (name+desc+schema+security annotations). NULL = drift-check skipped.
    admin_review_required BOOLEAN NOT NULL DEFAULT FALSE,  -- TESSA-442: set TRUE on definition drift; fails writes closed until re-set
    updated_by VARCHAR(255),                   -- admin user_guid
    updated_by_roles TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, server_id, tool_name),
    CHECK (mode IN ('allow','ask_session','ask_once','otp'))
);

CREATE TABLE IF NOT EXISTS tenant_tool_permission_audit (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    server_id VARCHAR(64),
    server_name_snapshot VARCHAR(255),
    tool_name VARCHAR(255),
    old_mode VARCHAR(16),
    new_mode VARCHAR(16),
    policy_version BIGINT,
    changed_by VARCHAR(255),
    changed_by_roles TEXT,
    source VARCHAR(32) DEFAULT 'settings-ui',
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tool_consent (
    id SERIAL PRIMARY KEY,
    challenge_id VARCHAR(64),                  -- groups a batch (NOT unique per row)
    action_id VARCHAR(64) NOT NULL,            -- one tool call = one row
    policy_version BIGINT,                      -- mode version this grant was issued under
    tenant_id VARCHAR(100) NOT NULL,
    user_guid VARCHAR(255),
    session_id VARCHAR(255),                    -- NULL for permanent grants
    -- TESSA-604: the grant is bound to the server's IMMUTABLE id. `server_name_snapshot`
    -- is DISPLAY ONLY — the label as it read when the user was asked — and is never a
    -- lookup key. A rename changes the label; it must not move the grant.
    server_id VARCHAR(64),
    server_name_snapshot VARCHAR(255),
    tool_name VARCHAR(255) NOT NULL,
    scope VARCHAR(16) NOT NULL,                -- pending | once | session | permanent
    status VARCHAR(16) NOT NULL,               -- pending | granted | consumed | denied | expired | cancelled
    canonical_args_hash VARCHAR(64),
    stored_call_ref VARCHAR(128),              -- ref to a protected, expiring exact-call payload
    code_hash VARCHAR(128),                     -- salted OTP hash; never plaintext
    code_salt VARCHAR(64),                      -- per-challenge salt for the OTP hash
    -- TESSA-442 P0-1: DISPLAY-ONLY, secret-redacted JSON describing what the user
    -- is being asked to approve (label, description, guardrail, bounded parameter
    -- preview). Persisted so a card rebuilt after a reload shows the SAME operation,
    -- target and effect it showed before. NEVER the executable raw call and NEVER
    -- the plaintext one-time code; never an authorization or replay input —
    -- canonical_args_hash remains the sole execution binding.
    display_snapshot TEXT,
    consumed_by VARCHAR(64),                    -- claim token: only the winner of the atomic consume sets this
    attempts INTEGER DEFAULT 0,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (action_id),
    CHECK (scope IN ('pending','once','session','permanent')),
    CHECK (status IN ('pending','granted','consumed','denied','expired','cancelled'))
);

CREATE TABLE IF NOT EXISTS tool_execution_consent_audit (
    id SERIAL PRIMARY KEY,
    action_id VARCHAR(64),
    challenge_id VARCHAR(64),
    tool_call_id VARCHAR(128),
    tenant_id VARCHAR(100) NOT NULL,
    conversation_id VARCHAR(255),
    session_id VARCHAR(255),
    user_guid VARCHAR(255),
    -- TESSA-604: append-only audit keeps BOTH — id for correlation across a rename,
    -- snapshot for historical readability. Never a foreign key; never cascade-deleted.
    server_id VARCHAR(64),
    server_name_snapshot VARCHAR(255),
    tool_name VARCHAR(255),
    event_type VARCHAR(32) NOT NULL,
    -- The operation's OWN configured guardrail. NEVER overwritten by an
    -- escalation: an auditor must still see the policy the administrator set.
    mode VARCHAR(16),
    -- TESSA-442 D2: when one model step requests several governed writes whose
    -- guardrails differ, the WHOLE batch is escalated to the strictest guardrail
    -- present and approved once. This records the guardrail that actually
    -- SATISFIED the operation. With mode + satisfied_by_mode + the shared
    -- challenge_id, "this tool's policy was ask-once-per-chat and it was approved
    -- via a one-time code as part of batch X" is readable, not inferred.
    satisfied_by_mode VARCHAR(16),
    reason TEXT,
    args_summary TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tool_result_evidence (
    evidence_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(100) NOT NULL,
    user_guid VARCHAR(255),
    session_id VARCHAR(255),
    conversation_id VARCHAR(255),
    tool_call_id VARCHAR(128),
    -- TESSA-604: evidence is a historical record of what a tool RETURNED, so it keeps
    -- both — `server_id` so the row stays correlated to its server across a rename,
    -- and `server_name_snapshot` because the grounding block rendered to the model
    -- must name a server a human recognises, not an opaque id.
    server_id VARCHAR(64),
    server_name_snapshot VARCHAR(255),
    tool_name VARCHAR(255) NOT NULL,
    tool_def_hash VARCHAR(64),                 -- sha256(server_id::tool::definition) at capture time
    args_hash VARCHAR(64),                     -- canonical_args_hash of the call that produced it
    status VARCHAR(16) NOT NULL,               -- only 'success' rows are ever used as grounding
    executed_at TIMESTAMP NOT NULL,            -- when the tool RAN (drives FRESH vs STALE)
    evidence_bytes INTEGER NOT NULL DEFAULT 0,
    evidence_text TEXT,
    change_request TEXT,
    write_outcome VARCHAR(24),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (evidence_id),
    -- Tool output describes the tenant's own environment, so deleting the
    -- tenant must take it with them. Same FK every sibling TESSA-442 table uses.
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tenant_policy_generation (
    tenant_id VARCHAR(100) PRIMARY KEY,
    generation BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tenant_config_change_audit (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    -- Dotted, from agent/services/config_audit_vocabulary.py. That module owns the
    -- user-facing English too — a UI-side copy of this table has broken FOUR times.
    event_type VARCHAR(64) NOT NULL,
    occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- 'user' | 'system' | 'unattributed'. A missing actor is NEVER recorded as
    -- 'system': that would falsely attribute a real user's request to the platform
    -- on the one occasion (middleware failure) when an auditor most needs the truth.
    actor_type VARCHAR(16) NOT NULL DEFAULT 'unattributed',
    actor_guid VARCHAR(255),
    -- Comma-joined, matching tenant_tool_permission_audit.changed_by_roles. One audit
    -- tab must not carry two role encodings.
    actor_roles TEXT,
    target_type VARCHAR(32),
    target_id VARCHAR(255),
    target_name VARCHAR(255),
    old_value TEXT,
    new_value TEXT,
    source VARCHAR(32) DEFAULT 'settings-ui',
    -- Correlates the N field-events emitted by one blob PUT into one action.
    request_id VARCHAR(64),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

-- ===================================================================
-- REPAIR AN OLDER TABLE BEFORE ANY INDEX TOUCHES IT.
--
-- CREATE TABLE IF NOT EXISTS silently PRESERVES an existing table rather than
-- upgrading it, so a cluster where these were hand-created from an earlier
-- scripts/schema.sql reaches version 5 still missing columns the application writes.
--
-- ⚠️ ORDER MATTERS AND WAS WRONG. This block used to sit AFTER the index section, so
-- on exactly the database it exists to repair, `CREATE INDEX ... (tenant_id,
-- server_id, tool_name)` referenced a column that was still missing and aborted the
-- whole transaction before the repair ran.
--
-- Every line below is DERIVED from scripts/schema.sql, not hand-written: an earlier
-- draft invented `tenant_tool_permissions.server_name_snapshot`, which does not
-- exist in the fresh schema, and typed satisfied_by_mode as VARCHAR(32) when it is
-- VARCHAR(16). Adding a column a fresh install does not have is the same fidelity
-- defect as omitting one, just in the other direction.
--
-- Customers are unaffected: they have none of these tables, so the CREATEs above give
-- them the correct shape outright. This is for development and QA clusters.
-- ===================================================================
ALTER TABLE tenant_tool_permissions      ADD COLUMN IF NOT EXISTS server_id VARCHAR(64);
ALTER TABLE tenant_tool_permission_audit ADD COLUMN IF NOT EXISTS server_id VARCHAR(64);
ALTER TABLE tenant_tool_permission_audit ADD COLUMN IF NOT EXISTS server_name_snapshot VARCHAR(255);
ALTER TABLE tool_consent                 ADD COLUMN IF NOT EXISTS server_id VARCHAR(64);
ALTER TABLE tool_consent                 ADD COLUMN IF NOT EXISTS server_name_snapshot VARCHAR(255);
ALTER TABLE tool_consent                 ADD COLUMN IF NOT EXISTS display_snapshot TEXT;
ALTER TABLE tool_execution_consent_audit ADD COLUMN IF NOT EXISTS server_id VARCHAR(64);
ALTER TABLE tool_execution_consent_audit ADD COLUMN IF NOT EXISTS server_name_snapshot VARCHAR(255);
ALTER TABLE tool_execution_consent_audit ADD COLUMN IF NOT EXISTS satisfied_by_mode VARCHAR(16);
ALTER TABLE tool_result_evidence         ADD COLUMN IF NOT EXISTS server_id VARCHAR(64);
ALTER TABLE tool_result_evidence         ADD COLUMN IF NOT EXISTS server_name_snapshot VARCHAR(255);
-- TESSA-630: a change operation records WHAT it was asked to apply and the TYPED
-- outcome, in host-written columns. They are separate from evidence_text because
-- that column holds tool OUTPUT: an in-band marker there is forgeable by a tool
-- result, which would show the response guard a change the agent never requested.
ALTER TABLE tool_result_evidence         ADD COLUMN IF NOT EXISTS change_request TEXT;
ALTER TABLE tool_result_evidence         ADD COLUMN IF NOT EXISTS write_outcome VARCHAR(24);

-- TESSA-641: the user's own read-only toggle for one chat session. Same shape as the
-- TESSA-197 is_pinned/pinned_at pair in 3-up.sql: a per-session boolean, owner-scoped
-- by the table's (session_id, tenant_id, user_guid) key. Durable rather than in-memory
-- because it is a safety control -- a per-pod cache would find writes enabled again on
-- the next pod, having already told the user they were protected.
ALTER TABLE conversation_logs_session_metadata ADD COLUMN IF NOT EXISTS read_only BOOLEAN DEFAULT FALSE;
ALTER TABLE conversation_logs_session_metadata ADD COLUMN IF NOT EXISTS read_only_set_at BIGINT;

-- TESSA-645: the other half of the same user-owned write posture -- "skip the routine
-- approval cards in this one chat". Added to 5-up.sql rather than a new file because 5
-- has not shipped: 4-up.sql is the frozen one. Same column type, nullability and
-- default as the agent's own CREATE TABLE, so an upgraded database and a fresh one end
-- identical.
--
-- Two columns, never a both-true row from this code: the writer sets them in one
-- statement from one enum. A row that somehow holds both resolves to Read-only, which
-- is the only misreading a user can recover from by asking again.
ALTER TABLE conversation_logs_session_metadata ADD COLUMN IF NOT EXISTS auto_approve BOOLEAN DEFAULT FALSE;

-- TESSA-687: when an authenticated caller RESERVED this session -- claimed it as the
-- chat was opened, before it had any history. Added to 5-up.sql for the same reason
-- auto_approve was: 5 has not shipped, 4-up.sql is the frozen one.
--
-- Ownership was previously derived from the interactions table, whose first row only
-- appears once a turn has been logged, so a chat that had merely been opened had no
-- owner and every owner-scoped control refused it. A user could not set Read-only at
-- the one moment they most want to.
--
-- NULL is NOT "unowned by nobody" -- it means this row was created by something other
-- than a reservation (a title, a pin, a posture) and says nothing about ownership.
-- get_session_identity tests reserved_at IS NOT NULL precisely so that a rename, which
-- also creates a row here, cannot become a claim on a session id.
--
-- Nullable with no default, so every existing row reads as unreserved and keeps the
-- old interaction-history behaviour. Reservation is OPTIONAL: clients that never
-- reserve are unaffected.
ALTER TABLE conversation_logs_session_metadata ADD COLUMN IF NOT EXISTS reserved_at BIGINT;

-- TESSA-702: what an operation's TARGET was CALLED, as a {id: name} JSON map.
--
-- Every other readable field on an audit row describes the OPERATION -- its tool,
-- its guardrail, its outcome. None describes what it was done TO, so a row reads
-- "createActivationServer against d6bojjpg92ac73aabt30" and an auditor searching
-- for the data plane by name finds nothing.
--
-- A snapshot, like server_name_snapshot beside it: a later lookup would show
-- today's name, or fail once the entity is renamed or deleted. An audit should
-- record what the thing was called when the operation happened.
--
-- Nullable with no default, so every existing row reads as "no name recorded" --
-- which is also the normal outcome going forward, whenever the turn's reads did
-- not label the id. Never inferred, never a placeholder.
--
-- Added to 5-up.sql rather than a new file for the same reason auto_approve and
-- reserved_at were: 5 has not shipped, 4-up.sql is the frozen one.
ALTER TABLE tool_execution_consent_audit ADD COLUMN IF NOT EXISTS target_names TEXT;

-- STOP RATHER THAN LIMP. A genuinely pre-604 table can still carry
-- `server_name NOT NULL`, which ADD COLUMN cannot repair: the new code inserts
-- server_id and no name, so every write would fail AFTER this migration reported
-- success. There is no safe automatic conversion - mapping names to ids needs the
-- tenant's own server list - so the supported starting states are narrowed
-- explicitly and anything else fails loudly, inside the transaction, changing
-- nothing.
DO $$
DECLARE offender text;
BEGIN
    SELECT string_agg(table_name || '.' || column_name, ', ')
      INTO offender
      FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name IN ('tenant_tool_permissions','tenant_tool_permission_audit',
                          'tool_consent','tool_execution_consent_audit','tool_result_evidence')
       AND column_name = 'server_name'
       AND is_nullable = 'NO';
    IF offender IS NOT NULL THEN
        -- ⚠️ CUSTOMER-VISIBLE TEXT. This is the only string in this file a customer
        -- can ever see, and they see it during a Helm upgrade. No Jira ids, no
        -- internal script paths, no branch names - those mean nothing to them and
        -- reading them in a failed upgrade is alarming rather than useful. The
        -- internal detail belongs in this comment, which never reaches them:
        -- pre-TESSA-604 rows key tool permissions by server_name; the fix is
        -- scripts/tessa604_server_id_backfill.sql in the agent repo.
        --
        -- What they DO need: what stopped, that nothing changed, and who to call.
        -- The object names stay - it is their database and support will ask.
        RAISE EXCEPTION USING
          MESSAGE = 'AI Agent database upgrade stopped: the tool-permission tables in '
                    'this database use an older layout that cannot be upgraded '
                    'automatically (' || offender || '). No changes have been made.',
          HINT    = 'This database was created by an earlier pre-release build. Its '
                    'existing rows cannot be converted automatically. Please contact '
                    'TIBCO support and quote this message.';
    END IF;
END $$;

-- The two lookup indexes are DROPPED and rebuilt because CREATE INDEX IF NOT EXISTS
-- matches on NAME ONLY: an index of that name over the pre-604 columns would survive
-- and quietly serve the wrong plan. Both are plain indexes in schema.sql, so DROP
-- INDEX is safe; a constraint-backed index of the same name would abort the
-- transaction, which is the correct outcome for a shape we do not support.
DROP INDEX IF EXISTS idx_tool_perms_lookup;
DROP INDEX IF EXISTS idx_tool_consent_lookup;

CREATE INDEX IF NOT EXISTS idx_tool_perms_tenant ON tenant_tool_permissions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tool_perms_lookup ON tenant_tool_permissions(tenant_id, server_id, tool_name);
CREATE INDEX IF NOT EXISTS idx_tool_consent_action ON tool_consent(action_id);
CREATE INDEX IF NOT EXISTS idx_tool_consent_lookup ON tool_consent(tenant_id, user_guid, session_id, server_id, tool_name);
CREATE INDEX IF NOT EXISTS idx_tool_consent_challenge ON tool_consent(challenge_id);
CREATE INDEX IF NOT EXISTS idx_tool_perm_audit_tenant ON tenant_tool_permission_audit(tenant_id, changed_at);
CREATE INDEX IF NOT EXISTS idx_tool_exec_audit_conv ON tool_execution_consent_audit(tenant_id, conversation_id);
CREATE INDEX IF NOT EXISTS idx_tool_exec_audit_tenant_id ON tool_execution_consent_audit(tenant_id, id);
CREATE INDEX IF NOT EXISTS idx_tool_perm_audit_tenant_id ON tenant_tool_permission_audit(tenant_id, id);
CREATE INDEX IF NOT EXISTS idx_config_audit_tenant ON tenant_config_change_audit(tenant_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_config_audit_event ON tenant_config_change_audit(tenant_id, event_type);
CREATE INDEX IF NOT EXISTS idx_tool_evidence_scope ON tool_result_evidence(tenant_id, user_guid, session_id, executed_at);



-- ===================================================================
-- TESSA-627: provenance of an MCP server row.
--
-- Auto-acknowledgement of a server's tools may only be granted to servers WE
-- provision. server_role cannot carry that decision: the config-import path can
-- SUPPLY a role (config_importer.py) and validate_server_roles only checks the
-- role is known, not that the caller was entitled to claim it. Treating a
-- supplied role as proof of provenance would let an imported server nominate
-- itself as trusted and skip review entirely.
--
-- Written ONLY by internal provisioners; stripped on the import and API paths.
-- Existing rows are backfilled to 'user'. An earlier draft claimed everything
-- already in this table came from a provisioner and backfilled 'system'; that is
-- not true - the settings API and config import have both been able to insert
-- here for far longer than this column has existed.
-- ===================================================================
-- DEFAULT 'user', NOT 'system'. An earlier draft defaulted to 'system' and then
-- backfilled every existing row to 'system' on the claim that everything in this
-- table came from an internal provisioner. That claim is false: the settings API
-- and config import have both been able to insert here since long before this
-- migration, so an upgraded database can hold tenant-created servers - and every
-- one of them would have been elevated to trusted, auto-approving its tools. A
-- 'system' default also means any future INSERT that simply forgets the column
-- becomes privileged by accident, which is the wrong direction for a mistake to
-- fall.
ALTER TABLE tenant_mcp_servers
    ADD COLUMN IF NOT EXISTS provisioning_source VARCHAR(16) DEFAULT 'user';

-- Repair a database that applied the earlier draft: put the permissive default back
-- to 'user' before anything else runs.
ALTER TABLE tenant_mcp_servers ALTER COLUMN provisioning_source SET DEFAULT 'user';

-- Every historical row becomes 'user'. Nothing is promoted back.
--
-- ⚠️ NO URL-DERIVED PROMOTION. This migration used to grant 'system' - and with
-- it control-plane TRUST - to any pre-existing row whose URL matched the managed
-- in-cluster host pattern. Successive drafts tightened the matching (substring ->
-- anchored host regex) on the theory that a tight enough pattern makes the
-- inference sound. It does not. The inference itself is the defect: a URL is not
-- provenance. It is a field a tenant writes. The settings API validates only that
-- it is syntactically HTTP(S) with a host (agent/utils/validation.py), so a server
-- a tenant created through Settings, whose URL happens to sit on the cluster DNS
-- pattern, was promoted to trusted - and a trusted server's tools are acknowledged
-- on sight, which is the one thing this column exists to prevent.
--
-- Unknown history therefore stays 'user' and untrusted. That fails CLOSED: the
-- worst outcome is an administrator being asked to approve tools they would have
-- got silently, which is what the feature is for. The alternative fails open, and
-- silently.
--
-- Nothing is lost by this. Every server WE provision writes its own
-- provisioning_source='system' at provision time - code_executor_auto_provisioner,
-- dp_mcp_aggregator_auto_provisioner, tibco_kb_auto_provisioner and the
-- control-plane/o11y/BW/Flogo provisioners all set it on the INSERT - so a managed
-- server re-provisioned after this upgrade carries its own proof. There is no
-- verified id list to backfill from, and inventing one from URLs is the thing
-- being removed.
UPDATE tenant_mcp_servers
   SET provisioning_source = 'user'
 WHERE provisioning_source IS NULL
    OR btrim(provisioning_source) = ''
    OR provisioning_source NOT IN ('system', 'import', 'user');

-- ===================================================================
-- TESSA-627: the persisted tool catalog, one row per (subscription, server, tool).
--
-- Grain is the SUBSCRIPTION, not the user: the DP MCP Aggregator scopes tools by
-- the JWT `gsbc` claim, and gsbc IS the subscription. Only the admin Reconnect
-- path writes this table - a per-user discovery could otherwise seed a reduced
-- baseline, because a server may legitimately return fewer tools to a
-- lower-privileged caller.
--
-- PRESENCE AND REVIEW ARE SEPARATE COLUMNS ON PURPOSE. A never-acknowledged tool
-- that disappears and comes back must not be labelled "changed" - it is present
-- and unreviewed. Collapsing them into one enum produces exactly that bug.
--
-- review_state has TWO values, deliberately. An earlier draft had a third,
-- 'changed', which quietly made a signature change gate the tool. It must not:
-- the aggregator carries the onboarded data planes as an ENUM INSIDE the tool's
-- input schema, so onboarding a data plane changes the signature of every
-- aggregator tool. Gating on that would disable kubectl and helm at exactly the
-- moment an operator onboards a data plane. Removing the value removes the
-- possibility. A signature change sets change_notice and nothing else.
--
-- The one escalation that DOES withdraw an approved tool - acknowledged
-- read-only, now write-capable - is decided by comparing acknowledged_read_only
-- against the live read_only_hint. A stored boolean, not a hash.
-- ===================================================================
CREATE TABLE IF NOT EXISTS tenant_mcp_tools (
    id                     SERIAL PRIMARY KEY,
    tenant_id              VARCHAR(100) NOT NULL,
    -- The immutable identity, NOT the display name: renaming a server must not
    -- orphan its catalog and silently re-gate every tool it owns.
    server_id              VARCHAR(64)  NOT NULL,
    -- DISPLAY ONLY - the label as it read when the tool was recorded. Never a
    -- lookup key.
    server_name_snapshot   VARCHAR(255),
    tool_name              VARCHAR(255) NOT NULL,

    -- Definition snapshot. input_schema is kept RAW so the UI can show an admin
    -- exactly which parameters exist (the aggregator's `dataplane` argument is
    -- invisible today because only the description is rendered) and so a diff
    -- can say what actually changed.
    description            TEXT,
    input_schema           TEXT,
    -- Tri-state on purpose: absent is NOT false. MCP defaults destructiveHint and
    -- openWorldHint to TRUE, so recording `absent` as `false` would turn a
    -- security escalation into a no-op. NULL means the server did not say.
    read_only_hint         BOOLEAN,
    destructive_hint       BOOLEAN,
    idempotent_hint        BOOLEAN,
    open_world_hint        BOOLEAN,
    -- ONE exact fingerprint over the whole canonicalised definition, enum values
    -- included. Safe to be exact precisely because its only consequence is a
    -- notice. hash_version lets the algorithm change without a false storm.
    def_hash               VARCHAR(64) NOT NULL,
    hash_version           SMALLINT NOT NULL DEFAULT 1,

    -- Presence, independent of review.
    presence               VARCHAR(16) NOT NULL DEFAULT 'present',
    first_seen_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    missing_since          TIMESTAMP,
    -- Dedupes concurrent discoveries: two pods, or two rapid Reconnect clicks,
    -- must not double-count one outage into a 'missing' promotion.
    last_observation_id    VARCHAR(64),

    -- Review, independent of presence. THE ONLY COLUMN THAT GATES.
    review_state           VARCHAR(16) NOT NULL DEFAULT 'unreviewed',
    acknowledged_at        TIMESTAMP,
    acknowledged_by        VARCHAR(255),
    acknowledged_def_hash  VARCHAR(64),
    -- The safety posture a human actually signed off, so the read-only ->
    -- write-capable escalation is decided against what was approved rather than
    -- against the previous observation.
    acknowledged_read_only BOOLEAN,

    -- Informational only; NEVER gates. Cleared when an admin dismisses it.
    change_notice          VARCHAR(32),

    created_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- The catalog describes the tenant's own environment, so deleting the tenant
    -- must take it with them. Same FK every sibling table uses, and load-bearing:
    -- TESSA-485 showed that deleting a `tenants` row is how a subscription is
    -- re-onboarded, and a stale acknowledgement outliving its subscription would
    -- silently pre-approve tools for the fresh one.
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, server_id, tool_name),
    CHECK (presence      IN ('present','possibly_missing','missing')),
    CHECK (review_state  IN ('unreviewed','acknowledged')),
    CHECK (change_notice IS NULL OR change_notice IN ('signature_changed','reappeared','removed'))
);

-- ⚠️ The CREATE above is IF NOT EXISTS, so editing its inline CHECK does NOTHING
-- for a database that already ran an earlier draft of this migration - the old
-- two-value constraint stays and every attempt to record 'removed' fails with a
-- CheckViolationError. Found the hard way on a live cluster: reconcile swallows
-- the per-row error, so the tool silently stayed un-noticed and the only trace
-- was one ERROR line in the agent log.
--
-- Drop and re-add explicitly. Guarded so it is idempotent, and named exactly as
-- PostgreSQL names the inline constraint, so an upgraded database ends up with
-- the same catalogue entry a fresh install has.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname = 'tenant_mcp_tools_change_notice_check'
           AND conrelid = 'tenant_mcp_tools'::regclass
    ) THEN
        ALTER TABLE tenant_mcp_tools
            DROP CONSTRAINT tenant_mcp_tools_change_notice_check;
    END IF;

    ALTER TABLE tenant_mcp_tools
        ADD CONSTRAINT tenant_mcp_tools_change_notice_check
        CHECK (change_notice IS NULL
               OR change_notice IN ('signature_changed', 'reappeared', 'removed'));
END $$;

CREATE INDEX IF NOT EXISTS idx_tenant_mcp_tools_tenant
    ON tenant_mcp_tools (tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_mcp_tools_review
    ON tenant_mcp_tools (tenant_id, review_state);
CREATE INDEX IF NOT EXISTS idx_tenant_mcp_tools_server
    ON tenant_mcp_tools (tenant_id, server_id);

-- ===================================================================
-- TESSA-627: catalog-decision auditing is NOT created on the 1.21 line.
--
-- This migration used to create `tenant_mcp_tool_audit`. It is deliberately
-- gone: nothing in 1.21 ever read those rows - there is no API and no UI - and
-- the audit viewer arrives with TESSA-442, which has independently designed a
-- different audit schema (tenant_config_change_audit /
-- tenant_tool_permission_audit / tool_execution_consent_audit) that does not
-- include this table. Creating a write-only table with competing semantics only
-- makes the merge worse, so auditing is deferred wholesale to 442.
--
-- The writer, MCPToolApprovalService._audit, is disabled to match, with its
-- signature and all its call sites left in place; it gets re-pointed at 442's
-- tables on merge. Deployments that already ran an earlier build of this
-- migration keep an empty table - inert, and nothing reads or writes it.
-- ===================================================================

-- ===================================================================
-- TESSA-627: per-subscription tool-approval settings.
--
-- NOT called a "policy": on the TESSA-442 line that word means the write-consent
-- guardrails (tenant_tool_permissions, policy_version, tenant_policy_generation),
-- which are a different feature and are not on this branch at all. Reusing the
-- term for a pair of on/off switches would make both harder to read, especially
-- at merge.
--
-- auto_accept_new_tools DEFAULT FALSE. Gating new tools is the entire point of
-- the feature; auto-accepting by default would ship the old silent behaviour
-- under a new name. (require_tool_approval is the other switch and ships TRUE —
-- see its own comment on the column.)
--
-- A column on tenant_config would have been smaller, but that table is a
-- key/value blob written by the settings PUT path, and this flag decides whether
-- capabilities reach the agent. It gets its own typed row and its own audit.
-- ===================================================================
CREATE TABLE IF NOT EXISTS tenant_mcp_tool_settings (
    tenant_id           VARCHAR(100) PRIMARY KEY,
    -- Is tool approval switched ON for this subscription?
    --
    -- A row here exists ONLY once an administrator has chosen. The shipped
    -- default for a subscription that has never chosen lives in the agent, in
    -- mcp_tool_approval_service.DEFAULT_REQUIRE_APPROVAL, because no INSERT in
    -- the code omits this column and a column default would therefore never be
    -- reached. This DEFAULT is kept in step with that constant so the two cannot
    -- read differently; it is not the thing that decides.
    --
    -- ⚠️ It ships ON. Nothing trusted is withdrawn by that: tools from servers we
    -- provision are adopted on sight. What waits for a human on the first
    -- observation after upgrade is the DP MCP Aggregator's tools (executeKubectl,
    -- executeHelm) and any server the customer added themselves — surfaced as an
    -- "N new tools" badge, not a silent disappearance. And a subscription whose
    -- catalog has never been recorded is not gated at all, so upgrading does not
    -- empty an agent before anyone has looked at it.
    require_tool_approval     BOOLEAN NOT NULL DEFAULT TRUE,
    auto_accept_new_tools  BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by          VARCHAR(255),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

-- Repair for a cluster that already applied an earlier build of this file.
ALTER TABLE tenant_mcp_tool_settings
    ADD COLUMN IF NOT EXISTS require_tool_approval BOOLEAN NOT NULL DEFAULT TRUE;

-- ⚠️ ADD COLUMN IF NOT EXISTS is a no-op where the column is already there, so on
-- a cluster that applied the EARLIER build of this file the default stays FALSE.
-- Codex P1: the agent's INSERTs did not always name this column, so such a
-- cluster created rows that inherited FALSE — saving auto-accept alone switched
-- approval off with nothing to show for it. The agent now writes both columns
-- explicitly, which is the real fix; this keeps the schema from disagreeing.
--
-- SET DEFAULT changes what FUTURE inserts inherit. It does not touch a single
-- existing row, which is the point: a row already there records a decision
-- somebody made, and an upgrade must not overturn it. There is deliberately no
-- backfill and no UPDATE.
ALTER TABLE tenant_mcp_tool_settings
    ALTER COLUMN require_tool_approval SET DEFAULT TRUE;

-- ===================================================================
-- TESSA-627: record WHEN each server's catalog was last successfully listed.
--
-- Codex P0. "Has this subscription ever been observed" was inferred from the
-- existence of any row in tenant_mcp_tools, which is the wrong question in three
-- ways. A server that answers cleanly with ZERO tools writes no row, so it looked
-- unobserved for ever and its tools passed ungated when they finally appeared -
-- and that is TESSA-527's own case, the aggregator with no data planes onboarded.
-- A partial discovery, 3 of 7 servers answering, wrote rows and thereby switched
-- enforcement on for all seven, silently withholding the other four servers'
-- tools. And deleting the last inventoried server emptied the table, which read
-- as "never observed" again.
--
-- Answering is a fact about the SERVER, so it is recorded on the server. Set from
-- answered_server_ids, which already means "responded cleanly", zero tools
-- included, and already excludes a server whose tools/list threw.
--
-- Per server rather than one flag for the tenant, deliberately: a single
-- permanently broken server - a bad URL, a dead endpoint - must not be able to
-- hold enforcement off for every other server in the subscription for ever.
--
-- NULL means never successfully listed, and a tool from such a server is not
-- gated: there is nothing to gate against and withholding it would take away a
-- capability nobody has had the chance to review.
-- ===================================================================
ALTER TABLE tenant_mcp_servers
    ADD COLUMN IF NOT EXISTS catalog_observed_at TIMESTAMP;

-- ===================================================================
-- TESSA-627: purge ORPHANED inventory rows.
--
-- A tool row is keyed on server_id. If no server with that id exists any more,
-- nothing will ever reconcile the row again: it sits at whatever presence it
-- last had - typically 'present' - for ever, inflating counts and telling an
-- auditor a tool is available from a server that is gone.
--
-- Two ways they were created, both now fixed at source: deleting a server left
-- its tools behind, and an earlier draft rotated server_id when a URL was
-- edited, stranding every approval under the old id. This cleans up databases
-- that already have them, because otherwise there is no moment at which anyone
-- ever would.
--
-- The AUDIT table is deliberately untouched. Who approved what, and when,
-- outlives the server.
-- ===================================================================
DELETE FROM tenant_mcp_tools t
 WHERE NOT EXISTS (
     SELECT 1 FROM tenant_mcp_servers s
      WHERE s.tenant_id = t.tenant_id
        AND s.server_id = t.server_id
 );

-- Update database schema version
UPDATE SCHEMA_VERSION
   SET version = 5,
       description = 'Write-operation consent, immutable MCP server identity and roles, durable evidence, settings audit, and the persisted MCP tool catalog with admin gating (TESSA-442 + TESSA-627)';

COMMIT;
