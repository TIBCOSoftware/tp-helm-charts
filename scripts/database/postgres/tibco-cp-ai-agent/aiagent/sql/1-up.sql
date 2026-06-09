-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- ============================================================================
-- TP AI Agent - Database Schema (Version 4)
-- ============================================================================
-- PRODUCTION SCHEMA - For fresh installations, this is the ONLY file you need
--
-- Multi-tenant configuration storage
-- Compatible with PostgreSQL (production) and SQLite (development)
--
-- Usage:
--   PostgreSQL: psql -h localhost -p 5433 -U user -d dbname -f schema.sql
--   SQLite:     sqlite3 data/config.db < schema.sql
--              OR python scripts/init_database.py
--
-- Note: Other schema_v*.sql files in this directory are legacy/migration files
--       from development. DO NOT run multiple schema files for fresh installs.
--
-- Validation strategy:
-- - Pydantic models (agent/models/tenant.py) = Primary validation
-- - Database constraints = Safety net for data integrity
-- ============================================================================

-- ============================================================================
-- TENANTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenants (
    tenant_id VARCHAR(100) PRIMARY KEY,
    display_name VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,

    -- Constraints (Pydantic does primary validation)
    CHECK (length(trim(tenant_id)) > 0),
    CHECK (length(trim(display_name)) > 0)
);

-- NOTE: No default tenant created - use Tenant CLI to import first tenant
-- Example: python agent/cli/tenant.py import default --config-file config.yaml

-- ============================================================================
-- BRANDING SETTINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_branding (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    app_name VARCHAR(255),
    app_title VARCHAR(255),
    app_description TEXT,
    about_text TEXT,
    logo_url TEXT,
    logo_size VARCHAR(20),           -- small, medium, large
    primary_color VARCHAR(7),        -- Hex color (e.g., #FF6B6B)
    secondary_color VARCHAR(7),
    sidebar_title VARCHAR(255),
    system_prompt_identity TEXT,
    cookie_name VARCHAR(100),
    favicon_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id)
);

-- ============================================================================
-- MCP SERVERS (SSE, HTTP, STDIO)
-- ============================================================================
-- NOTE: stdio transport allowed in schema but NOT SUPPORTED at runtime.
--       Agent will skip stdio servers with warning during connection.

CREATE TABLE IF NOT EXISTS tenant_mcp_servers (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    server_name VARCHAR(255) NOT NULL,

    -- Transport: sse, http, or stdio (stdio allowed but not supported at runtime)
    transport VARCHAR(10) NOT NULL,

    -- SSE/HTTP configuration
    url TEXT,                             -- Required for SSE/HTTP, NULL for stdio

    -- Authorization (optional)
    authorization_header TEXT,            -- Optional: Bearer token, etc.
    custom_headers TEXT,                  -- Optional: JSON object as text
    pass_atmosphere_token BOOLEAN DEFAULT FALSE,
    atmosphere_token_override TEXT,

    -- Status
    enabled BOOLEAN DEFAULT TRUE NOT NULL,
    readonly_mode BOOLEAN DEFAULT FALSE,   -- Read-only mode: only allow tools with readOnlyHint=true
    disabled_tools TEXT,                   -- JSON array of disabled tool names: ["tool1", "tool2"]

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, server_name),
    CHECK (length(trim(server_name)) > 0),
    CHECK (transport = 'stdio' OR (url IS NOT NULL AND length(trim(url)) > 0))
);

-- ============================================================================
-- LLM PROVIDERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_llm_providers (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,

    -- Provider configuration
    provider_name VARCHAR(255) NOT NULL,  -- User-friendly name (e.g., "azure-gpt5-mini")
    provider VARCHAR(50) NOT NULL,        -- openai, anthropic, openrouter, ollama, azure, azure_openai
    api_key TEXT,                         -- API key (plaintext or encrypted via service layer)
    api_version VARCHAR(50),              -- For Azure: API version (e.g., "2024-05-01-preview")
    azure_endpoint TEXT,                  -- For Azure: Endpoint URL
    azure_deployment TEXT,                -- For Azure: Deployment name
    base_url TEXT,                        -- Custom endpoints (for Ollama, OpenRouter, etc.)
    temperature DECIMAL(3,2) DEFAULT 0.7,
    is_default BOOLEAN DEFAULT FALSE,     -- Mark as default provider
    service_tier VARCHAR(20) DEFAULT NULL, -- OpenAI service tier: priority, default, auto (NULL = use feature flag)
    max_tokens INTEGER DEFAULT NULL,      -- Max output tokens per LLM call (NULL = use app default 2048)

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, provider_name),
    CHECK (provider IN ('openai', 'anthropic', 'openrouter', 'ollama', 'azure', 'azure_openai')),
    CHECK (temperature >= 0.0 AND temperature <= 2.0),
    CHECK (service_tier IS NULL OR service_tier IN ('priority', 'default', 'auto')),
    CHECK (max_tokens IS NULL OR max_tokens > 0)
);

