-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 2;

-- delete property (only if it exists)
DELETE FROM TCTA_PROPERTY WHERE prop_key='tcta.dataserver.limit.query.event';