---------------------------------------------------
-- AI Agent schema changes for version 1.2 (TESSA-181 + TESSA-182)
---------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------

-- Persist rerun/variation grouping so reruns stay grouped after reload.
-- rerun_root_conversation_id = the conversation_id of the rerun family's ROOT
-- (the original). A fresh row is its own root; a rerun shares the root of the
-- message it was launched from. Additive, non-breaking.
ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS rerun_root_conversation_id VARCHAR(64);

-- Backfill every existing row as its own root (singletons). Pre-existing reruns
-- stay ungrouped (acceptable per locked decision: no retro-grouping of old data).
UPDATE conversation_logs SET rerun_root_conversation_id = conversation_id
  WHERE rerun_root_conversation_id IS NULL;

-- Index for grouping/lookup by family within a session.
-- Name MUST match the agent runtime backstop (pgsql_conversation_adapter.py:
-- f"idx_{self.table_name}_session_root" => idx_conversation_logs_session_root)
-- so dev/local envs that run both migration and runtime DDL don't create two
-- equivalent indexes. (Diverges from the older idx_conv_* names in 1-up.sql by design.)
CREATE INDEX IF NOT EXISTS idx_conversation_logs_session_root
  ON conversation_logs (session_id, rerun_root_conversation_id);

-- TESSA-182: monthly ROLLUP of ancillary (non-conversation) LLM cost.
-- Improve-prompt, improve-chart-hint, follow-up suggestions, and future per-user
-- LLM ops UPSERT-increment one bounded counter row per
-- (tenant=subscription gsbc, user_guid, operation_type, period_month) instead of
-- mutating conversation_logs (whose cost must stay stable after reload). Bounded
-- (~users x ops x months); all-time = SUM over months, "this month" = one bucket.
-- Per-call detail (trace_url / conversation_id) lives in LangFuse, not here.
CREATE TABLE IF NOT EXISTS llm_usage_rollup (
    tenant_id         VARCHAR(64)   NOT NULL,   -- == subscription (gsbc)
    user_guid         VARCHAR(128)  NOT NULL,
    operation_type    VARCHAR(64)   NOT NULL,   -- 'improve_prompt'|'improve_chart_hint'|'followup_suggestions'|...
    period_month      CHAR(7)       NOT NULL,   -- 'YYYY-MM' (UTC)
    count             BIGINT        NOT NULL DEFAULT 0,
    total_cost_usd    NUMERIC(18,9) NOT NULL DEFAULT 0,   -- accounting -> NUMERIC, not FLOAT
    input_tokens      BIGINT        NOT NULL DEFAULT 0,
    output_tokens     BIGINT        NOT NULL DEFAULT 0,
    cache_read_tokens BIGINT        NOT NULL DEFAULT 0,   -- audit: cached-input tokens
    reasoning_tokens  BIGINT        NOT NULL DEFAULT 0,   -- audit: reasoning/thinking output tokens
    updated_at        BIGINT        NOT NULL,             -- epoch ms of last increment
    PRIMARY KEY (tenant_id, user_guid, operation_type, period_month)
);
-- PK prefix (tenant_id, user_guid) serves per-user reads; this index serves
-- admin per-subscription / per-month scans.
CREATE INDEX IF NOT EXISTS idx_usage_rollup_tenant_month ON llm_usage_rollup (tenant_id, period_month);

-- TESSA-198: provenance bitmask on each conversation turn. Captures how the
-- user's prompt originated (1=follow-up pill, 2=improved, 4=improved-verbatim,
-- 8=sample-prompt card; see OriginFlag) for adoption metrics. Additive,
-- non-breaking; the server masks to the allowed bits before persist. Pre-release,
-- so we append here (no 4-up.sql) — SCHEMA_VERSION stays 3. Mirrors the in-code
-- DDL backstop in pgsql_conversation_adapter.py / pgvector_conversation_adapter.py.
ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS origin_flags INTEGER DEFAULT 0;

-- TESSA-206: synthesis (code-execution) flag per conversation turn. True when
-- programmatic synthesis (execute_python) ran for the turn, derived server-side
-- from the RAW tools_called at persist time. Lets the UI show a quiet synthesis
-- hint that survives reload, while the code-executor tool/server name stays masked
-- everywhere it reaches the frontend. Additive, non-breaking; cheap boolean.
-- Pre-release, so we append here (no 4-up.sql) — SCHEMA_VERSION stays 3. Mirrors
-- the in-code DDL backstop in pgsql_conversation_adapter.py / pgvector_conversation_adapter.py.
ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS synthesis_performed BOOLEAN DEFAULT FALSE;

-- TESSA-197: pin/unpin a conversation so it stays on top of the sidebar. Two
-- additive columns on the existing per-session metadata table (where Rename's
-- custom_title also lives): is_pinned + pinned_at (epoch ms, NULL when unpinned;
-- set only on the false->true transition so re-pinning keeps a stable slot).
-- The pinned-first ordering index aligns with get_user_sessions' ORDER BY.
-- Pre-release reuse of 3-up (no 4-up); mirrors the in-code DDL backstop in
-- pgsql/pgvector _ensure_session_metadata_schema.
ALTER TABLE conversation_logs_session_metadata ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;
ALTER TABLE conversation_logs_session_metadata ADD COLUMN IF NOT EXISTS pinned_at BIGINT;
CREATE INDEX IF NOT EXISTS idx_conversation_logs_session_metadata_user_pin
  ON conversation_logs_session_metadata (user_guid, tenant_id, is_pinned, pinned_at DESC);

-- Update the current schema version (earlier version is 1.1 i.e. 2).
-- SCHEMA_VERSION is a SINGLE-ROW "current version" table: the upgrade runner reads
-- it as a scalar (`SELECT VERSION FROM SCHEMA_VERSION` in postgres-helper.bash) and
-- 2-up.sql mutates it in place, so we UPDATE (not INSERT) to keep exactly one row —
-- a second row would break the scalar/numeric version comparison.
UPDATE SCHEMA_VERSION
SET version = 3,
    description = 'Persist rerun/variation grouping (rerun_root_conversation_id) - TESSA-181 + llm_usage_rollup - TESSA-182 + origin_flags provenance bitmask - TESSA-198 + pin/unpin session metadata (is_pinned, pinned_at) - TESSA-197 + synthesis_performed code-execution flag - TESSA-206';
