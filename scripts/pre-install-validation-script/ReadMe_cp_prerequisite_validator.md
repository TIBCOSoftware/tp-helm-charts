# TIBCO Control Plane Installation Prerequisite Validator

This script validates prerequisites for TIBCO Control Plane installation. The script reads configuration values from a YAML file and environment files.

---

## Features

* **YAML-based Configuration**: Reads all required settings from a single YAML file.
* **Environment-based Overrides: Supports additional configuration via platform_base_default_config.env.
* **Comprehensive Validation**: Covers key validation categories for control plane deployment.
* **Severity-based Reporting**: Categorizes validations as HIGH, MEDIUM, or LOW severity.
* **Detailed Reporting**: Generates both console output and HTML reports.
* **Kubernetes-native**: Runs validation tests directly within the cluster.

---

## Prerequisites for script execution

* `kubectl` installed and configured to access your Kubernetes cluster.
* `yq` installed for YAML parsing.
* Appropriate permissions to create test resources in the cluster.
* platform_base_default_config.env must be in the same directory as the script 
* platform_base_values.yaml must be in the same directory as the script
---

## Configuration Files

* platform_base_values.yaml: Main configuration file (edit as needed).
* platform_base_default_config.env: Environment file for overriding default settings (e.g., paths, repo URLs).

---

## Quick Start

1.  **Create your configuration YAML file:**
    ```bash
    cp platform_base_values.yaml.template platform_base_values.yaml
    ```
    
2.  **Edit the YAML file with your specific values:**
    ```bash
    vim platform_base_values.yaml
    ```
	
3.  **Edit platform_base_default_config.env as needed:** 
    ```bash
    vim platform_base_default_config.env
    ```
	
4. **Run the validation:**
    ```bash
    ./cp_prerequisite_validator.sh
    ```
5. **Once you run the script it will ask for yaml config file name and required image file name. You can provide any name or press enter and it will take by default the name of files mentioned above**

---

## Required YAML Configuration Structure

```yaml
global:
  tibco:
    namespace: "cp-system"
    controlPlaneInstanceId: "cp-instance"
    containerRegistry:
      url: "your-registry-url"
      username: "your-username"
      password: ""
      repository: "your-repository"
    helm:
      repo: "tp-helm-charts"
      url: "[https://raw.githubusercontent.com/tibco/tp-helm-charts/gh-pages](https://raw.githubusercontent.com/tibco/tp-helm-charts/gh-pages)"
      username: "your-helm-username"
      password: ""
  external:
    db_host: "your-db-host"
    db_port: "5432"
    db_name: "your-db-name"
    db_username: "your-db-user"
    db_password: ""
    emailServer:
      smtp:
        server: "smtp.example.com"
        port: "587"
        username: "smtp-user"
        password: ""
    admin:
      email: "admin@example.com"
```      
	  
## Required platform_base_default_config.env Structure
```text
EXPECTED_K8S_CLUSTER_NAME="docker-desktop"

# Database configuration
POSTGRES_HOST=""
POSTGRES_PORT="5432"
POSTGRES_DB=""
POSTGRES_USER=""
POSTGRES_PASSWORD=""

# Container Registry Repository configuration
PRIVATE_IMAGE_REPO_URL=""
PRIVATE_IMAGE_USERNAME=""
PRIVATE_IMAGE_PASSWORD=""
PRIVATE_IMAGE_CONTAINER_REGISTRY_REPO=""

# Helm Chart Repository configuration
PRIVATE_CHART_REPO_NAME=""
PRIVATE_CHART_REPO_URL=""
PRIVATE_CHART_REPO_USERNAME=""
PRIVATE_CHART_REPO_PASSWORD=""

# Kubernetes configuration
STORAGE_CLASS="hostpath"
INGRESS_CLASS="nginx"
NAMESPACE="default"
SERVICE_ACCOUNT=""
MIN_K8S_VERSION="1.28.0"
MAX_K8S_VERSION="1.33.5"

# Resource requirements
REQUIRED_CPU="4"
REQUIRED_MEMORY="8Gi"

# SMTP configuration
RUN_SMTP_VALIDATIONS=""
SMTP_HOST=""
SMTP_PORT="1025"
SMTP_USER=""
SMTP_PASSWORD=""
ADMIN_EMAIL=""

```
---
## Usage

