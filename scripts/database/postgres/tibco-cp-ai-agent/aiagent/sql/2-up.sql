---------------------------------------------------
-- AI Agent schema changes for version 1.1 (Ph1.1)
---------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------

-- Add image/chart persistence columns to conversation_logs
ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS image_data TEXT;
ALTER TABLE conversation_logs ADD COLUMN IF NOT EXISTS has_image BOOLEAN DEFAULT FALSE;

-- Update database schema version (earlier version is 1.0.0 i.e. 1)
UPDATE SCHEMA_VERSION SET version = 2;
