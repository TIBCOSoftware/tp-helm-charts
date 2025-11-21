---------------------------------------------------
-- Database schema changes for 1.2.0
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.sh when adding a new n-up.sql file 
---------------------------------------------------------------------------

-- PCP-4471: Increase session size in DB to 96 bytes
ALTER TABLE OAUTH2_ACCESS_TOKENS
    ALTER COLUMN SESSION_INDEX TYPE VARCHAR(96);


-- a keystore is unlocked using the password under the given alias. 
CREATE TABLE IF NOT EXISTS KEYSTORES (
    ALIAS UUID PRIMARY KEY,
    DATA BYTEA,
    ENCRYPTED_PWD BYTEA,
    EXPIRY TIMESTAMP WITH TIME ZONE
);
-- alter column EXPIRY to TIMESTAMP (without TIME ZONE)
ALTER TABLE KEYSTORES 
    ALTER COLUMN EXPIRY TYPE TIMESTAMP;

-- Update database schema at the end (earlier version is 1.1.0 i.e. 2)

UPDATE SCHEMA_VERSION SET version = 3;
