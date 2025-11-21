---------------------------------------------------
-- Database schema changes for 1.1.0
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.sh when adding a new n-up.sql file 
---------------------------------------------------------------------------

-- PCP-2269: Added index for DELETE queries in expired resources cleanup in three tables
CREATE INDEX IF NOT EXISTS OAUTH2_ACCESS_TOKENS_REFRESH_TOKEN_EXPIRATION_DATES_SECONDS_IDX ON OAUTH2_ACCESS_TOKENS(REFRESH_TOKEN_EXPIRATION_DATES_SECONDS);

CREATE INDEX IF NOT EXISTS OAUTH2_AUTH_EXPIRATION_DATES_SECONDS_IDX ON OAUTH2_AUTH_CODES(EXPIRATION_DATES_SECONDS);

CREATE INDEX IF NOT EXISTS OAUTH2_CLIENTS_LAST_ACCESSED_IDX ON OAUTH2_CLIENTS(LAST_ACCESSED);

-- Update database schema at the end (earlier version is 1.0.0 i.e. 1)

UPDATE SCHEMA_VERSION SET version = 2;