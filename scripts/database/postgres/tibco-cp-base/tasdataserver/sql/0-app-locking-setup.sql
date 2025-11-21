-- =====================================================
-- Application Locking Mechanism Setup
-- This script sets up proper support for the TAS_INIT_LOCK table
-- used by the application for distributed initialization locking
-- =====================================================

-- Create a dedicated schema for application locking if needed
-- This separates locking tables from main application data
CREATE SCHEMA IF NOT EXISTS tas_locks;

-- Grant full privileges on the locking schema to the application user
GRANT ALL PRIVILEGES ON SCHEMA tas_locks TO tctadataserveruser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA tas_locks TO tctadataserveruser;
ALTER DEFAULT PRIVILEGES IN SCHEMA tas_locks GRANT ALL ON TABLES TO tctadataserveruser;

-- Ensure the application user can create tables in the main schema
-- (This is where the application currently tries to create TAS_INIT_LOCK)
GRANT CREATE ON SCHEMA tctadataserver TO tctadataserveruser;

-- Alternative: Pre-create the locking table structure to avoid CREATE TABLE at runtime
-- This approach eliminates the need for CREATE privileges during application startup
/*
CREATE TABLE IF NOT EXISTS tctadataserver.TAS_INIT_LOCK (
    DUMMY CHAR(1),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INSTANCE_ID VARCHAR(255) DEFAULT 'unknown'
);

-- Grant specific privileges on the pre-created locking table
GRANT ALL PRIVILEGES ON TABLE tctadataserver.TAS_INIT_LOCK TO tctadataserveruser;

-- Create an index for better performance
CREATE INDEX IF NOT EXISTS idx_tas_init_lock_created ON tctadataserver.TAS_INIT_LOCK(CREATED_AT);
*/

-- Ensure proper transaction isolation for locking operations
-- This prevents read-only transaction issues
ALTER USER tctadataserveruser SET default_transaction_isolation = 'read committed';
ALTER USER tctadataserveruser SET default_transaction_read_only = off;

-- Grant temporary table privileges (alternative locking approach)
GRANT TEMP ON DATABASE tctadataserver TO tctadataserveruser;

COMMIT;
