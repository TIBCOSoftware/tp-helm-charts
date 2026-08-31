-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------
-- Database schema changes for 1.20
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

-- PCP-21466 (1.20): limit SESSION_INDEX to 255 to reasonably accommodate the session index,
-- which is not capped in specs; we also append the host prefix (up to 63 characters).
ALTER TABLE OAUTH2_ACCESS_TOKENS ALTER COLUMN SESSION_INDEX TYPE VARCHAR(255);

-- Update database schema at the end (earlier version is 8)
UPDATE SCHEMA_VERSION SET version = 9;
