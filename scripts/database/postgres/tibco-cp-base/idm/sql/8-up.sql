-- Copyright (c) 2023-2026. Cloud Software Group, Inc.
-- This file is subject to the license terms contained
-- in the license file that is distributed with this file.

---------------------------------------------------
-- Database schema changes for next release
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

-- PCP-18744: Track whether the INITIAL_ACCESS_TOKEN tied to this client has been revoked,
-- so the cleanup trigger short-circuits on subsequent access-token updates.
ALTER TABLE OAUTH2_CLIENTS
    ADD COLUMN IF NOT EXISTS INITIAL_ACCESS_TOKEN_REVOKED BOOLEAN NOT NULL DEFAULT FALSE;

-- PCP-18744: After the OAuth2 client's access token is used a 2nd time, the initial-access-token
-- row in INITIAL_ACCESS_TOKENS is no longer needed; delete it and mark the client as revoked
-- so the trigger short-circuits on subsequent LAST_ACCESSED updates.
-- NOTE: The 2nd-use rule applies to this forward trigger only. The one-time backfill below
-- uses a looser 1st-use rule to clean up rows orphaned BEFORE this migration deployed.
DROP FUNCTION IF EXISTS CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN() CASCADE;
CREATE FUNCTION CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN()
RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
DECLARE
    v_created_by VARCHAR(56);
    v_revoked BOOLEAN;
BEGIN
    SELECT CREATED_BY, INITIAL_ACCESS_TOKEN_REVOKED
      INTO v_created_by, v_revoked
      FROM OAUTH2_CLIENTS
     WHERE CLIENT_ID = NEW.CLIENT_ID;

    -- Defensive: access-token row is not tied to a known client (should not happen)
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Short-circuit: already revoked; nothing to do
    IF v_revoked THEN
        RETURN NEW;
    END IF;

    -- Safe even if 0 rows matched (clients can be created via non-IAT flows)
    DELETE FROM INITIAL_ACCESS_TOKENS WHERE ID = v_created_by;

    UPDATE OAUTH2_CLIENTS
       SET INITIAL_ACCESS_TOKEN_REVOKED = TRUE
     WHERE CLIENT_ID = NEW.CLIENT_ID;

    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN_TRIGGER ON OAUTH2_ACCESS_TOKENS;
CREATE TRIGGER CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN_TRIGGER
    AFTER UPDATE OF LAST_ACCESSED ON OAUTH2_ACCESS_TOKENS
    FOR EACH ROW
    WHEN (OLD.LAST_ACCESSED IS NOT NULL
          AND NEW.LAST_ACCESSED IS NOT NULL
          AND OLD.LAST_ACCESSED IS DISTINCT FROM NEW.LAST_ACCESSED)
    EXECUTE PROCEDURE CLEANUP_ORPHAN_INITIAL_ACCESS_TOKEN();

-- PCP-18744: One-time backfill for pre-existing orphaned INITIAL_ACCESS_TOKENS rows.
-- The forward trigger only fires on the 2nd LAST_ACCESSED update, so it cannot
-- clean up rows orphaned BEFORE this migration deployed. Conservative cleanup:
-- delete IAT rows whose client's access token has already been used at least once
-- (LAST_ACCESSED IS NOT NULL). IATs are only needed at registration time, so any
-- client past first-use is safe to clean up. Defensive: skip clients already
-- marked revoked (idempotent re-run).
DELETE FROM INITIAL_ACCESS_TOKENS iat
    USING OAUTH2_CLIENTS oc, OAUTH2_ACCESS_TOKENS oat
WHERE iat.ID = oc.CREATED_BY
  AND oat.CLIENT_ID = oc.CLIENT_ID
  AND oat.LAST_ACCESSED IS NOT NULL
  AND NOT oc.INITIAL_ACCESS_TOKEN_REVOKED;

UPDATE OAUTH2_CLIENTS oc
   SET INITIAL_ACCESS_TOKEN_REVOKED = TRUE
  FROM OAUTH2_ACCESS_TOKENS oat
 WHERE oat.CLIENT_ID = oc.CLIENT_ID
   AND oat.LAST_ACCESSED IS NOT NULL
   AND NOT oc.INITIAL_ACCESS_TOKEN_REVOKED;

-- PCP-21466: Relax IDP_DETAILS.HOST_PREFIX from VARCHAR(32) to VARCHAR(63) to match the UTD
-- side (V2_ACCOUNTS.HOST_PREFIX, relaxed in tscutd/sql/7-up.sql). A host prefix
-- accepted by UTD (up to 63 chars) was being rejected by IDM's 32-char cap, which
-- broke external-IdP configuration on insert/update into IDP_DETAILS. No IDM view
-- depends on IDP_DETAILS.HOST_PREFIX, so (unlike UTD) no view drop/recreate is
-- required. The validation regex mirrors UTD and is added NOT VALID so existing
-- rows are not re-validated.
ALTER TABLE IDP_DETAILS ALTER COLUMN HOST_PREFIX TYPE VARCHAR(63);
ALTER TABLE IDP_DETAILS DROP CONSTRAINT IF EXISTS host_prefix_valid_check;
ALTER TABLE IDP_DETAILS ADD CONSTRAINT host_prefix_valid_check
    CHECK (host_prefix ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$') NOT VALID;

-- Update database schema at the end (earlier version since 1.14.0 i.e. 7)
UPDATE SCHEMA_VERSION SET version = 8;
