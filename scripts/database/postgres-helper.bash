#!/bin/bash

################################################################################
# PostgreSQL Database Management Script
# 
# This script manages PostgreSQL databases for TIBCO Platform deployments.
# It handles database creation, schema upgrades, user management, and cleanup.
#
# Usage:
#   ./postgres-helper.bash upgrade  - Create/upgrade databases and schemas
#   ./postgres-helper.bash delete   - Delete databases and users
#   ./postgres-helper.bash check-schema-version <service> - Check schema version
#
# For detailed documentation, see README.md
################################################################################

set -e

################################################################################
# Configuration
################################################################################

# Kubernetes access mode
NO_KUBECTL_ACCESS=${NO_KUBECTL_ACCESS:-false}
KUBECTL_COMMANDS_FILE=${KUBECTL_COMMANDS_FILE:-"./kubectl-create-secret-commands.sh"}

# Service filtering
SKIP_SERVICES=${SKIP_SERVICES:-""}

# PostgreSQL client settings
export PGCLIENTENCODING="UTF8"
export PAGER=""

################################################################################
# Utility Functions
################################################################################

# Generate a random password using openssl
get-random-password() {
  local _password=$(openssl rand -base64 24)
  echo ${_password}
}

################################################################################
# Schema Version Checking
################################################################################

# Check if database schema version matches expected version
# Used by init containers to verify database readiness
check-schema-version() {
  local service_name=${1:-""}
  local host=${2:-"${PGHOST}"}
  local port=${3:-"${PGPORT}"}

  if [ -z "${service_name}" ]; then
    echo "ERROR: Service name is required"
    echo "Usage: check-schema-version <service_name> [host] [port]"
    if [[ "${PSQL_SCRIPTS_LOCATION}" == *"tibco-cp-hawk"* ]]; then
      echo "Available services: rtmon"
    else
      echo "Available services: idm, tasdataserver, tscorch, pengine, rtmon, monitoringdb, defaultidp, tasdomainserver, tscscheduler, tscutd"
    fi
    return 1
  fi

  # Validate DB_PREFIX requirement
  if [ -z "${DB_PREFIX}" ]; then
    echo "ERROR: DB_PREFIX is required"
    echo "Set DB_PREFIX to the controlPlaneInstanceId value with underscore suffix (global.tibco.controlPlaneInstanceId from tibco-cp-chart)"
    echo "Example: if controlPlaneInstanceId is 'cp1', then export DB_PREFIX=\"cp1_\""
    return 1
  fi

  # Use PSQL_SCRIPTS_LOCATION if set, otherwise try to find postgres directory
  local metadata_file=""
  if [ -n "${PSQL_SCRIPTS_LOCATION}" ]; then
    metadata_file="${PSQL_SCRIPTS_LOCATION}/${service_name}/scripts/metadata.bash"
  else
    # Try common locations for the postgres directory
    local script_dir="$(dirname "${BASH_SOURCE[0]}")"
    if [ -d "${script_dir}/postgres/tibco-cp-base" ]; then
      metadata_file="${script_dir}/postgres/tibco-cp-base/${service_name}/scripts/metadata.bash"
    elif [ -d "/opt/tibco/tsc/scripts/postgres/tibco-cp-base" ]; then
      metadata_file="/opt/tibco/tsc/scripts/postgres/tibco-cp-base/${service_name}/scripts/metadata.bash"
    else
      echo "ERROR: Cannot locate postgres scripts directory. Set PSQL_SCRIPTS_LOCATION environment variable."
      return 1
    fi
  fi

  if [ ! -f "${metadata_file}" ]; then
    echo "ERROR: Metadata file not found: ${metadata_file}"
    if [[ "${PSQL_SCRIPTS_LOCATION}" == *"tibco-cp-hawk"* ]]; then
      echo "Available services: rtmon"
    else
      echo "Available services: idm, tasdataserver, tscorch, pengine, rtmon, monitoringdb, defaultidp, tasdomainserver, tscscheduler, tscutd"
    fi
    return 1
  fi

  # Source the metadata file to get PGDATABASE, PGUSER, and CURRENT_VERSION
  source "${metadata_file}"

  if [ -z "${PGDATABASE}" ] || [ -z "${PGUSER}" ] || [ -z "${CURRENT_VERSION}" ]; then
    echo "ERROR: Missing required variables in metadata file: ${metadata_file}"
    echo "Required: PGDATABASE, PGUSER, CURRENT_VERSION"
    return 1
  fi
  
  if [ -z "${host}" ] || [ -z "${port}" ]; then
    echo "ERROR: Missing required database connection parameters"
    echo "Required environment variables: PGHOST, PGPORT, PGPASSWORD"
    return 1
  fi

  echo "Checking schema version for service: ${service_name}"
  echo "Database: ${PGDATABASE}"
  echo "User: ${PGUSER}"
  echo "Expected version: ${CURRENT_VERSION}"

  local max_attempts=60
  local attempt=1

  while [ ${attempt} -le ${max_attempts} ]; do
    echo "Attempt ${attempt}/${max_attempts}: Checking schema version..."

    # Get current schema version with detailed error capture
    local psql_output
    local psql_exit_code
    set +e  # Temporarily disable exit on error for psql command
    local schema_name=${PGSCHEMA:-${PGDATABASE}}
    psql_output=$(psql -h "${host}" -p "${port}" -U "${PGUSER}" -d "${PGDATABASE}" -t -c "SELECT VERSION FROM ${schema_name}.SCHEMA_VERSION;" 2>&1)
    psql_exit_code=$?
    set -e  # Re-enable exit on error

    if [ ${psql_exit_code} -eq 0 ]; then
      local current_version=$(echo "${psql_output}" | tr -d ' \t\n\r')
      if [ "${current_version}" = "${CURRENT_VERSION}" ]; then
        echo "✓ Schema version check passed: ${current_version}"
        return 0
      else
        echo "Schema version mismatch - Current: '${current_version}', Expected: '${CURRENT_VERSION}'"
      fi
    else
      # Parse common error types for better logging
      if echo "${psql_output}" | grep -q "could not connect to server"; then
        echo "Database connection failed - server may not be ready"
      elif echo "${psql_output}" | grep -q "database.*does not exist"; then
        echo "Database '${PGDATABASE}' does not exist"
      elif echo "${psql_output}" | grep -q "relation.*does not exist"; then
        echo "SCHEMA_VERSION table does not exist - schema may not be initialized (Expected: '${CURRENT_VERSION}')"
      elif echo "${psql_output}" | grep -q "authentication failed"; then
        echo "Authentication failed for user '${PGUSER}'"
      else
        echo "Query failed: ${psql_output}"
      fi
    fi

    echo "Waiting 3 seconds before retry..."
    sleep 3
    attempt=$((attempt + 1))
  done

  echo "ERROR: Schema version check failed after ${max_attempts} attempts"
  echo "Current version: ${current_version:-"unknown"}, expected: ${CURRENT_VERSION}"
  return 1
}