-- ============================================================================
-- LLM PROVIDER MODELS (Multi-model support)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_llm_provider_models (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL,        -- Foreign key to tenant_llm_providers
    model VARCHAR(255) NOT NULL,
    temperature DECIMAL(3,2),            -- Optional temperature override
    max_tokens INTEGER DEFAULT NULL,     -- Per-model max output tokens override (NULL = use provider/app default)

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (provider_id) REFERENCES tenant_llm_providers(id) ON DELETE CASCADE,
    UNIQUE (provider_id, model),
    CHECK (temperature IS NULL OR (temperature >= 0.0 AND temperature <= 2.0)),
    CHECK (max_tokens IS NULL OR max_tokens > 0)
);

-- ============================================================================
-- NODE MODELS (Per-node LLM model mapping)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_node_models (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    node_name VARCHAR(50) NOT NULL,      -- validator, tool_filter, smart_response, response_guard, react_agent_executor
    model VARCHAR(255) NOT NULL,

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, node_name),
    CHECK (node_name IN ('validator', 'tool_filter', 'smart_response', 'response_guard', 'react_agent_executor'))
);

-- ============================================================================
-- PROMPTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_prompts (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    prompt_key VARCHAR(50) NOT NULL,      -- systemPrompt, validatorPrompt, toolFilterPrompt, responseGuardPrompt
    content TEXT NOT NULL,
    is_customized BOOLEAN DEFAULT TRUE,
    max_length INTEGER,                   -- Maximum prompt length (e.g., 25000)

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, prompt_key),
    CHECK (prompt_key IN ('systemPrompt', 'validatorPrompt', 'toolFilterPrompt', 'smartResponsePrompt', 'responseGuardPrompt')),
    CHECK (length(content) > 0 AND length(content) <= 25000)  -- 25k char limit
);

-- ============================================================================
-- APP SETTINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_config (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    config_key VARCHAR(100) NOT NULL,     -- appSettings, conversationSettings, mcpSettings
    config_value TEXT NOT NULL,           -- JSON as text
    config_version INTEGER DEFAULT 1,     -- Version for cache invalidation

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    UNIQUE (tenant_id, config_key)
);

-- ============================================================================
-- APPROVED MODELS - REMOVED (Not Used)
-- ============================================================================
-- The approved_models table was removed because:
-- - All models are loaded from llm_models_config.yaml (single source of truth)
-- - The /llm/approved-models API endpoint reads from YAML, not database
-- - Tenant admin selects models during onboarding (stored in tenant_llm_provider_models)
-- - Simpler architecture: YAML catalog → Runtime selection
--
-- If database-driven model governance is needed in the future, recreate this table.

-- ============================================================================
-- CHAT INTERACTIONS (Sessions and conversations)
-- ============================================================================

