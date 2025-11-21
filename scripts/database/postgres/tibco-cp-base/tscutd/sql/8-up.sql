-- Database schema changes for 1.5.1

-- PCP-10584: [CP Backend] Add a constraint at CP UTD DB side to allow only one default repo to be added/updated
DROP function if EXISTS v3_enforce_single_default_helm_repo_instance() CASCADE;

CREATE OR REPLACE FUNCTION v3_enforce_single_default_helm_repo_instance()
RETURNS TRIGGER AS $$
BEGIN
    -- Apply enforcement only if resource_id is 'HELMREPO'
    IF NEW.resource_id = 'HELMREPO' THEN
        -- Check if another row already has default = TRUE in JSONB column for the same scope_id
        IF NEW.resource_instance_metadata @> '{"default": true}' THEN
            IF EXISTS (
                SELECT 1 FROM v3_resource_instances 
                WHERE resource_instance_metadata @> '{"default": true}' 
                AND scope_id = NEW.scope_id 
                AND resource_instance_id <> NEW.resource_instance_id
            ) THEN
                RAISE EXCEPTION 'Only one helm repo can have "default" set to true for the same scope_id';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS v3_check_single_default_helm_repo_instance_trigger on V3_RESOURCE_INSTANCES;

CREATE TRIGGER v3_check_single_default_helm_repo_instance_trigger
BEFORE INSERT OR UPDATE ON V3_RESOURCE_INSTANCES
FOR EACH ROW
EXECUTE FUNCTION v3_enforce_single_default_helm_repo_instance();

-- Update database schema at the end (earlier version is 1.5.0 i.e. 7)
UPDATE schema_version SET version = 8;
