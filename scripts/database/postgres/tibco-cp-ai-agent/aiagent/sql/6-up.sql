---------------------------------------------------------------------------
-- AI Agent schema changes for version 6
-- TESSA-808 / TESSA-809 (LLM Conduits) — the model PLATFORM axis on
-- tenant_llm_providers, and the invariant that a role-assumption connection
-- stores no secret at all.
---------------------------------------------------------------------------
-- REMEMBER to update metadata.bash when adding a new n-up.sql file.
-- PostgreSQL only (production). Mirrors scripts/schema.sql in the agent repo.
---------------------------------------------------------------------------
-- 5-up.sql IS FROZEN. It shipped on the 1.21 line, so this is a NEW file rather
-- than an edit. Re-running an already-applied n-up against a database that has
-- it is how a "small edit" becomes a failed upgrade — and, specifically here, an
-- edit to 5-up would do nothing whatsoever to a database already at version 5,
-- which is every database this change is for.
--
-- WHY THIS FILE CARRIES THE WHOLE AXIS, NOT JUST THE LAST FIX
--
-- The agent repository developed this in four local migrations
-- (scripts/migrations/001..004). NONE of them has ever appeared in an n-up file
-- — 1-up through 5-up contain no `platform`, no `auth_method`, no
-- `platform_config`. So a deployed database at version 5 has none of those
-- columns, and a 6-up that only re-stated the final constraint would fail on its
-- first statement: it references columns that do not exist there.
--
-- Everything below is additive and idempotent: ADD COLUMN IF NOT EXISTS,
-- CREATE INDEX IF NOT EXISTS, and constraints added through a guarded DO block.
-- Applying this to a database that already has some of it (a cluster
-- hand-patched during development) is a no-op rather than an error.
---------------------------------------------------------------------------
-- WRAPPED IN A TRANSACTION, following 5-up. postgres-helper.bash runs each
-- migration with `psql -f ... -v ON_ERROR_STOP=1` and NO transaction of its own,
-- so a failure part-way would leave every statement before it committed while
-- SCHEMA_VERSION still read 5 — a half-migrated database the next run cannot
-- distinguish from an un-migrated one. PostgreSQL is transactional for DDL, so
-- the migration becomes all-or-nothing.
---------------------------------------------------------------------------
BEGIN;

-- ===================================================================
-- 1. The platform axis (agent migration 001).
--
-- `provider` names who BUILT a model. That was a sufficient identity while every
-- model was reached directly from its own vendor. It is not once the same model
-- can arrive through AWS Bedrock: "OpenAI direct" and "OpenAI on Bedrock" are
-- different connections, billed to different accounts, authenticated in
-- completely different ways, and `provider` says 'openai' for both.
-- ===================================================================
ALTER TABLE tenant_llm_providers
    -- WHERE the model is served and who bills for it.
    ADD COLUMN IF NOT EXISTS platform              VARCHAR(30),
    -- Non-secret, platform-specific config as JSON text:
    --   Bedrock {region, role_arn} | Vertex {project_id, region}
    ADD COLUMN IF NOT EXISTS platform_config       TEXT,
    -- HOW we authenticate on that platform.
    ADD COLUMN IF NOT EXISTS auth_method           VARCHAR(30),
    -- Encrypted JSON, only for MULTI-VALUE secrets (an AWS key pair). NULL when
    -- a single api_key suffices.
    ADD COLUMN IF NOT EXISTS credentials           TEXT,
    -- Vendor-generated ownership proof (Bedrock AssumeRole -> STS ExternalId).
    -- NEVER writable from a request body: the runtime DERIVES this tenant's
    -- value and ignores whatever is stored, which is what stops one tenant
    -- pointing a row at another tenant's role.
    ADD COLUMN IF NOT EXISTS integration_id        VARCHAR(64),
    -- Revisioned verification. "Verified" has to be able to go stale — a
    -- short-term cloud credential expires, so a bare boolean would go on
    -- claiming a connection works long after it stopped.
    ADD COLUMN IF NOT EXISTS config_revision       INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS verified_revision     INTEGER,
    ADD COLUMN IF NOT EXISTS verified_at           TIMESTAMP,
    ADD COLUMN IF NOT EXISTS credential_expires_at TIMESTAMP;

-- A Bedrock model is reached either by a plain modelId or by a full
-- inference-profile ARN, and the ARN form runs well past 255 characters.
ALTER TABLE tenant_llm_provider_models ALTER COLUMN model TYPE TEXT;