CREATE TABLE IF NOT EXISTS chat_interactions (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    session_id VARCHAR(100) NOT NULL,
    conversation_id VARCHAR(100) NOT NULL,

    -- Message content
    user_message TEXT NOT NULL,
    assistant_response TEXT NOT NULL,

    -- Execution metadata
    tools_called TEXT,                    -- JSON array as text
    servers_used TEXT,                    -- JSON array as text
    execution_time_ms INTEGER,

    -- Cost tracking
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    total_cost DECIMAL(10,6) DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

-- ============================================================================
-- CONVERSATION LOGS (Full conversation storage - pgsql mode)
-- ============================================================================
-- Used when CONVERSATION_STORAGE_MODE=pgsql
-- The adapter auto-creates these tables at runtime (IF NOT EXISTS),
-- but they are included here for documentation and fresh installs.
-- NOTE: This is separate from chat_interactions which is a simpler
-- tenant-config-level table. conversation_logs stores full conversation
-- data with 27 fields including cost tracking, tool metrics, and GDPR support.

CREATE TABLE IF NOT EXISTS conversation_logs (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR(64) UNIQUE NOT NULL,
    session_id VARCHAR(128) NOT NULL,
    user_guid VARCHAR(128) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL,
    timestamp BIGINT NOT NULL,
    question TEXT,
    answer_text TEXT,
    answer_full TEXT,
    table_data TEXT,
    csv_content TEXT,
    has_table BOOLEAN DEFAULT FALSE,
    servers_used VARCHAR(500),
    tools_called VARCHAR(500),
    feedback VARCHAR(20) DEFAULT 'none',
    feedback_text VARCHAR(200) DEFAULT '',
    node_execution_times TEXT,
    total_execution_time_ms BIGINT,
    llm_model_used VARCHAR(64),
    total_cost_usd FLOAT,
    input_tokens BIGINT,
    output_tokens BIGINT,
    trace_url VARCHAR(500),
    tools_failed_count INTEGER,
    tool_failure_rate FLOAT,
    failed_tool_names VARCHAR(500),
    tool_execution_details TEXT,
    content_blocked INTEGER DEFAULT 0,
    deleted_at BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS conversation_logs_session_metadata (
    session_id VARCHAR(128) PRIMARY KEY,
    tenant_id VARCHAR(64) NOT NULL,
    user_guid VARCHAR(128) NOT NULL,
    custom_title VARCHAR(200),
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

-- ============================================================================
-- SCHEMA VERSION TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Set current schema version (only if not already set)
-- NOTE: Keep at 1 until production upgrade is needed. Update only when explicitly requested.
-- Using INSERT with subquery check to avoid duplicates (works in both SQLite and PostgreSQL)
INSERT INTO schema_version (version, description)
SELECT 1, 'Initial multi-tenant schema'
WHERE NOT EXISTS (SELECT 1 FROM schema_version WHERE version = 1);

-- ============================================================================
-- INDEXES (Performance optimization)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_tenants_active ON tenants(is_active);
CREATE INDEX IF NOT EXISTS idx_tenant_mcp_servers_tenant ON tenant_mcp_servers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_mcp_servers_enabled ON tenant_mcp_servers(tenant_id, enabled);
CREATE INDEX IF NOT EXISTS idx_llm_providers_tenant ON tenant_llm_providers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_prompts_tenant ON tenant_prompts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_chat_interactions_tenant ON chat_interactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_chat_interactions_session ON chat_interactions(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_interactions_conversation ON chat_interactions(conversation_id);

-- Conversation logs indexes (pgsql mode)
CREATE INDEX IF NOT EXISTS idx_conv_session_tenant ON conversation_logs(session_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_conv_user_tenant ON conversation_logs(user_guid, tenant_id);
CREATE INDEX IF NOT EXISTS idx_conv_timestamp ON conversation_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_conv_conversation_id ON conversation_logs(conversation_id);
CREATE INDEX IF NOT EXISTS idx_session_meta_user_tenant ON conversation_logs_session_metadata(user_guid, tenant_id);

-- ============================================================================
-- IDEMPOTENT MIGRATIONS (for upgrades on existing databases)
-- ============================================================================
-- These ALTER statements ensure schema changes apply to existing databases
-- during Helm chart upgrades. They are no-ops on fresh installs.
-- Add new ALTER TABLE statements here as schema evolves during development.

-- Add max_tokens to tenant_llm_providers (added in development)
ALTER TABLE tenant_llm_providers
    ADD COLUMN IF NOT EXISTS max_tokens INTEGER DEFAULT NULL;

-- Add max_tokens to tenant_llm_provider_models (added in development)
ALTER TABLE tenant_llm_provider_models
    ADD COLUMN IF NOT EXISTS max_tokens INTEGER DEFAULT NULL;

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- Syntax compatibility:
-- - SERIAL PRIMARY KEY: Works in both SQLite and PostgreSQL
-- - VARCHAR(n), TEXT: Compatible
-- - BOOLEAN: PostgreSQL native, SQLite stores as 0/1
-- - DECIMAL: Both support
-- - CHECK constraints: Both support (complex regex only in PostgreSQL)
-- - FOREIGN KEY: Both support
-- - TIMESTAMP DEFAULT CURRENT_TIMESTAMP: Compatible
--
-- Validation strategy:
-- - Pydantic models perform primary validation (regex patterns, complex rules)
-- - Database constraints provide safety net (NOT NULL, CHECK, UNIQUE, FK)
-- - This allows one schema to work for both databases
--
-- Transport types:
-- - SSE and HTTP ONLY: No stdio support (removed for simplicity)
-- - MCP servers use SSE or HTTP transport with URL-based connection
--
-- ============================================================================
