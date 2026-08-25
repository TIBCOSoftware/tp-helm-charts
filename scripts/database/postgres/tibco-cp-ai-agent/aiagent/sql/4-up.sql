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

-- Update the current schema version (earlier version is 1.2 i.e. 3).
-- SCHEMA_VERSION is a SINGLE-ROW "current version" table: the upgrade runner reads
-- it as a scalar (`SELECT VERSION FROM SCHEMA_VERSION` in postgres-helper.bash) and
-- mutates it in place, so we UPDATE (not INSERT) to keep exactly one row.
UPDATE SCHEMA_VERSION
SET version = 4,
    description = 'MCP server auth_type column for google_iap (TIBCO Knowledge in-agent MCP) - TESSA-374';
