---------------------------------------------------
-- AI Agent schema changes for version 1.20 (TESSA-374)
---------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------
-- NOTE: 3-up.sql (schema v3) is the 1.19 release (in QA / production-bound) and
-- is frozen. 1.20 changes go in this NEW 4-up.sql so the version bump (3 -> 4)
-- triggers the migration on upgrade of an existing v3 database.

-- TESSA-374: TIBCO Knowledge (in-agent MCP) uses a new MCP auth strategy,
-- google_iap (self-signed RS256 JWT). The auto-provisioner WRITES this per-server
-- auth strategy and the config loader READS it, so tenant_mcp_servers needs an
-- auth_type column. Additive, non-breaking; existing rows default to 'none'
-- (unchanged behavior). Mirrors the CREATE TABLE in the agent repo's
-- scripts/schema.sql (bootstrap/local path).
ALTER TABLE tenant_mcp_servers ADD COLUMN IF NOT EXISTS auth_type VARCHAR(20) DEFAULT 'none';

-- TESSA-610: one-time administrator notices. "This administrator has been told X
-- once", and nothing more. The only writer is POST /api/v1/settings/notices/{key},
-- and the key must be on a server-side allow-list, so this cannot become arbitrary
-- client-writable storage.
--
-- Scope is (tenant, user): the same admin on a second subscription is meeting that
-- subscription's configuration for the first time, and a second admin on an
-- already-configured subscription has never been told the model. Both must see the
-- notice, so neither axis can leave the key.
--
-- The FK cascade is load-bearing rather than tidy: TESSA-485 showed that deleting a
-- `tenants` row is how a subscription is re-onboarded, and an acknowledgement that
-- outlived its subscription would suppress the notice for the fresh one.
--
-- Mirrors the CREATE TABLE in the agent repo's scripts/schema.sql (bootstrap/local
-- path) and the in-code backstop in agent/services/user_notice_service.py.
--
-- APPENDED to 4-up.sql rather than shipped as a new 5-up.sql, per the standing
-- pre-release rule: the upgrade runner applies each ${N}-up.sql for N in
-- (db_version, CURRENT_VERSION], so a NEW file only matters once some database is
-- already AT version 4. Nothing is — 4-up.sql has not reached QA (the cp-scripts
-- image still predates it) — so every fresh and QA install picks this up from here,
-- and the version number stays at 4.
CREATE TABLE IF NOT EXISTS tenant_user_notices (
    tenant_id VARCHAR(100) NOT NULL,
    user_guid VARCHAR(128) NOT NULL,
    notice_key VARCHAR(64) NOT NULL,
    acknowledged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, user_guid, notice_key),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

-- Update the current schema version (earlier version is 1.2 i.e. 3).
-- SCHEMA_VERSION is a SINGLE-ROW "current version" table: the upgrade runner reads
-- it as a scalar (`SELECT VERSION FROM SCHEMA_VERSION` in postgres-helper.bash) and
-- mutates it in place, so we UPDATE (not INSERT) to keep exactly one row.
UPDATE SCHEMA_VERSION
SET version = 4,
    description = 'MCP server auth_type column (TESSA-374) + one-time admin notices table (TESSA-610)';
