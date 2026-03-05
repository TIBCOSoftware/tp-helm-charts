---------------------------------------------------------
-- Database (monitoringdb) schema for monitoring 1.15.0
---------------------------------------------------------

-- Update HOST_CLOUD_TYPE values in DATAPLANES table
UPDATE DATAPLANES SET HOST_CLOUD_TYPE='k8s' WHERE ACTIVE=true AND HOST_CLOUD_TYPE IN ('aws','azure','gcp');

-- UPGRADE VERSION
UPDATE SCHEMA_VERSION SET VERSION = 5;