```bash
./cp_prerequisite_validator.sh [OPTIONS]

OPTIONS:
    -s, --skip-low         Skip low severity validations
    -m, --skip-medium      Skip medium severity validations
    -h, --help             Show help message
```

## Validation Categories

### Pre-installation Validations

| ID | Category | Validation | Severity |
|----|----------|--|----------|
| 1 | Infrastructure | Kubernetes cluster version check | LOW |
| 2 | Infrastructure | Cluster resource availability | LOW |
| 3 | Database | Postgres database accessibility | HIGH |
| 4 | Database | Database user permissions | HIGH |
| 5 | Access | ServiceAccount must exist in namespace | HIGH |
| 6 | Private Repos | Private chart repo accessibility | HIGH |
| 7 | Private Repos | Charts availability in private repo | HIGH |
| 8 | Private Repos | Private image repo accessibility | HIGH |
| 9 | Private Repos | Images availability in private repo | HIGH |
| 10 | Storage | StorageClass availability | HIGH |
| 11 | Storage | Dynamic PVC creation | HIGH |
| 12 | Ingress | IngressClass availability | HIGH |
| 13 | Email | SMTP accessibility | HIGH |
| 14 | Email | Email service permissions | HIGH |


## Output

The script generates:

1. **Console Output**: Real-time validation progress with color-coded results
2. **Log File**: Detailed log file with timestamp (`cp_validation_YYYYMMDD_HHMMSS.log`)
3. **HTML Report**: Comprehensive HTML report with summary and recommendations (`cp_validation_report_YYYYMMDD_HHMMSS.html`)


## Security Considerations

- Store sensitive credentials (passwords, tokens) securely
- Use Kubernetes secrets for production deployments
- Limit script permissions to necessary resources only
- Review and audit the script before running in production environments

## Troubleshooting

### Common Issues

1. **kubectl not found**: Ensure kubectl is installed and in your PATH
2. **Cluster connection failed**: Verify your kubeconfig is correct
3. **Permission denied**: Ensure your user/ServiceAccount has required permissions
4. **Timeout errors**: Check network connectivity to external services

---

## Example: Adding a New Validation

To add a new validation to the prerequisite validator script, follow these steps:

1. **Define the validation function**

   Add a new function in `cp_prerequisite_validator.sh` following the existing pattern. For example, to check if all nodes are Ready:

   ```bash
   # Validation 15: All nodes must be Ready
   validate_all_nodes_ready() {
       local validation_id="15"
       local category="Infrastructure"
       local description="All Kubernetes nodes must be in Ready state"
       local severity="LOW"

       log "INFO" "Running validation ${validation_id}: ${description}"

       local not_ready_nodes
       not_ready_nodes=$(kubectl get nodes --no-headers | grep -v " Ready " || true)
       if [[ -z "$not_ready_nodes" ]]; then
           record_result "${validation_id}" "${category}" "${description}" "${severity}" "PASS" "All nodes are Ready"
           log "INFO" "All nodes are Ready"
       else
           record_result "${validation_id}" "${category}" "${description}" "${severity}" "FAIL" "Some nodes are not Ready"
           log "ERROR" "Some nodes are not Ready:\n$not_ready_nodes"
       fi
   }
    ```
2. **Call the function in the main execution flow**
    ```bash
    validate_all_nodes_ready || true
    ```
3. **Update the documentation**
   Add your new validation to the validation table in the README, specifying its ID, category, description, and severity.

4. **Test the new validation**

---
    