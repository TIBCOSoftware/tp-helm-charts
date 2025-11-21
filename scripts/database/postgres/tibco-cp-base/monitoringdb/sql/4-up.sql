---------------------------------------------------------
-- Database (monitoringdb) schema for finops 1.3.0-HF3
---------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_capability_instances_dataplane_id ON CAPABILITY_INSTANCES(dataplane_id);
CREATE INDEX IF NOT EXISTS idx_capability_instances_active ON CAPABILITY_INSTANCES(active);

-- UPGRADE VERSION
UPDATE SCHEMA_VERSION SET VERSION = 4;
