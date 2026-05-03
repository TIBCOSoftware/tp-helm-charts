-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 4;

DROP TABLE IF EXISTS TCTA_RETENTION_PERIOD;
DROP TABLE IF EXISTS TCTA_PAYLOAD_CONTROL;
DROP TABLE IF EXISTS TCTA_ENCRYPTION_KEY;
