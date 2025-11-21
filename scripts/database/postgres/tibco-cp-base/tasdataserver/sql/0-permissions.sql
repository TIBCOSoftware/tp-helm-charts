-- =====================================================
-- Database User Permissions Setup for TIBCO Audit Safe
-- This script should be run BEFORE the migration scripts
-- =====================================================

-- Ensure the user exists (if not created elsewhere)
-- CREATE USER tctadataserveruser WITH PASSWORD 'postgres';

-- Grant database-level privileges
GRANT CONNECT ON DATABASE tctadataserver TO tctadataserveruser;
GRANT CREATE ON DATABASE tctadataserver TO tctadataserveruser;
GRANT TEMPORARY ON DATABASE tctadataserver TO tctadataserveruser;

-- Grant schema-level privileges
GRANT USAGE ON SCHEMA tctadataserver TO tctadataserveruser;
GRANT CREATE ON SCHEMA tctadataserver TO tctadataserveruser;
GRANT ALL PRIVILEGES ON SCHEMA tctadataserver TO tctadataserveruser;

-- Grant privileges on all existing tables in the schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA tctadataserver TO tctadataserveruser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA tctadataserver TO tctadataserveruser;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA tctadataserver TO tctadataserveruser;

-- Grant privileges on future tables (important for new tables)
ALTER DEFAULT PRIVILEGES IN SCHEMA tctadataserver GRANT ALL ON TABLES TO tctadataserveruser;
ALTER DEFAULT PRIVILEGES IN SCHEMA tctadataserver GRANT ALL ON SEQUENCES TO tctadataserveruser;
ALTER DEFAULT PRIVILEGES IN SCHEMA tctadataserver GRANT ALL ON FUNCTIONS TO tctadataserveruser;

-- Allow the user to create extensions (needed for uuid-ossp in 1-up.sql)
-- Note: This might require superuser privileges, so it should be done by postgres user
-- ALTER USER tctadataserveruser CREATEDB;

-- Grant specific privileges for the TAS_INIT_LOCK table (application locking mechanism)
-- This ensures the application can create/drop the temporary locking table
GRANT CREATE ON SCHEMA public TO tctadataserveruser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tctadataserveruser;

-- Ensure user can create temporary tables for distributed locking
GRANT TEMP ON DATABASE tctadataserver TO tctadataserveruser;

-- Set default transaction mode to read-write for this user
ALTER USER tctadataserveruser SET default_transaction_read_only = off;

-- Optional: Set connection limits
-- ALTER USER tctadataserveruser CONNECTION LIMIT 50;

COMMIT;
