-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 3;

DROP TABLE IF EXISTS TCTA_COLUMN_CONFIGURATION;
DROP TABLE IF EXISTS TCTA_SUB_EMAIL;
DROP TABLE IF EXISTS TCTA_QUERY_HISTORY;

ALTER TABLE IF EXISTS TCTA_STATUS
DROP COLUMN IF EXISTS is_error,
DROP COLUMN IF EXISTS is_complete,
DROP COLUMN IF EXISTS need_notify,
DROP COLUMN IF EXISTS email,
DROP COLUMN IF EXISTS color;