################################################################################
# Kubernetes Secret Management
################################################################################

# Generate kubectl command for secret creation
# Creates file with header on first call, appends on subsequent calls
generate-kubectl-command() {
  local service_name=$1
  local password=$2
  
  # Only generate command if KUBECTL_COMMANDS_FILE is set
  if [ -n "${KUBECTL_COMMANDS_FILE}" ]; then
    # Initialize file with header if it doesn't exist
    if [ ! -f "${KUBECTL_COMMANDS_FILE}" ]; then
      cat > "${KUBECTL_COMMANDS_FILE}" << EOF
#!/bin/bash
# Kubernetes secret creation commands
# Generated by postgres-helper.bash
# 
# Instructions:
# 1. Review the commands below
# 2. Run this script in your Kubernetes environment
# 3. Verify the secrets are created successfully

# Set the target namespace
$(if [ -n "${POD_NAMESPACE}" ]; then echo "export NAMESPACE=\"${POD_NAMESPACE}\""; else echo "# export NAMESPACE=\"your-namespace-here\"  # Uncomment and set your target namespace"; fi)

EOF
      chmod +x "${KUBECTL_COMMANDS_FILE}"
    fi
    
    # Append command to file
    cat >> "${KUBECTL_COMMANDS_FILE}" << EOF
# Service: ${service_name}
kubectl create secret generic ${service_name}-postgres-credential \\
  --from-literal=PGPASSWORD='${password}' \\
  --namespace=\${NAMESPACE}

EOF
  fi
}


################################################################################
# Credential Management
################################################################################

# Export master database credentials from files or environment
export-master-credentials() {
  # Use environment variables if secret-volume files don't exist
  if [ -f "$VOLUME_LOCATION/secret-volume/USERNAME" ]; then
    export MASTER_PGUSER=`cat $VOLUME_LOCATION/secret-volume/USERNAME`
  else
    echo "...Using master user from environment: ${MASTER_PGUSER}"
    # Ensure MASTER_PGUSER is set from environment
    if [ -z "${MASTER_PGUSER}" ]; then
      echo "ERROR: MASTER_PGUSER environment variable is not set and no username file found"
      return 1
    fi
  fi
  
  if [ -f "$VOLUME_LOCATION/secret-volume/PASSWORD" ]; then
    MASTER_PGPASSWORD=`cat $VOLUME_LOCATION/secret-volume/PASSWORD`
  else
    echo "...Using master password from environment: [REDACTED]"
    # Ensure MASTER_PGPASSWORD is set from environment
    if [ -z "${MASTER_PGPASSWORD}" ]; then
      echo "ERROR: MASTER_PGPASSWORD environment variable is not set and no password file found"
      return 1
    fi
  fi
  
  export PGPASSWORD=${MASTER_PGPASSWORD}
}

################################################################################
# Database User Management
################################################################################

# Check if a database user already exists
verifyExistingUser() {
    local __exit_code=0

    psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" \
        -c "SELECT 1 FROM pg_roles WHERE rolname='${PGUSER}'" | \
        grep -q 1 || export __exit_code=1

    return ${__exit_code}
}


createUpdateUserKubernetesSecret() {
    # Use the service password passed as parameter, but don't overwrite PGPASSWORD
    local service_password="${1}"
    
    # If NO_KUBECTL_ACCESS is true, generate kubectl commands instead of applying them
    if [ "${NO_KUBECTL_ACCESS}" = "true" ]; then
        echo "...Generating kubectl commands (NO_KUBECTL_ACCESS=true)"
        echo "...Commands will be saved to: ${KUBECTL_COMMANDS_FILE}"
        generate-kubectl-command "${SERVICE_NAME}" "${service_password}"
        return 0
    fi
    
    # Use a variable for the secret YAML content to debug more easily
    secret_yaml=$(cat <<EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: ${SERVICE_NAME}-postgres-credential
  namespace: ${POD_NAMESPACE}
data:
  PGPASSWORD: $(echo -n "${service_password}" | base64 -w0)
EOF
)

    echo "${secret_yaml}" | kubectl apply -f -
    __exit_code=$?
    
    if [ ${__exit_code} -ne 0 ]; then
        echo "******* ERROR: Failed to create/update kubernetes secret ${SERVICE_NAME}-postgres-credential for user '${PGUSER}'. Exit code: ${__exit_code}"
    else
        echo "...Successfully created/updated Kubernetes secret ${SERVICE_NAME}-postgres-credential with new user '${PGUSER}' password"
    fi
    
    return ${__exit_code}
}

################################################################################
# Database Schema Management
################################################################################

