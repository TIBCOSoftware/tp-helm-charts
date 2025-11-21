-- update schema_version table
UPDATE SCHEMA_VERSION SET VERSION = 3;

-- insert init data
-- initialized data for TCTA_PROPERTY
INSERT INTO TCTA_PROPERTY VALUES ('tcta.dataserver.limit.query.event', 'integer',
                                'Query Limit',
                                'Maximum number of querying events',
                                '1000', false) ON CONFLICT DO NOTHING;