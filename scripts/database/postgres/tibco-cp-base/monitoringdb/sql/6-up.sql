-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- Database schema changes for 1.15.0

ALTER TABLE DATAPLANES ADD COLUMN IF NOT EXISTS HAS_TIBTUNNEL BOOLEAN DEFAULT TRUE;

-- UPGRADE VERSION
UPDATE SCHEMA_VERSION SET VERSION = 6;