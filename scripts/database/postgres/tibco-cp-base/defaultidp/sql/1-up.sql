---------------------------------------------------
-- Database schema changes for 1.2.0
---------------------------------------------------
------------------------------------------------------------------------
-- REMEMBER to update the metadata.sh when adding a new n-up.sql file 
------------------------------------------------------------------------
------------------------------------------------------------------------
--  TABLE NAME: DATA
------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS DATA (
      KEY VARCHAR(64) PRIMARY KEY,
      VALUE TEXT NOT NULL,
      EXPIRY TIMESTAMP
);

------------------------------------------------------------------------
--  TABLE NAME: ARCHIVED_DATA
------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ARCHIVED_DATA (
    KEY VARCHAR(64) PRIMARY KEY,
    VALUE TEXT,
    EXPIRY TIMESTAMP
);

------------------------------------------------------------------------
--  TABLE NAME: SCHEMA_VERSION
------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SCHEMA_VERSION (
      ID SERIAL PRIMARY KEY,
      VERSION INTEGER NOT NULL,

      CONSTRAINT SCHEMA_VERSION_UNIQUE_CONSTRAINT UNIQUE (VERSION)
);

-- Trigger to move the record to archived_data before deletion
CREATE OR REPLACE FUNCTION ARCHIVE_DATA()
RETURNS TRIGGER 
	LANGUAGE plpgsql 
	AS $$
BEGIN
    -- Copy the record to archived_data if the expiry is NULL since these are users and SPs worth preserving
    IF OLD.expiry IS NULL THEN
        INSERT INTO ARCHIVED_DATA VALUES (OLD.key, OLD.value, OLD.expiry);
    END IF;

    -- Continue with the deletion
    RETURN OLD;
END;
$$;

-- DROP if trigger already exists
DROP TRIGGER IF EXISTS ARCHIVE_DATA_TRIGGER ON DATA;

-- Create the trigger on the data table
CREATE TRIGGER ARCHIVE_DATA_TRIGGER
BEFORE DELETE ON DATA
FOR EACH ROW EXECUTE FUNCTION ARCHIVE_DATA();

INSERT INTO SCHEMA_VERSION (VERSION) VALUES (1) ON CONFLICT DO NOTHING;

