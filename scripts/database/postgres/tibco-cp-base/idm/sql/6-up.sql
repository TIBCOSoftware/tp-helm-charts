---------------------------------------------------
-- Database schema changes for 1.9.0
---------------------------------------------------

---------------------------------------------------------------------------
-- REMEMBER to update the metadata.bash when adding a new n-up.sql file
---------------------------------------------------------------------------

-- PCP-8080: Support for customer-provided keystore for the SP
-- Consuming both the cpGeneratedCert and the customer-provided certs as an array under ServiceProviderCerts
-- The cpGeneratedCert will have an additional 'active' attribute set to true. Skipping the 'cert' field from cpGeneratedCert.

UPDATE idp_details
SET metadata = (
    jsonb_set(
            metadata::jsonb,
            '{metadata,serviceProviderCerts}',
            jsonb_build_array(
                -- Start with the original cpGeneratedCert, but without 'cert'
                (metadata->'metadata'->'serviceProviderCerts'->'cpGeneratedCert')::jsonb - 'cert'
                    -- Add the 'active' attribute
                    || jsonb_build_object('active', true)
            )
        )
    )::json
WHERE
    jsonb_typeof(metadata::jsonb->'metadata'->'serviceProviderCerts') = 'object'
  AND (metadata::jsonb->'metadata'->'serviceProviderCerts' ? 'cpGeneratedCert');

-- Update database schema at the end (earlier version is 1.8.0 i.e. 5)
UPDATE SCHEMA_VERSION SET version = 6;
