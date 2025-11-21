-- Database schema changes for 1.12.0

-- PCP-14440: Update FLOGO Capability's diplay_name from TIBCO Flogo® Enterprise to TIBCO Flogo®
UPDATE V3_CAPABILITY_METADATA VCM SET DISPLAY_NAME = 'TIBCO Flogo®' WHERE VCM.CAPABILITY_ID = 'FLOGO';

-- Update database schema at the end (earlier version is 1.11.0 i.e. 14)
UPDATE schema_version SET version = 15;