-- ===================================================================
-- 2. BACKFILL BEFORE CONSTRAINING.
--
-- An ALTER on a populated table cannot declare NOT NULL against rows that have
-- no value, so the columns are added nullable above and filled here. Without
-- this step an upgraded database would permanently differ from a fresh one.
-- ===================================================================
-- Each legacy vendor maps to ITS OWN platform. A blanket 'openai' would be
-- wrong for every Anthropic, Azure and Ollama row in the field.
UPDATE tenant_llm_providers SET platform = CASE provider
        WHEN 'openai'       THEN 'openai'
        WHEN 'azure_openai' THEN 'azure'
        WHEN 'azure'        THEN 'azure'
        WHEN 'anthropic'    THEN 'anthropic'
        WHEN 'openrouter'   THEN 'openrouter'
        WHEN 'ollama'       THEN 'ollama'
        WHEN 'vertex'       THEN 'vertex'
        ELSE 'openai'
    END
WHERE platform IS NULL;

-- auth_method is backfilled EXPLICITLY. A blanket 'api_key' would misclassify
-- no-auth configurations such as Ollama, and a misclassified row is worse than
-- an unclassified one because the runtime would then look for a key that was
-- never meant to exist.
UPDATE tenant_llm_providers SET auth_method = CASE
        WHEN provider = 'ollama'                   THEN 'none'
        WHEN provider = 'vertex'                   THEN 'gcp_service_account'
        WHEN api_key IS NOT NULL AND api_key <> '' THEN 'api_key'
        ELSE 'none'
    END
WHERE auth_method IS NULL;

ALTER TABLE tenant_llm_providers ALTER COLUMN platform    SET NOT NULL;
ALTER TABLE tenant_llm_providers ALTER COLUMN auth_method SET NOT NULL;

-- ===================================================================
-- 3. Constraints.
--
-- Note the deliberate asymmetry (agent migration 002):
--   platform = our own small, CLOSED enum          -> constrain in the database
--   provider = an external, OPEN vendor namespace  -> validate in application code
--
-- Bedrock's vendor namespace belongs to AWS and grows without us (zai, meta,
-- mistral, deepseek, qwen, writer...). An enum CHECK on `provider` meant a
-- schema migration before a customer could so much as try a new model, so it is
-- dropped in favour of a cheap shape guard.
-- ===================================================================
ALTER TABLE tenant_llm_providers
    DROP CONSTRAINT IF EXISTS tenant_llm_providers_provider_check;

