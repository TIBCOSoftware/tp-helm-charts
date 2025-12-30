# PostgreSQL Database Management Script

This script provides PostgreSQL database management for TIBCO Platform deployments. It handles database initialization and schema upgrades.

## Overview

The `postgres-helper.bash` script is a unified database management tool that works with all TIBCO Platform deployments. It can be run directly for manual database operations or executed within Kubernetes jobs for automated deployment workflows.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Environment Variables](#environment-variables)
  - [Required Variables](#required-variables)
  - [Optional Variables](#optional-variables)
- [Command Reference](#command-reference)
- [Usage](#usage)
  - [Upgrade](#upgrade)
  - [Delete](#delete)
  - [Schema Version Checking](#schema-version-checking)
- [Implementation Details](#implementation-details)
  - [Directory Structure](#directory-structure)
  - [Database Service Processing](#database-service-processing)
  - [Database Operations](#database-operations)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## Features

- **Database Installation**: Creates database schemas, users, and initial setup
- **Schema Upgrades**: Handles incremental database schema upgrades
- **Database Deletion**: Removes database schemas, users, and associated secrets
- **Credential Management**: Securely manages database credentials and Kubernetes secrets

## Prerequisites

### Software Requirements

- PostgreSQL client tools (`psql`)
- `kubectl` configured with access to your Kubernetes cluster (optional - see "Database Management Without Kubernetes Access" section)
- `openssl` for password generation
- Bash shell environment

### PostgreSQL Requirements

- **PostgreSQL Version**: 14 or higher
- **Master User Privileges**: The `MASTER_PGUSER` must have privileges to:
  - Create databases and users
  - Grant privileges on databases
  - Create schemas and extensions
- **Extensions**: The `uuid-ossp` extension should be available
- **Network Access**: The machine running this script must have network connectivity to:
  - PostgreSQL server (PGHOST:PGPORT)
  - Kubernetes API server (unless using `NO_KUBECTL_ACCESS=true` mode)

### Kubernetes Requirements

- **Namespace**: The Kubernetes namespace specified in `POD_NAMESPACE` must already exist before running the script
- **RBAC Permissions**: If using `kubectl` to manage secrets directly (default mode), you need the following permissions in the target namespace:
  - `secrets`: `get`, `create`, `update`, `delete`
  - Example RBAC role:
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: database-secret-manager
      namespace: <your-namespace>
    rules:
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get", "create", "update", "delete"]
    ```

**Note**: If you don't have `kubectl` access or RBAC permissions, use `NO_KUBECTL_ACCESS=true` mode to generate kubectl commands for your cluster administrator to execute.

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PGHOST` | PostgreSQL server hostname | `postgres.example.com` |
| `PGPORT` | PostgreSQL server port | `5432` |
| `MASTER_PGUSER` | PostgreSQL master user | `postgres` |
| `MASTER_PGPASSWORD` | PostgreSQL master user password | `your-master-password` |
| `POD_NAMESPACE` | Kubernetes namespace for secrets | `cp-ns` |
| `DB_PREFIX` | Database prefix for object naming (use controlPlaneInstanceId with underscore suffix from tibco-cp-chart) | `cp1_` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NO_KUBECTL_ACCESS` | `false` | Generate kubectl commands instead of applying secrets (for users without cluster access) |
| `ENVIRONMENT_TYPE` | unset | Environment type (affects upgrade behavior). Set to `prod` for production to disable re-running current schema version upgrades. Non-prod environments will re-run the current version script on each upgrade |
| `SKIP_SERVICES` | unset | Space-separated list of services to skip during processing. Available services vary by chart (see `Usage` section for details). |
| `DELETE_DB_ON_UNINSTALL` | unset | Set to `true` to enable database deletion. If not set or `false`, delete command will skip actual deletion |
| `PSQL_SCRIPTS_LOCATION` | `$(pwd)/postgres/tibco-cp-base` | Path to SQL scripts directory. For other charts, set to `$(pwd)/postgres/<chart-name>` |

## Command Reference

| Command | Description |
|---------|-------------|
| `upgrade` | Install or upgrade database schema to latest version for all services |
| `delete` | Delete database schemas, users, and secrets for all services (requires DELETE_DB_ON_UNINSTALL=true) |
| `check-schema-version <service_name>` | Check if database schema version matches expected version for a specific service |

## Important Notes

⚠️ **Critical Workflow Requirements:**
- **Before Chart Install/Upgrade**: Always run `upgrade` command first to ensure database schemas are ready
- **After Chart Uninstall**: Only run `delete` command after the chart is completely uninstalled to avoid connection errors
- **Do Not Interrupt**: Allow the script to complete fully. Interrupting during execution may leave databases in an inconsistent state
- **Password Management**: Random passwords are generated only when creating new users. If a user already exists, the script skips password generation. Passwords are stored in Kubernetes secrets (or kubectl command files if `NO_KUBECTL_ACCESS=true`)

## Generated Files

The script creates the following files:

| File | When Created | Purpose |
|------|--------------|---------|
| `kubectl-create-secret-commands.sh` | `NO_KUBECTL_ACCESS=true` during upgrade (only when new users/passwords are created) | Contains kubectl commands to create secrets (for cluster admin to execute) |
| `kubectl-delete-secret-commands.sh` | `NO_KUBECTL_ACCESS=true` during delete (only when databases/users are actually deleted) | Contains kubectl commands to delete secrets (for cluster admin to execute) |

**Important Notes:**
- The kubectl command files are **only generated when there are actual changes** (new users created or databases deleted)
- On reruns with no changes, these files will not be created/updated
- If `POD_NAMESPACE` is not set, the generated scripts will contain a commented-out `export NAMESPACE` line that users can uncomment and set before running
- Passwords are generated randomly using openssl on first run and stored in Kubernetes secrets (or in the kubectl command files if `NO_KUBECTL_ACCESS=true`)

## Usage

### Primary Use Case

When deploying the `tibco-cp-base` chart with `global.tibco.manageDbSchema=false`, the chart does not manage database schemas. You must use this script to create, upgrade, and delete databases externally.

**Key points:**
- Set `DB_PREFIX` to match `global.tibco.controlPlaneInstanceId` with an underscore suffix (e.g., `cp1` → `cp1_`)
- Run upgrade before installing/upgrading the chart
- Run delete after uninstalling the chart
- See environment variables table above for required configuration

**Example chart values:**
```yaml
global:
  tibco:
    manageDbSchema: false
    controlPlaneInstanceId: cp1
```

### Upgrade

Create or upgrade all control-plane databases and users. Run this command before installing or upgrading the associated Helm chart.

```bash
# Set required environment variables
export PGHOST="<postgres-host>"
export PGPORT="5432"
export MASTER_PGUSER="postgres"
export MASTER_PGPASSWORD="<master-password>"
export POD_NAMESPACE="<your-cp-namespace>"
export DB_PREFIX="cp1_"  # controlPlaneInstanceId + underscore

# Create or upgrade all databases and users for the default chart (tibco-cp-base)
./postgres-helper.bash upgrade
```

#### Running for a Specific Chart (e.g., `tibco-cp-hawk`)

By default, the script is configured for the `tibco-cp-base` chart. To target a different chart, export the `PSQL_SCRIPTS_LOCATION` variable.

```bash
# Example: Run upgrade for the tibco-cp-hawk chart
export PSQL_SCRIPTS_LOCATION=$(pwd)/postgres/tibco-cp-hawk
./postgres-helper.bash upgrade
```

#### Without Kubernetes Access

If you do not have `kubectl` access, set `NO_KUBECTL_ACCESS=true` to generate a `kubectl-create-secret-commands.sh` file instead of directly creating secrets.

```bash
export NO_KUBECTL_ACCESS="true"
export PGHOST="<postgres-host>"
export PGPORT="5432"
export MASTER_PGUSER="postgres"
export MASTER_PGPASSWORD="<master-password>"
export POD_NAMESPACE="<your-cp-namespace>"
export DB_PREFIX="cp1_"

./postgres-helper.bash upgrade
```

The script will:
- Create databases and users in PostgreSQL
- Generate `kubectl-create-secret-commands.sh` containing all kubectl commands to create secrets

Share the generated file with your cluster administrator to execute on the cluster.

#### Skip Specific Services

You can skip processing specific database services during upgrade by setting the `SKIP_SERVICES` environment variable with a space-separated list of service names.

**Available services vary by chart:**
- **tibco-cp-base**: `defaultidp`, `idm`, `monitoringdb`, `pengine`, `tasdataserver`, `tasdomainserver`, `tscorch`, `tscscheduler`, `tscutd`
- **tibco-cp-hawk**: `rtmon`

To see available services for your chart, list the directories in your `PSQL_SCRIPTS_LOCATION`:
```bash
ls -1 postgres/tibco-cp-base/    # For tibco-cp-base chart
ls -1 postgres/tibco-cp-hawk/    # For tibco-cp-hawk chart
```

```bash
# Example: Skip processing of idm and tscorch services
export SKIP_SERVICES="idm tscorch"
./postgres-helper.bash upgrade
```

### Delete

When `global.tibco.manageDbSchema=false`, the chart will not delete databases on uninstall. Use this script to clean up after uninstalling the chart.

Run database deletion **after** uninstalling the associated Helm chart. Running delete while the chart is still deployed and databases are in use by pods may cause the operation to fail.

```bash
# 1) Uninstall the chart release (e.g., tibco-cp-base)
helm uninstall tibco-cp-base -n <your-cp-namespace>

# 2) Set required environment variables
export PGHOST="<postgres-host>"
export PGPORT="5432"
export MASTER_PGUSER="postgres"
export MASTER_PGPASSWORD="<master-password>"
export POD_NAMESPACE="<your-cp-namespace>"
export DB_PREFIX="cp1_"

# 3) Run delete command (required to allow deletion)
export DELETE_DB_ON_UNINSTALL="true"
./postgres-helper.bash delete
```

#### Running for a Specific Chart (e.g., `tibco-cp-hawk`)

To target a different chart, export the `PSQL_SCRIPTS_LOCATION` variable before running the delete command.

```bash
# Example: Run delete for the tibco-cp-hawk chart
export PSQL_SCRIPTS_LOCATION=$(pwd)/postgres/tibco-cp-hawk
export DELETE_DB_ON_UNINSTALL="true"
./postgres-helper.bash delete
```

#### Without Kubernetes Access

If you do not have `kubectl` access, set `NO_KUBECTL_ACCESS=true` to generate a `kubectl-delete-secret-commands.sh` file instead of directly deleting secrets.

```bash
export NO_KUBECTL_ACCESS="true"
export DELETE_DB_ON_UNINSTALL="true"
./postgres-helper.bash delete
```

Share the generated file with your cluster administrator to execute on the cluster.

**Safety features:**
- Deletion only proceeds if `DELETE_DB_ON_UNINSTALL=true`
- Supports `NO_KUBECTL_ACCESS=true` mode to generate kubectl commands

### Schema Version Checking

The `check-schema-version` function is useful for checking whether the current schema version in the database matches the expected schema version:

```bash
# Set required environment variables for schema version checking
export DB_PREFIX="cp1_"
export PGHOST="your-postgres-host"
export PGPORT="5432"
export PGPASSWORD="service-user-password" #eg. if checking for idm db, set idm user password.

# Check schema version for a specific service
./postgres-helper.bash check-schema-version idm

```

**Available services for schema checking vary by chart:**
- **tibco-cp-base**: `defaultidp`, `idm`, `monitoringdb`, `pengine`, `tasdataserver`, `tasdomainserver`, `tscorch`, `tscscheduler`, `tscutd`
- **tibco-cp-hawk**: `rtmon`

To see available services for your chart, list the directories in your `PSQL_SCRIPTS_LOCATION`:
```bash
ls -1 postgres/tibco-cp-base/    # For tibco-cp-base chart
ls -1 postgres/tibco-cp-hawk/    # For tibco-cp-hawk chart
```


## Implementation Details

### Directory Structure

The script expects the following directory structure for SQL scripts:

```
scripts/database/postgres/
├── tibco-cp-base/              # Default chart (PSQL_SCRIPTS_LOCATION points here by default)
│   ├── idm/
│   │   ├── scripts/
│   │   │   └── metadata.bash
│   │   └── sql/
│   │       ├── 1-up.sql
│   │       ├── 2-up.sql
│   │       └── ...
│   └── service2/
│       └── ...
├── tibco-cp-hawk/ 
│   ├── rtmon/
│   │   ├── scripts/
│   │   │   └── metadata.bash
│   │   └── sql/
│   │       ├── 1-up.sql
│   │       └── ...
```

Each service directory must contain:
- `scripts/metadata.bash`: Defines database connection parameters (PGDATABASE, PGUSER, etc.)
- `sql/`: Contains numbered upgrade scripts (1-up.sql, 2-up.sql, etc.)

### Database Service Processing

The script processes all database services found in `${PSQL_SCRIPTS_LOCATION}/` directory. Each service should have:
- A `scripts/metadata.bash` file containing database configuration
- SQL files for schema creation and upgrades

### Database Operations

#### Installation Process
1. Verifies database connectivity
2. Creates database users if they don't exist
3. Creates databases and schemas
4. Sets up proper permissions and roles
5. Executes initial SQL setup scripts
6. Manages Kubernetes secrets for database credentials (or generates kubectl commands)

#### Upgrade Process
1. Uses saved passwords from previous runs or generates new ones
2. Checks current schema version
3. Executes upgrade scripts sequentially (1-up.sql, 2-up.sql, etc.)
4. Updates schema version tracking
5. Manages Kubernetes secrets (or generates kubectl commands)

## Security Considerations

- Database passwords are automatically generated using `openssl`
- Credentials can be stored as Kubernetes secrets or shared using a script to run on cluster later

## Troubleshooting

### Common Issues

1. **Database Connection Failures**
   - Verify `PGHOST` and `PGPORT` settings
   - Check network connectivity to PostgreSQL
   - Ensure `MASTER_PGUSER` and `MASTER_PGPASSWORD` are correct

2. **Permission Errors**
   - Verify Kubernetes RBAC permissions for secret management (if using kubectl)
   - Check PostgreSQL user permissions
   - For no kubectl access, use `NO_KUBECTL_ACCESS=true`

3. **Script Location Errors**
   - Verify `PSQL_SCRIPTS_LOCATION` points to the correct chart directory (default: `$(pwd)/postgres/tibco-cp-base`)
   - For other charts, set `PSQL_SCRIPTS_LOCATION=$(pwd)/postgres/<chart-name>` eg. `PSQL_SCRIPTS_LOCATION=$(pwd)/postgres/tibco-cp-hawk`
   - Ensure SQL scripts and metadata files exist
   - Check file permissions and accessibility

4. **Delete Fails with "database is being accessed by other users"**
   - Error: `ERROR: database <db_name> is being accessed by other users`
   - Ensure the `tibco-cp-base` chart is fully uninstalled before running delete
   - Verify no pods are still running and accessing the databases
   - Wait for all pods to terminate completely after helm uninstall before running delete

