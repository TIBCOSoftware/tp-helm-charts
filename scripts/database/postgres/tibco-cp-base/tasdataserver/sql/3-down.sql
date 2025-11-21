-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 2;

-- delete property (only if it exists)
DELETE FROM TCTA_PROPERTY WHERE prop_key='tcta.dataserver.limit.query.event';