DO $$ BEGIN
    ALTER TABLE tenant_llm_providers ADD CONSTRAINT tenant_llm_providers_provider_shape
        CHECK (provider ~ '^[a-z0-9_.-]{2,50}$');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE tenant_llm_providers ADD CONSTRAINT tenant_llm_providers_platform_check
        CHECK (platform IN ('openai','anthropic','azure','openrouter','ollama','bedrock','vertex'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE tenant_llm_providers ADD CONSTRAINT tenant_llm_providers_auth_method_check
        CHECK (auth_method IN ('api_key','aws_access_keys','gcp_service_account','aws_assume_role','none'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Exactly ONE default connection per tenant, enforced by the database rather
-- than by application code remembering to clear the others.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_llm_provider_default_per_tenant
    ON tenant_llm_providers (tenant_id) WHERE is_default;

-- Ownership proof must be unique where set (confused-deputy defence).
CREATE UNIQUE INDEX IF NOT EXISTS uniq_llm_provider_integration_id
    ON tenant_llm_providers (integration_id) WHERE integration_id IS NOT NULL;

-- ===================================================================
-- 4. A role-assumption connection stores NO SECRET (agent migrations 003+004).
--
-- The whole argument for `aws_assume_role` is that TESSA holds nothing a thief
-- could use: the connection is a role ARN, an External ID and a region, none of
-- which are secrets. That claim is only worth making if it cannot quietly stop
-- being true. A future code path that "helpfully" cached an assumed session's
-- access key would break the property with no visible symptom — everything would
-- keep working, and the row would silently become a credential store again.
--
-- Expressing it in the schema means the database refuses that write, so the
-- claim stays checkable by anyone with a SQL prompt rather than resting on
-- reviewers remembering why the column is empty.
--
-- BOTH secret columns, deliberately. The agent's migration 003 covered
-- `credentials` alone; `api_key` is the older column that every existing write
-- path targets, so the one place a secret was most likely to land was the one
-- the constraint did not mention. 004 widened it and this ships the wide form.
-- ===================================================================
-- Satisfy the precondition before enforcing it. Scoped to aws_assume_role rows
-- ONLY — without the auth_method predicate these statements wipe every tenant's
-- credentials. There should be no such row today (the auth method is new), but
-- a migration that assumes its own preconditions is how a deploy fails at 3am.
UPDATE tenant_llm_providers
   SET credentials = NULL
 WHERE auth_method = 'aws_assume_role'
   AND credentials IS NOT NULL
   AND btrim(credentials) NOT IN ('', '{}');

UPDATE tenant_llm_providers
   SET api_key = NULL
 WHERE auth_method = 'aws_assume_role'
   AND api_key IS NOT NULL
   AND btrim(api_key) <> '';

-- DROP then ADD under the SAME name. The invariant is one idea; giving the wide
-- version a second name would leave both attached, with the narrow one
-- documenting a weaker rule beside the real one.
ALTER TABLE tenant_llm_providers
    DROP CONSTRAINT IF EXISTS tenant_llm_providers_assume_role_no_secret;

ALTER TABLE tenant_llm_providers
    ADD CONSTRAINT tenant_llm_providers_assume_role_no_secret
    CHECK (
        auth_method <> 'aws_assume_role'
        OR (
            -- NULL and the empty JSON object are both accepted: different
            -- writers have different ideas of "nothing", and rejecting '{}'
            -- would turn a harmless serialisation difference into a failed
            -- save. Anything with actual content is refused.
            (credentials IS NULL OR btrim(credentials) IN ('', '{}'))
            AND (api_key IS NULL OR btrim(api_key) = '')
        )
    );

-- NOT expressed as a constraint: an assume-role row is also meaningless without
-- a role ARN, but that lives inside platform_config, which is free-form JSON
-- shared by every platform. A CHECK reaching into it would couple the schema to
-- one platform's key names and break the next platform added. The conduit
-- validates it at build time and reports a specific error, which is the right
-- place for it.

-- ===================================================================
-- 5. TESSA-873 — what the Interaction Details panel loses on a reload.
--
-- The per-message popover shows the model's provider, a "cached" sub-row under
-- Input and a "reasoning" sub-row under Output while the answer streams, and
-- loses all three the moment the page is refreshed. Cost and the token TOTALS
-- survive, which is the clue: the row IS written, it just has nowhere to put
-- these.
--
-- Each column exists because a value that is already computed for every turn
-- currently has no home:
--
--   llm_provider         Who BUILT the model. `llm_model_used` deliberately
--                        stores the BARE name -- the subscription-metrics
--                        breakdown does GROUP BY on that column, so writing the
--                        qualified "openai:gpt-5.6-luna" there would split one
--                        model into two historical buckets, and the column is
--                        only VARCHAR(64) besides. A separate, typed column is
--                        what makes the qualified id reconstructable without
--                        anything parsing a string back apart.
--
--   llm_platform         WHERE it was served and who billed for it -- the axis
--                        6-up adds to tenant_llm_providers above. Recorded PER
--                        TURN on purpose: a tenant's connection can be switched
--                        at any time, and reading the current one while
--                        rendering an old answer would relabel every past turn
--                        the instant an admin changes platform.
--                        ⚠️ NULL means legacy/unknown, NOT "direct vendor".
--                        Every row written before this migration has one, and
--                        back-filling would have the panel assert a connection
--                        nobody ever recorded. (Deliberately unlike PRICING,
--                        where an unscoped lookup resolves against the direct
--                        vendor entries so those same rows keep the price they
--                        had. Both behaviours are correct; they are not the
--                        same statement.)
--
--   cached_input_tokens  Already counted on every turn and thrown away at save
--   reasoning_tokens     time. The panel guards each sub-row on > 0, which is
--                        why they vanish silently rather than showing a zero.
--
-- NO BACKFILL for any of them. There is nothing to backfill from: the values
-- were never written anywhere, and inventing them is the failure this ticket is
-- about. Legacy rows keep reloading exactly as they do today -- bare model name,
-- no token detail, no error.
--
-- Widths follow the existing contracts rather than an invented size:
-- VARCHAR(50)/VARCHAR(30) match tenant_llm_providers.provider/platform, and
-- BIGINT matches conversation_logs.input_tokens/output_tokens.
--
-- Additive and idempotent like everything above it, so a cluster hand-patched
-- during development takes this as a no-op.
-- ===================================================================
ALTER TABLE conversation_logs
    ADD COLUMN IF NOT EXISTS llm_provider        VARCHAR(50),
    ADD COLUMN IF NOT EXISTS llm_platform        VARCHAR(30),
    ADD COLUMN IF NOT EXISTS cached_input_tokens BIGINT,
    ADD COLUMN IF NOT EXISTS reasoning_tokens    BIGINT;

-- Update the current schema version.
-- SCHEMA_VERSION is a SINGLE-ROW "current version" table: the upgrade runner
-- reads it as a scalar (`SELECT VERSION FROM SCHEMA_VERSION` in
-- postgres-helper.bash) and mutates it in place, so we UPDATE (not INSERT) to
-- keep exactly one row.
-- ===================================================================
-- 6. TESSA-808 — the instance-wide derivation salt, in the DATABASE.
--
-- The Bedrock External ID is HMAC-SHA256(salt, tenant_id). One salt serves
-- every tenant; a per-tenant salt would only mean a per-tenant secret to lose.
--
-- WHY THIS TABLE EXISTS AT ALL. The salt lived in the pod's /app/.env. On
-- 2026-09-29 that container was OOMKilled and restarted from its image, the
-- file was gone, and the salt with it. HMAC is one-way, so every External ID
-- already pasted into a customer's IAM trust policy became unrecoverable in
-- the same instant -- no error, no alert, just a fleet of trust policies that
-- had quietly stopped matching. Recovery meant choosing a new salt and
-- hand-editing IAM. The database is the only thing in this deployment that
-- outlives the container beside it.
--
-- WRITE ONCE, READ FOREVER. The first process to find the table empty inserts
-- the row; nothing updates or deletes it. Changing the value changes every
-- External ID the instance has ever issued, simultaneously, in the field.
--
-- Stored in the clear deliberately: AWS documents External IDs as non-secret,
-- and an encrypted salt would be lost the moment ENCRYPTION_KEY was, which is
-- the failure above wearing a different hat. Back it up with the database.
--
-- salt_name is the natural primary key, not a surrogate -- it is what makes a
-- second row for the same purpose impossible, and that is the invariant. A
-- SERIAL id would let two salts coexist and let readers disagree about which
-- one is real.
--
-- The one table here that is NOT tenant-scoped, and deliberately so.
-- ===================================================================
CREATE TABLE IF NOT EXISTS instance_derivation_salts (
    salt_name  VARCHAR(64) PRIMARY KEY,
    salt_value TEXT NOT NULL,
    source     VARCHAR(16) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CHECK (length(trim(salt_value)) > 0)
);

-- TESSA-898: which generation of the tenant's derived Bedrock External ID is in
-- force, and where a two-phase owner-driven rotation stands. Integers and a phase
-- only, never the External ID. No row = generation 0 = the value every existing
-- trust policy already holds, so no backfill.
CREATE TABLE IF NOT EXISTS bedrock_external_id_rotation (
    tenant_id           VARCHAR(100) PRIMARY KEY,
    active_generation   INTEGER NOT NULL DEFAULT 0,
    pending_generation  INTEGER,
    previous_generation INTEGER,
    next_generation     INTEGER NOT NULL DEFAULT 1,
    phase               TEXT    NOT NULL DEFAULT 'IDLE',
    state_version       INTEGER NOT NULL DEFAULT 0,
    started_at          TIMESTAMP,
    started_by          VARCHAR(128),
    committed_at        TIMESTAMP,
    committed_by        VARCHAR(128),
    CHECK (phase IN ('IDLE', 'PENDING', 'AWAITING_RETIREMENT')),
    CHECK (active_generation >= 0 AND state_version >= 0),
    CHECK (next_generation > active_generation),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

-- ===================================================================
-- One LLM connection per platform (TESSA-808, agent migration 007).
-- Mirrors scripts/migrations/007_one_connection_per_platform.sql and the
-- uniq_llm_connection_per_tenant_platform index in scripts/schema.sql, so an
-- upgraded database has the same key as a fresh one. A tenant already holding
-- two connections on one platform stops the upgrade here, inside this
-- transaction, rather than having one of them chosen silently.
-- ===================================================================
DO $$
DECLARE
    offender RECORD;
BEGIN
    SELECT tenant_id, platform, count(*) AS n
      INTO offender
      FROM tenant_llm_providers
     GROUP BY tenant_id, platform
    HAVING count(*) > 1
     ORDER BY tenant_id, platform
     LIMIT 1;
    IF FOUND THEN
        RAISE EXCEPTION
            'AI Agent database upgrade stopped: subscription % has % LLM connections on platform %. '
            'Only one connection per platform is allowed. No changes have been made.',
            offender.tenant_id, offender.n, offender.platform;
    END IF;
END $$;

UPDATE tenant_llm_providers
   SET provider_name = platform
 WHERE provider_name <> platform;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_llm_connection_per_tenant_platform
    ON tenant_llm_providers (tenant_id, platform);

UPDATE SCHEMA_VERSION
   SET version = 6,
       description = 'LLM connection platform axis, assume-role no-stored-secret invariant (TESSA-808), '
                     'per-turn connection + token detail on conversation_logs (TESSA-873), '
                     'the instance-wide derivation salt (TESSA-808), '
                     'and the Bedrock External ID rotation state (TESSA-898)';

COMMIT;