# Create initial database tables from 1-up.sql script
createTables() {
    local __exit_code=0
    DDLFILE=$( ls -1v ${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/1-up.sql 2>/dev/null | xargs -n 1 basename )
    
    if [ -z "${DDLFILE}" ]; then
        echo "...No 1-up.sql file found for service '${SERVICE_NAME}', skipping table creation"
        return 0
    fi
    
    echo "...Found DDL file: ${DDLFILE}"
    echo "...Executing SQL script: ${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/${DDLFILE}"
    
    if [ -f ${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/${DDLFILE} ]; then
        # Create a temporary file that combines SET ROLE with the SQL script
        TEMP_SQL_FILE=$(mktemp)
        local schema_name=${PGSCHEMA:-${PGDATABASE}}
        echo "SET ROLE ${PGUSER};" > "${TEMP_SQL_FILE}"
        echo "SET search_path TO ${schema_name};" >> "${TEMP_SQL_FILE}"
        cat "${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/${DDLFILE}" >> "${TEMP_SQL_FILE}"
        
        # Execute using master credentials with SET ROLE to service user
        psql --set=AWS_REGION=${AWS_REGION} --set=IAAS_VENDOR=${IAAS_VENDOR} --set=AUTHUSER=${PGUSER} -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -f "${TEMP_SQL_FILE}" -v ON_ERROR_STOP=1
        __exit_code=$?
        
        # Clean up temporary file
        rm -f "${TEMP_SQL_FILE}"
        
        if [ ${__exit_code} -eq 0 ]; then
            echo "...Successfully executed ${DDLFILE} for service '${SERVICE_NAME}'"
        else
            echo "******* ERROR: Failed to create tables by executing DDL statements from '${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/${DDLFILE}'. Exit code: ${__exit_code}"
        fi
    else
        echo "******* ERROR: Table creation script is missing at ${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/${DDLFILE}"
        return 1
    fi

    return ${__exit_code}
}

# Create or update database user with generated password
createDatabaseSchemaUser() {
    local __exit_code=0

    # Check if user already exists
    verifyExistingUser
    user_exists=$?
    
    if [ ${user_exists} -eq 0 ]; then
        echo "...User '${PGUSER}' already exists, skipping password generation"
        # User exists, skip password generation and creation
        __exit_code=0
    else
        # Generate password for the service user only when creating new user
        if [ -z ${GENERATE_PASSWORD} ]; then
            export DB_USER_PWD=`get-random-password`
            echo "...Generated random password for user => ${PGUSER}"
        else
            export DB_USER_PWD="postgres"
            echo "...Using default password for user => ${PGUSER}"
        fi
        
        echo "...Creating new user '${PGUSER}'"
        # Create the user, database, and schema
        PGPASSWORD=${MASTER_PGPASSWORD} psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" \
            -c "CREATE USER \"${PGUSER}\" WITH PASSWORD '${DB_USER_PWD}' ROLE \"`echo ${MASTER_PGUSER}|cut -d@ -f1`\"" 2>/dev/null
        __exit_code=$?
        if [ ${__exit_code} -eq 0 ]; then
            echo "...Successfully created user '${PGUSER}'"
            # Create/update Kubernetes secret after successful user creation
            createUpdateUserKubernetesSecret "${DB_USER_PWD}" || __exit_code=$?
        else
            echo "******* ERROR: Failed to create user '${PGUSER}' with role '${MASTER_PGUSER}'. Exit code: ${__exit_code}" 
        fi
    fi
    if [ ${__exit_code} -eq 0 ]; then
        # Define the schema name to be used, defaulting to the database name if PGSCHEMA is not set
        local schema_name=${PGSCHEMA:-${PGDATABASE}}

        # Check if database already exists
        db_exists=$(psql -t -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "SELECT 1 FROM pg_database WHERE datname='${PGDATABASE}'" 2>/dev/null | sed -e 's/[  ]*//g')
        
        if [ "$db_exists" = "1" ]; then
            echo "...Database '${PGDATABASE}' already exists, skipping creation"
            __exit_code=0
        else
            echo "...Creating database '${PGDATABASE}'"
            psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "CREATE DATABASE ${PGDATABASE} OWNER \"${PGUSER}\""
            __exit_code=$?
        fi
        
        if [ ${__exit_code} -eq 0 ]; then
            # Check if schema already exists
            schema_exists=$(psql -t -h ${PGHOST} -p ${PGPORT} -d "${PGDATABASE}" -U "${MASTER_PGUSER}" -c "SELECT 1 FROM information_schema.schemata WHERE schema_name='${schema_name}'" 2>/dev/null | sed -e 's/[  ]*//g')
            
            if [ "$schema_exists" = "1" ]; then
                echo "...Schema '${schema_name}' already exists, skipping creation"
                __exit_code=0
            else
                echo "...Creating schema '${schema_name}'"
                psql -h ${PGHOST} -p ${PGPORT} -d "${PGDATABASE}" -U "${MASTER_PGUSER}" -c "CREATE SCHEMA \"${schema_name}\" AUTHORIZATION \"${PGUSER}\""
                __exit_code=$?
            fi
            
            if [ ${__exit_code} -eq 0 ]; then
                psql -h ${PGHOST} -p ${PGPORT} -d "${PGDATABASE}" -U "${MASTER_PGUSER}" -c "ALTER USER \"${PGUSER}\" SET search_path=\"${schema_name}\""
                __exit_code=$?
                if [ ${__exit_code} -eq 0 ]; then
                    psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "GRANT ALL PRIVILEGES ON DATABASE \"${PGDATABASE}\" TO \"${PGUSER}\" WITH GRANT OPTION"
                    __exit_code=$?
                    if [ ${__exit_code} -eq 0 ]; then
                        # Grant CREATEROLE privilege for all deployments
                        psql -h ${PGHOST} -p ${PGPORT} -d ${MASTER_PGDATABASE} -U "${MASTER_PGUSER}" -c "ALTER USER \"${PGUSER}\" CREATEROLE"
                        __exit_code=$?
                        if [ ${__exit_code} -ne 0 ]; then
                            echo "******* ERROR: Failed to grant create role privileges on '${PGDATABASE}' to '${PGUSER}'. Exit code: ${__exit_code}"
                        fi
                        
                        if [ ${__exit_code} -eq 0 ]; then
                            [ -f "${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/create-other-db-objects.sql" ] && {
                                psql -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -a -f "${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/create-other-db-objects.sql"
                                __exit_code=$?
                                if [ ${__exit_code} -ne 0 ]; then
                                    echo "******* ERROR: Failed to execute '${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/create-other-db-objects.sql'. Exit code: ${__exit_code}"
                                fi
                            }
                        fi
                    else
                        echo "******* ERROR: Failed to grant all privileges on '${PGDATABASE}' to '${PGUSER}'. Exit code: ${__exit_code}"
                    fi
                else
                    echo "******* ERROR: Failed to set search path '${schema_name}' for '${PGUSER}'. Exit code: ${__exit_code}"
                fi
            else
                echo "******* ERROR: Failed to create schema '${schema_name}' with authorization for '${PGUSER}'. Exit code: ${__exit_code}"
            fi
        else
            echo "******* ERROR: Failed to create database '${PGDATABASE}' with owner '${PGUSER}'. Exit code: ${__exit_code}"
        fi
    else
        echo "******* ERROR: Failed to create database user '${PGUSER}' with role '${MASTER_PGUSER}'. Exit code: ${__exit_code}"
    fi

    if [ ${__exit_code} -eq 0 ]; then
        echo "... Successfully created database schema '${schema_name}'"
        createExtensionUuidOssp
        __exit_code=$?
    fi

    # Note: Keep PGPASSWORD as MASTER_PGPASSWORD for subsequent operations
    # Service password (DB_USER_PWD) is only used for Kubernetes secrets
    return ${__exit_code}
}

# Create uuid-ossp extension if required by service
createExtensionUuidOssp() {
    local __exit_code=0
    if [ "$CREATE_UUID_OSSP_EXTENSION" = "true" ]; then
        echo "... Creating uuid-ossp extension"
        local schema_name=${PGSCHEMA:-${PGDATABASE}}
        psql -h ${PGHOST} -p ${PGPORT} -d "${PGDATABASE}" -U "${MASTER_PGUSER}" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\" SCHEMA \"${schema_name}\""
        __exit_code=$?
        if [ ${__exit_code} -eq 0 ]; then
            echo "... Successfully created uuid-ossp extension"
            # unset CREATE_UUID_OSSP_EXTENSION, as this extension should not be created for next deploying databases by default
            unset CREATE_UUID_OSSP_EXTENSION
        else
            echo "******* ERROR: Failed to create uuid-ossp extension"
        fi
    fi
    return ${__exit_code}
}

# Execute incremental database schema upgrades
# Runs upgrade scripts sequentially from current version to target version
upgradeDatabase() {
    local __exit_code=0
    
    # Check if the database and schema_version table exist
    local schema_name=${PGSCHEMA:-${PGDATABASE}}
    table_exists=$(psql -t -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE UPPER(table_name) = 'SCHEMA_VERSION' AND table_schema = '${schema_name}');" 2>/dev/null | sed -e 's/[  ]*//g')
    
    if [ "$table_exists" != "t" ]; then
        echo "...SCHEMA_VERSION table does not exist, skipping upgrade for ${SERVICE_NAME}"
        return 0
    fi

    # select from version table to get current schema version in db
    statement="SELECT VERSION FROM ${schema_name}.SCHEMA_VERSION"

    # Use master user for version check
    PREVIOUS_VERSION=$(psql -t -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -c "${statement}" 2>/dev/null | sed -e 's/[  ]*//g')
    OLD_VERSION=${PREVIOUS_VERSION}
    echo "...Previous DB version is ${PREVIOUS_VERSION}. Required version is ${CURRENT_VERSION}."

    # Handle empty PREVIOUS_VERSION
    if [ -z "${PREVIOUS_VERSION}" ]; then
        PREVIOUS_VERSION=1
        echo "...No previous version found, starting from version 1"
    fi

    
    if [[ ${PREVIOUS_VERSION} -gt ${CURRENT_VERSION} ]] ; then
      echo "...Existing SCHEMA_VERSION ${PREVIOUS_VERSION} is higher than the Required SCHEMA_VERSION ${CURRENT_VERSION}"
      echo "...Please run Manual Downgrade for database ${DB_NAME} , Exiting the setup."
      return 1
    else
        if [ "${RERUN_CURRENT_UPGRADE}" = "true" ] && [ "${PREVIOUS_VERSION}" -eq "${CURRENT_VERSION}" ]; then
           echo "...Re-running existing upgrade script"
        elif [ "${PREVIOUS_VERSION}" -eq "${CURRENT_VERSION}" ]; then
           echo "...Database is already at the required version ${CURRENT_VERSION}. No upgrade needed."
           return 0
        else
            (( PREVIOUS_VERSION++ ))
        fi

        # Execute the SQL script on the DB to create the schema and tables
        while [[ ${PREVIOUS_VERSION} -le ${CURRENT_VERSION} ]]; do
            NEXT_VERSION=$((PREVIOUS_VERSION))
            if [ "${RERUN_CURRENT_UPGRADE}" = "true" ] && [ "${PREVIOUS_VERSION}" -eq "${CURRENT_VERSION}" ]; then
                echo "...Re-running upgrade script for version: ${NEXT_VERSION}"
            else
                echo "...Upgrading from version: $((PREVIOUS_VERSION-1)) to ${NEXT_VERSION}"
            fi
            
            DBPREFIX=${DB_PREFIX}
            SQL_FILE_PATH="${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/sql/${PREVIOUS_VERSION}-up.sql"
            echo "...Executing SQL script: ${SQL_FILE_PATH}"
            # Execute upgrade using master user with SET ROLE to service user
            # This maintains proper ownership while using master credentials
            echo "...Executing upgrade as master user with role ${PGUSER}"
            if [ -f "${SQL_FILE_PATH}" ]; then
                # Create a temporary file that combines SET ROLE and search_path with the SQL script
                TEMP_SQL_FILE=$(mktemp)
                echo "SET ROLE ${PGUSER};" > "${TEMP_SQL_FILE}"
                echo "SET search_path TO ${schema_name};" >> "${TEMP_SQL_FILE}"
                cat "${SQL_FILE_PATH}" >> "${TEMP_SQL_FILE}"
                
                psql --set=AWS_REGION=${AWS_REGION} --set=IAAS_VENDOR=${IAAS_VENDOR} --set=PGDATABASE=${PGDATABASE} --set=PGUSER=${PGUSER} --set=DBPREFIX=${DBPREFIX} --set=AUTHUSER=${PGUSER} -f "${TEMP_SQL_FILE}" -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -v ON_ERROR_STOP=1
                __exit_code=$?
                
                # Clean up temporary file
                rm -f "${TEMP_SQL_FILE}"
            else
                __exit_code=1
            fi
            if [ ${__exit_code} -eq 0 ]; then
                (( PREVIOUS_VERSION++ ))
            else
                echo "******* ERROR: Failed to execute DDL statements in '${SQL_FILE_PATH}' against ${PGDATABASE} with authorization for '${PGUSER}'"
                break
            fi
        done

        if [ ${__exit_code} -eq 0 ]; then
            # Verify final version using master user
            UPGRADED_VERSION=$(psql -t -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -c "$statement" | sed -e 's/[  ]*//g')
            echo "...Successfully upgraded '${SERVICE_NAME}' from version: ${OLD_VERSION} to version: ${UPGRADED_VERSION}"
        else
            echo "...Failed to Upgrade database '${SERVICE_NAME}' from version: ${OLD_VERSION} to version: ${CURRENT_VERSION}"
        fi
    fi
    
    return ${__exit_code}
}

################################################################################
# Environment Setup
################################################################################

# Setup and validate PostgreSQL environment variables
setupPostgreSQLEnvironment() {
    echo "...Setting up PostgreSQL environment"
    local __exit_code=0

    # Set master credentials from environment variables
    if [ -z "${MASTER_PGUSER}" ]; then
        export MASTER_PGUSER="${PGUSER:-postgres}"
    fi
    if [ -z "${MASTER_PGPASSWORD}" ]; then
        export MASTER_PGPASSWORD="${PGPASSWORD:-postgres}"
    fi

    # Use VOLUME_LOCATION with default to current directory
    if [ -z "${VOLUME_LOCATION}" ]; then
        export VOLUME_LOCATION="$(pwd)"
        echo "...Using default VOLUME_LOCATION: ${VOLUME_LOCATION}"
    fi

    # Set master database - default to postgres
    if [ -z "${MASTER_PGDATABASE}" ]; then
        export MASTER_PGDATABASE="postgres"
    fi

    # DB_PREFIX is now mandatory and validated at script start
    # This section is kept for backwards compatibility but should not be reached

    # Set scripts location - use environment variable if set, otherwise default to postgres/tibco-cp-base subdirectory
    if [ -z "${PSQL_SCRIPTS_LOCATION}" ]; then
        export PSQL_SCRIPTS_LOCATION="${VOLUME_LOCATION}/postgres/tibco-cp-base"
    fi

    # Validate required directories exist
    if [ ! -d "${PSQL_SCRIPTS_LOCATION}" ]; then
        echo "******* ERROR: Scripts directory '${PSQL_SCRIPTS_LOCATION}' does not exist"
        return 1
    fi

    echo "...PostgreSQL environment setup completed"
    echo "...Volume location: ${VOLUME_LOCATION}"
    echo "...Scripts location: ${PSQL_SCRIPTS_LOCATION}"
    
    return ${__exit_code}
}

# Upgrade database objects (extensions and schema)
upgradeDatabaseObjects() {
    local __exit_code=0
    echo "...Upgrading database objects"

    createExtensionUuidOssp
    
    upgradeDatabase $*
    __exit_code=$?
    if [ ${__exit_code} -eq 0 ]; then
        echo "...Successfully upgraded database objects"
    else
        echo "******* ERROR: Failed to upgrade database objects"
    fi

    return ${__exit_code}
}

# Check if database exists and is accessible
doesDatabaseExist() {
    ## Check Database connectivity with master credentials
    cnt=1
    until [ "$cnt" -ge 20 ]; do
      psql -h ${PGHOST} -d ${MASTER_PGDATABASE} -U ${MASTER_PGUSER} -c "SELECT datname FROM pg_database WHERE datistemplate = false" > /dev/null 2>&1 && break
      echo "Database is not ready yet..Retrying....Attempt $cnt/20...sleep 30s..."
      cnt=$((cnt+1))
      sleep 30
    done

    dbname=$(psql -h ${PGHOST} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "SELECT datname FROM pg_database WHERE datistemplate = false" -t | grep ${PGDATABASE} )
    if [ -n "$dbname" ]; then
        return 0
    fi

    return 1
}


# Setup PostgreSQL for a specific service
# Handles database creation, user management, and schema upgrades
setupPostgreSQLForService() {
    export SERVICE_NAME="${1}"
    echo ""
    echo "=========================================="
    echo "Processing service: ${SERVICE_NAME}"
    echo "=========================================="
    
    # Source the service metadata
    if [ ! -f "${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/scripts/metadata.bash" ]; then
        echo "******* ERROR: metadata.bash not found for service '${SERVICE_NAME}'"
        return 1
    fi
    
    source ${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/scripts/metadata.bash
    
    # Check if database exists
    doesDatabaseExist
    __isDatabasePresent=$?
    if [ ${__isDatabasePresent} -ne 0 ]; then
        echo "...Database does not exist, creating database objects for ${SERVICE_NAME}"
        createDatabaseObjects $*
        __exit_code=$?
    else
        echo "...Database '${PGDATABASE}' exists"
        
        # Check if SCHEMA_VERSION table exists to determine if this is a fresh database
        local schema_name=${PGSCHEMA:-${PGDATABASE}}
        table_exists=$(psql -t -h ${PGHOST} -p ${PGPORT} -d ${PGDATABASE} -U ${MASTER_PGUSER} -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE UPPER(table_name) = 'SCHEMA_VERSION' AND table_schema = '${schema_name}');" 2>/dev/null | sed -e 's/[  ]*//g')
        
        if [ "$table_exists" != "t" ]; then
            echo "...SCHEMA_VERSION table missing - running initial table creation"
            # Set CREATE_DB_TABLES to ensure tables are created
            export CREATE_DB_TABLES="true"
            createDatabaseObjects $*
            __exit_code=$?
        else
            echo "...SCHEMA_VERSION table exists"
            __exit_code=0
        fi
    fi
    
    # Perform upgrade if creation was successful or database already existed
    if [ ${__exit_code} -eq 0 ]; then
        upgradeDatabaseObjects $*
        __exit_code=$?
    fi
    
    echo "...Completed processing ${SERVICE_NAME}"
    return ${__exit_code}
}

# Create all database objects for a service
# Includes user, database, schema, and initial tables
createDatabaseObjects() {
    local __exit_code=0
    echo "...Creating database objects for ${SERVICE_NAME}"
    
    # Create database, schema, and user
    createDatabaseSchemaUser
    __exit_code=$?
    
    if [ ${__exit_code} -eq 0 ]; then
        _create_db_tables_flag=${CREATE_DB_TABLES:-"true"}
        echo "...CREATE_DB_TABLES is set to ${_create_db_tables_flag}"
        if [ "${_create_db_tables_flag}" = "true" ]; then
            echo "...Creating tables for ${SERVICE_NAME}"
            createTables
            __exit_code=$?
        else
            echo "...Skipping table creation for ${SERVICE_NAME} (CREATE_DB_TABLES=${_create_db_tables_flag})"
        fi
    fi
    
    if [ ${__exit_code} -eq 0 ] && [ ! -z "${CREATE_UUID_OSSP_EXTENSION}" ]; then
        echo "...Creating UUID extension for ${SERVICE_NAME}"
        createExtensionUuidOssp
        __exit_code=$?
    fi
    
    return ${__exit_code}
}


################################################################################
# Database Deletion
################################################################################

# Delete database, user, and associated Kubernetes secret
deleteDatabaseSchemaUser() {
    local __exit_code=0
    if [ "${DELETE_DB_ACL}" = "true" ]; then
        # Terminate existing connections using master credentials
        echo "...Terminating existing connections to database"
        psql -h ${PGHOST} -p ${PGPORT} -d "${PGDATABASE}" -U "${MASTER_PGUSER}" -c "SELECT pid, pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname ='"${PGDATABASE}"'  AND pid <> pg_backend_pid()"
        __exit_code=$?
        
        if [ ${__exit_code} -eq 0 ]; then
            # Drop database
            echo "...Dropping database '${PGDATABASE}'"
            psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "DROP DATABASE IF EXISTS \"${PGDATABASE}\""
            __exit_code=$?
            if [ ${__exit_code} -eq 0 ]; then
                if [[ "${SERVICE_NAME}" == "tscscheduler" ]] ; then
                    export schedulerUser=${PGUSER}
                    echo "...Skipping ${PGUSER} deletion (will be dropped with UTD DB)"
                elif [[ "${SERVICE_NAME}" == "tscutd" ]] ; then
                    echo "...Dropping users '${PGUSER}' and '${schedulerUser}'"
                    psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "DROP USER IF EXISTS \"${PGUSER}\""
                    psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "DROP USER IF EXISTS \"${schedulerUser}\""
                    __exit_code=$?
                else
                    echo "...Dropping user '${PGUSER}'"
                    psql -h ${PGHOST} -p ${PGPORT} -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" -c "DROP USER IF EXISTS \"${PGUSER}\""
                    __exit_code=$?
                fi
                
                if [ ${__exit_code} -ne 0 ]; then
                    echo "******* ERROR: Failed to drop user '${PGUSER}'. Exit code: ${__exit_code}"
                fi
            else
                echo "******* ERROR: Failed to drop database '${PGDATABASE}'. Exit code: ${__exit_code}"
            fi
        else
            echo "******* ERROR: Failed to terminate connections to database '${PGDATABASE}'"
        fi
    fi
    
    # Only delete the DB secret if the database deletion succeeded
    if [ ${__exit_code} -eq 0 ]; then
        # Handle secret deletion based on kubectl access
        if [ "${NO_KUBECTL_ACCESS}" = "true" ]; then
            local KUBECTL_DELETE_COMMANDS_FILE="kubectl-delete-secret-commands.sh"
            
            # Initialize file with header if it doesn't exist
            if [ ! -f "${KUBECTL_DELETE_COMMANDS_FILE}" ]; then
                cat > "${KUBECTL_DELETE_COMMANDS_FILE}" << EOF
#!/bin/bash
# Kubernetes secret deletion commands
# Generated by postgres-helper.bash
#
# Instructions:
# 1. Review the commands below
# 2. Update the NAMESPACE variable if needed
# 3. Run this script in your Kubernetes environment
# 4. Verify the secrets are deleted successfully

# Set the target namespace
$(if [ -n "${POD_NAMESPACE}" ]; then echo "export NAMESPACE=\"${POD_NAMESPACE}\""; else echo "# export NAMESPACE=\"your-namespace-here\"  # Uncomment and set your target namespace"; fi)

EOF
                chmod +x "${KUBECTL_DELETE_COMMANDS_FILE}"
            fi
            
            # Append delete command
            echo "kubectl delete secret ${SERVICE_NAME}-postgres-credential -n \${NAMESPACE}" >> "${KUBECTL_DELETE_COMMANDS_FILE}"
        else
            kubectl delete secret ${SERVICE_NAME}-postgres-credential -n ${POD_NAMESPACE} 2>/dev/null || echo "...Secret ${SERVICE_NAME}-postgres-credential not found or already deleted"
        fi
    else
        echo "...Skipping secret deletion because database drop failed (exit code: ${__exit_code})"
    fi
    
    return ${__exit_code}
}

# Delete all database objects for a service
deleteDatabaseObjects() {
    local __exit_code=0
    local _service="${1}"
    
    if [ -n "${_service}" ]; then
        echo "...Deleting database objects"
        
        # Check if database exists using master credentials
        exists=$(psql -h "${PGHOST}" -p "${PGPORT}" -d "${MASTER_PGDATABASE}" -U "${MASTER_PGUSER}" \
              -tAc "SELECT 1 FROM pg_database WHERE datname='${PGDATABASE}'")
        if [ "${exists}" != "1" ]; then
                echo "...Skipping deletion for '${_service}' (database '${PGDATABASE}' not found)"
            return 0
        fi
        
        # Delete using master credentials - no need for service passwords
        deleteDatabaseSchemaUser
        __exit_code=$?
        if [ ${__exit_code} -ne 0 ]; then
            echo "******* ERROR: Failed to delete users for '${_service}'"
        else
            echo "...Database and related objects deleted for '${_service}'"
        fi
    else
        echo "******* ERROR: Service name not provided"
        __exit_code=1
    fi
    
    return ${__exit_code}
}

# Teardown PostgreSQL environment - delete all databases and users
teardownPostgreSQLEnvironment() {
    local __exit_code=0
    echo ""
    echo "Deleting PostgreSQL databases and users..."
    
    # Setup environment first
    setupPostgreSQLEnvironment
    __exit_code=$?
    if [ ${__exit_code} -ne 0 ]; then
        echo "******* ERROR: Failed to setup Postgres environment for deletion. Exit code: ${__exit_code}"
        return ${__exit_code}
    fi
    
    # Export master credentials once at the start
    echo "...Setting up master credentials"
    export-master-credentials
    
    # Note: Delete commands file will be created only when actual delete commands are generated
    
    # Process all database services found in postgres/ directory
    echo "...Processing database services for deletion"
    __db_services=$( ls -l ${PSQL_SCRIPTS_LOCATION} | grep ^d | awk '{print $9}' )
    
    # Filter out skipped services if SKIP_SERVICES is set
    if [ -n "${SKIP_SERVICES}" ]; then
        echo "...Skipping services: ${SKIP_SERVICES}"
        for skip_service in ${SKIP_SERVICES}; do
            __db_services=$(echo "${__db_services}" | grep -v "^${skip_service}$")
        done
    fi
    
    echo "...Services to be processed: ${__db_services}"
    
    for __service in ${__db_services}; do
        export SERVICE_NAME=${__service}
        
        echo ""
        echo "=========================================="
        echo "Deleting service: ${SERVICE_NAME}"
        echo "=========================================="
        
        # Source the service metadata
        if [ ! -f "${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/scripts/metadata.bash" ]; then
            echo "******* ERROR: metadata.bash not found for service '${SERVICE_NAME}'"
            continue
        fi
        
        source ${PSQL_SCRIPTS_LOCATION}/${SERVICE_NAME}/scripts/metadata.bash
        deleteDatabaseObjects ${SERVICE_NAME}
        __exit_code=$?
        
        echo "...Completed deleting ${SERVICE_NAME}"
        
        [ ${__exit_code} -ne 0 ] && break
    done

    if [ ${__exit_code} -ne 0 ]; then
        echo ""
        echo "******* ERROR: Failed to delete databases - At least one step failed. Exit code: ${__exit_code}"
    else
        echo ""
        echo "...Successfully deleted all databases and users"
        
        # Display information about generated delete commands file
        if [ "${NO_KUBECTL_ACCESS}" = "true" ] && [ -f "kubectl-delete-secret-commands.sh" ]; then
            echo ""
            echo "=========================================="
            echo "KUBECTL DELETE COMMANDS GENERATED"
            echo "=========================================="
            echo "# File location: kubectl-delete-secret-commands.sh"
            echo "# Note: File is only generated when databases/users are actually deleted"
            echo "# Execute this file on a machine with kubectl access to complete secret deletion"
            echo "=========================================="
        fi
    fi
    
    unset DELETE_DB_ACL
    return ${__exit_code}
}

# Delete all databases (wrapper function)
deleteDB() {
    export DELETE_DB_ACL=${DELETE_DB_ACL:-"true"}

    teardownPostgreSQLEnvironment
    __exit_code=$?
    if [ ${__exit_code} -ne 0 ]; then
        echo "******* ERROR: Failed to delete Postgres environment. Exit code: ${__exit_code}"
        return ${__exit_code}
    fi
    unset DELETE_DB_ACL
    return ${__exit_code}
}

# Delete command entry point
# Requires DELETE_DB_ON_UNINSTALL=true for safety
delete() {
    if [ "${DELETE_DB_ON_UNINSTALL}" = "true" ]; then
        deleteDB || return $?
    else
        echo "...Database deletion skipped (DELETE_DB_ON_UNINSTALL is not set to 'true')"
        echo "...Current DELETE_DB_ON_UNINSTALL value: ${DELETE_DB_ON_UNINSTALL:-"not set"}"
        return 0
    fi
}

################################################################################
# Upgrade Configuration
################################################################################

# Set flag to re-run current schema version upgrade
# Enabled in non-production environments for testing
setRerunCurrentUpgrade() {
  local _environment=${ENVIRONMENT_TYPE}
  if [[ ! "${_environment}" =~ "prod" ]]; then
    export RERUN_CURRENT_UPGRADE=true
  else
    export RERUN_CURRENT_UPGRADE=false
  fi
}

################################################################################
# Main Operations
################################################################################

# Install or upgrade all database services
installOrUpgrade() {
    local __exit_code=0
    echo ""
    echo "Installing or Upgrading PostgreSQL..."

    # Set rerun current upgrade flag based on environment
    setRerunCurrentUpgrade
    setupPostgreSQLEnvironment
    __exit_code=$?
    if [ ${__exit_code} -ne 0 ]; then
        echo "******* ERROR: Failed to setup Postgres environment. Exit code: ${__exit_code}"
        return ${__exit_code}
    fi
    
    # Export master credentials once at the start
    echo "...Setting up master credentials"
    export-master-credentials
    
    # Process all database services found in postgres/ directory
    echo "...Processing database services"
    __db_services=$( ls -l ${PSQL_SCRIPTS_LOCATION} | grep ^d | awk '{print $9}' )
    
    # Filter out skipped services if SKIP_SERVICES is set
    if [ -n "${SKIP_SERVICES}" ]; then
        echo "...Skipping services: ${SKIP_SERVICES}"
        __filtered_services=""
        for __service in ${__db_services}; do
            __skip_service=false
            for __skip in ${SKIP_SERVICES}; do
                if [ "${__service}" = "${__skip}" ]; then
                    __skip_service=true
                    break
                fi
            done
            if [ "${__skip_service}" = "false" ]; then
                __filtered_services="${__filtered_services} ${__service}"
            fi
        done
        __db_services="${__filtered_services}"
    fi
    
    echo "...Services to be processed: ${__db_services}"
    
    for __service in ${__db_services}; do
        setupPostgreSQLForService ${__service}
        __exit_code=$?
        if [ ${__exit_code} -ne 0 ]; then
            echo "******* ERROR: Failed to setup service '${__service}'. Exit code: ${__exit_code}"
            break
        fi
    done

    if [ ${__exit_code} -eq 0 ]; then
        echo -e "\n\n...Successfully processed all database services"

        # Display summary if kubectl commands file was created
        if [ "${NO_KUBECTL_ACCESS}" = "true" ] && [ -f "${KUBECTL_COMMANDS_FILE}" ]; then
            echo ""
            echo "=========================================="
            echo "KUBECTL CREATE SECRET COMMANDS GENERATED"
            echo "=========================================="
            echo "# File location: ${KUBECTL_COMMANDS_FILE}"
            echo "# Note: File is only generated when new users/passwords are created"
            echo "# Please share this file with your team which has cluster access to create the required Kubernetes secrets."
            echo "# The file has been made executable and can be run directly."
            echo "=========================================="
        fi
        
    else
        echo "******* ERROR: Failed to process database services - At least one step failed. Exit code: ${__exit_code}"
    fi

    return ${__exit_code}
}

# Upgrade command entry point
upgrade() {
    installOrUpgrade || return $?
}

################################################################################
# Main Execution
################################################################################

# Only execute main logic if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inputCommand=$1
    echo "Got command: ${inputCommand}..."
    echo ""
    
    # Handle check-schema-version command separately (no kubectl/namespace requirements)
    if [ "${inputCommand}" = "check-schema-version" ]; then
        service_name=$2
        if [ -z "${service_name}" ]; then
            echo "Usage: $0 check-schema-version <service_name>"
            echo "Example: $0 check-schema-version idm"
            if [[ "${PSQL_SCRIPTS_LOCATION}" == *"tibco-cp-hawk"* ]]; then
              echo "Available services: rtmon"
            else
              echo "Available services: idm, tasdataserver, tscorch, pengine, rtmon, monitoringdb, defaultidp, tasdomainserver, tscscheduler, tscutd"
            fi
            exit 1
        fi
        # Disable set -e for check-schema-version to allow proper error handling
        set +e
        check-schema-version "${service_name}"
        schema_check_result=$?
        set -e
        exit ${schema_check_result}
    fi
    
    # Validate cluster access requirements for other commands
    if [ "${NO_KUBECTL_ACCESS}" != "true" ]; then
        # Validate POD_NAMESPACE requirement
        if [ -z "${POD_NAMESPACE}" ]; then
            echo "******* ERROR: POD_NAMESPACE is required when kubectl access is enabled"
            echo "Set POD_NAMESPACE or use NO_KUBECTL_ACCESS=true to generate kubectl commands instead"
            exit 1
        fi
        
        # Validate kubectl availability
        if ! command -v kubectl &> /dev/null; then
            echo "******* ERROR: kubectl not available but cluster access is expected (NO_KUBECTL_ACCESS=false)"
            echo "Install kubectl or set NO_KUBECTL_ACCESS=true to generate kubectl commands to be run later by your team"
            exit 1
        fi
        
    fi

    # Validate psql availability
    if ! command -v psql &> /dev/null; then
        echo "******* ERROR: psql not available but required for database operations"
        echo "Install PostgreSQL client tools (psql)"
        exit 1
    fi
    
    # Validate DB_PREFIX requirement
    if [ -z "${DB_PREFIX}" ]; then
        echo "******* ERROR: DB_PREFIX is required"
        echo "Set DB_PREFIX to the controlPlaneInstanceId value with underscore suffix (global.tibco.controlPlaneInstanceId from tibco-cp-chart)"
        echo "Example: if controlPlaneInstanceId is 'cp1', then export DB_PREFIX=\"cp1_\""
        exit 1
    fi

    case $inputCommand in
        upgrade)
            upgrade
            ;;
        delete)
            delete
            ;;
        check-schema-version)
            service_name=$2
            if [ -z "${service_name}" ]; then
                echo "Usage: $0 check-schema-version <service_name>"
                echo "Example: $0 check-schema-version idm"
                if [[ "${PSQL_SCRIPTS_LOCATION}" == *"tibco-cp-hawk"* ]]; then
                  echo "Available services: rtmon"
                else
                  echo "Available services: idm, tasdataserver, tscorch, pengine, rtmon, monitoringdb, defaultidp, tasdomainserver, tscscheduler, tscutd"
                fi
                exit 1
            fi
            # Disable set -e for check-schema-version to allow proper error handling
            set +e
            check-schema-version "${service_name}"
            schema_check_result=$?
            set -e
            exit ${schema_check_result}
            ;;
        *)
            echo "Usage: $0 {upgrade|delete|check-schema-version}"
            echo "Available commands:"
            echo "  upgrade                          - Install or upgrade database schema to latest version for all services"
            echo "  delete                           - Delete database schemas, users, and secrets for all services"
            echo "  check-schema-version <service>   - Check if database schema matches expected version (for init containers)"
            exit 1
            ;;
    esac

    __exit_code=$?
    if [ ${__exit_code} -ne 0 ]; then
        echo -e "\n\n******* ERROR: Please check above for failures"
        exit ${__exit_code}
    fi

    echo -e "\n\nDone..."
fi
