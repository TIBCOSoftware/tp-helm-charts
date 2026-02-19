# Common Upgrade Helper Library

## Overview

The `upgrade-helpers.sh` library provides reusable functions for TIBCO Control Plane upgrade scripts (version 1.13.0+).

### What's Included

- **`upgrade-helpers.sh`**: 600+ lines of reusable bash functions
- **`template-upgrade.sh`**: Ready-to-use template for new upgrade scripts
- **`README.md`**: This documentation file

### Architecture

All upgrades from version 1.13.0 onwards:
- **Single chart**: `tibco-cp-base`
- **Single release**: `platform-base` (standard release name)
- **Single values file**: One YAML for the entire control plane

### Benefits

- **Reduced Duplication**: 90% reduction in boilerplate code
- **Consistency**: All scripts use the same functions and formatting
- **Less Error-Prone**: Tested functions reduce bugs
- **Easier Maintenance**: Fix once, benefit everywhere
- **Faster Development**: New scripts created in hours, not days

---

## Quick Start

### Create a New Upgrade Script

```bash
# 1. Copy the template
mkdir -p scripts/1.16.0
cp scripts/common/template-upgrade.sh scripts/1.16.0/upgrade.sh

# 2. Edit and update versions
# Change FROM_VERSION="1.15.0" and TO_VERSION="1.16.0"

# 3. Implement version-specific logic in process_files()

# 4. Test
cd scripts/1.16.0
./upgrade.sh
```

### Example: Simple Version-Specific Logic

```bash
process_files() {
    print_info "Processing files for upgrade generation..."
    validate_file "${CONTROL_PLANE_FILE}" "Control plane values file" || exit 1
    
    # Start with current values as base
    cp "${CONTROL_PLANE_FILE}" "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Add new configuration for 1.16.0
    yq eval '.global.newFeature.enabled = true' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    # Remove deprecated settings
    yq eval 'del(.deprecated.oldSetting)' -i "${CONTROL_PLANE_OUTPUT_FILE}"
    
    print_success "Processing completed successfully"
}
```

---

## Usage

### Source the Library

At the top of your upgrade script:

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/upgrade-helpers.sh"

# Initialize common variables
init_common_variables
```

---

## Function Reference

### Print Functions

```bash
print_info "Informational message"        # Blue [INFO]
print_success "Success message"           # Green [SUCCESS]
print_warning "Warning message"           # Yellow [WARNING]
print_error "Error message"               # Red [ERROR] (to stderr)
print_step "Major step message"           # Cyan [STEP]
print_separator                           # Prints a separator line
```

### Version Comparison

```bash
# Returns 0 if v1 >= v2
if version_ge "1.13.0" "1.12.0"; then
    print_info "Version check passed"
fi
```

### Temporary Directory

```bash
# Creates temp directory with automatic cleanup on exit
setup_temp_dir
echo "Using: ${TEMP_DIR}"
```

### Dependency Checking

```bash
# Check specific dependencies
check_yq "4.45.4"        # Check yq with minimum version
check_helm "3.17"        # Check helm with minimum version
check_jq "1.8.0"         # Check jq with minimum version
check_kubectl            # Check kubectl

# Comprehensive check
check_dependencies "4.45.4" true true
# Params: yq_min_version, helm_mode (true/false), upgrade_mode (true/false)
```

### Helm Operations

```bash
# Get release version
version=$(get_helm_release_version "platform-base" "default")

# Get release status
status=$(get_helm_release_status "platform-base" "default")

# Extract values from a release
extract_helm_values "platform-base" "default" "/tmp/values.yaml"

# Validate release before upgrade
validate_helm_release_for_upgrade "platform-base" "default" "1.13.0" "deployed"

# Verify upgrade was successful
verify_upgrade "platform-base" "my-namespace" "1.14.0"
```

### Kubectl Operations

```bash
# Verify namespace exists
verify_namespace "my-namespace"

# Check pod status in namespace
check_pod_status "my-namespace"
```

### File Operations

```bash
# Validate file exists and is readable
validate_file "/path/to/file.yaml" "Configuration file"

# Generate output filename
output_file=$(generate_output_filename "platform-base" "1.14.0" "file" "/output/dir")
# Result: /output/dir/platform-base-1.14.0.yaml
```

### Interactive Prompts

```bash
# Prompt for file with validation
file_path=$(prompt_for_file "Enter configuration file path" true)

# Prompt for namespace
namespace=$(prompt_for_namespace)

# Prompt for release name with default
release=$(prompt_for_release_name "Enter release name" "platform-base")

# Prompt for yes/no confirmation
if prompt_yes_no "Do you want to continue?" "yes"; then
    print_info "User confirmed"
fi
```

### Usage Display

```bash
# Show standard usage help
show_standard_usage "1.13.0" "1.14.0"
```

### Error Handling

```bash
# Exit with fatal error
fatal_error "Critical error occurred, cannot continue"
```

### Logging

```bash
# Setup logging to file
log_file=$(setup_logging "/path/to/logs" "upgrade")
# All output will be logged to the returned file path
```

---

## Common Patterns

### Interactive Mode Selection

```bash
interactive_mode() {
    echo "Please select your operation mode:"
    echo "1) Generate values.yaml files"
    echo "2) Perform Helm upgrade"
    
    while true; do
        read -p "Enter your choice (1 or 2): " choice
        case $choice in
            1)
                print_info "Selected: Generate values"
                break
                ;;
            2)
                print_info "Selected: Perform upgrade"
                HELM_UPGRADE_MODE=true
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}
```

### Helm Values Extraction

```bash
extract_values() {
    print_step "Extracting current values"
    
    NAMESPACE=$(prompt_for_namespace)
    verify_namespace "${NAMESPACE}"
    
    RELEASE=$(prompt_for_release_name "Release name" "platform-base")
    
    # Validate release
    validate_helm_release_for_upgrade "${RELEASE}" "${NAMESPACE}" "${FROM_VERSION}"
    
    # Extract
    OUTPUT_FILE="${TEMP_DIR}/extracted-values.yaml"
    extract_helm_values "${RELEASE}" "${NAMESPACE}" "${OUTPUT_FILE}"
    
    print_success "Values extracted to: ${OUTPUT_FILE}"
}
```

### Upgrade Execution

```bash
perform_upgrade() {
    print_step "Performing Helm upgrade"
    
    # Pre-upgrade validation
    check_dependencies "${REQUIRED_YQ_VERSION}" true true
    verify_namespace "${NAMESPACE}"
    
    # Confirm with user
    if ! prompt_yes_no "Ready to upgrade from ${FROM_VERSION} to ${TO_VERSION}?" "no"; then
        print_info "Upgrade cancelled by user"
        exit 0
    fi
    
    # Perform upgrade
    print_info "Upgrading ${RELEASE_NAME} to ${TO_VERSION}..."
    helm upgrade "${RELEASE_NAME}" "tibco-platform/tibco-cp-base" \
        --version "${TO_VERSION}" \
        --namespace "${NAMESPACE}" \
        --values "${VALUES_FILE}" \
        --wait --timeout=1h
    
    # Verify
    verify_upgrade "${RELEASE_NAME}" "${NAMESPACE}" "${TO_VERSION}"
    check_pod_status "${NAMESPACE}"
    
    print_success "Upgrade completed successfully"
}
```

---

## Transformation Examples

### Add New Configuration

```bash
yq eval '.global.monitoring.enabled = true' -i "${OUTPUT_FILE}"
yq eval '.global.monitoring.prometheus.scrapeInterval = "30s"' -i "${OUTPUT_FILE}"
```

### Remove Deprecated Configuration

```bash
yq eval 'del(.deprecated)' -i "${OUTPUT_FILE}"
yq eval 'del(.global.oldFeature)' -i "${OUTPUT_FILE}"
```

### Rename/Move Configuration

```bash
yq eval '.new.path = .old.path | del(.old.path)' -i "${OUTPUT_FILE}"
```

### Update Resource Limits

```bash
yq eval '.tp-cp-core.resources.limits.memory = "2Gi"' -i "${OUTPUT_FILE}"
yq eval '.tp-cp-core.resources.requests.memory = "1Gi"' -i "${OUTPUT_FILE}"
```

### Conditional Transformations

```bash
# Only add if it doesn't exist
if ! yq eval '.global.feature' "${OUTPUT_FILE}" >/dev/null 2>&1; then
    yq eval '.global.feature.enabled = true' -i "${OUTPUT_FILE}"
fi
```

### Merge External Configuration

```bash
cat > "${TEMP_DIR}/new-config.yaml" << EOF
tp-cp-monitoring:
  enabled: true
  retention: 7d
EOF

yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
    "${OUTPUT_FILE}" \
    "${TEMP_DIR}/new-config.yaml" > "${OUTPUT_FILE}.tmp"
mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
```

---

## Testing & Troubleshooting

### Testing Checklist

After creating or migrating a script:

- [ ] Values generation from files works
- [ ] Values generation from Helm works
- [ ] Helm upgrade works
- [ ] Error handling works correctly
- [ ] Interactive prompts handle invalid input
- [ ] Dependencies are checked properly
- [ ] Pod status verification works
- [ ] Output formatting is consistent
- [ ] Script exits cleanly on errors
- [ ] Help text displays correctly

### Common Issues

#### Script fails with "source: not found"

Ensure the path is correct:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/upgrade-helpers.sh"
```

#### yq transformations not working

Check yq version (need 4.45.4+):
```bash
yq --version
# If too old: brew upgrade yq or apt-get install yq
```

#### Upgrade hangs or fails

Check pod logs:
```bash
kubectl get pods -n your-namespace
kubectl describe pod <pod-name> -n your-namespace
kubectl logs <pod-name> -n your-namespace
```

### Test Workflow

```bash
# 1. Test values generation from file
cd scripts/1.16.0
./upgrade.sh
# Select option 1, provide existing values file

# 2. Test values generation from Helm
./upgrade.sh
# Select option 1, choose Helm extraction

# 3. Test actual upgrade (in test environment!)
./upgrade.sh
# Select option 2, confirm prompts

# 4. Verify results
kubectl get pods -n <namespace>
helm list -n <namespace>
```

---

## Best Practices

1. **Always source the library first** before using any functions
2. **Initialize variables** with `init_common_variables()` after sourcing
3. **Use appropriate print functions** to keep consistent formatting
4. **Validate early**: Check dependencies and inputs before operations
5. **Use temp directories**: Call `setup_temp_dir()` for temporary files
6. **Provide user feedback**: Use print functions liberally
7. **Handle errors gracefully**: Use `fatal_error()` for unrecoverable errors
8. **Verify operations**: Always verify after critical operations
9. **Clean up**: Temp directory cleanup is automatic

---

## Alpha/Beta Version Testing

To test alpha or beta versions, use the `CHART_VERSION` environment variable:

```bash
# Test alpha version
export CHART_VERSION="1.16.0-alpha.1"
./scripts/1.16.0/upgrade.sh

# Test beta version
export CHART_VERSION="1.16.0-beta.1"
./scripts/1.16.0/upgrade.sh

# Test release candidate
export CHART_VERSION="1.16.0-rc.1"
./scripts/1.16.0/upgrade.sh

# Final release
export CHART_VERSION="1.16.0"
./scripts/1.16.0/upgrade.sh
```

The script will use `CHART_VERSION` if set, otherwise defaults to `TO_VERSION`.

---

## Complete Example Script

Here's a minimal working upgrade script:

```bash
#!/bin/bash
# TIBCO Control Plane Upgrade Script (1.14.0 → 1.15.0)

# Source helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/upgrade-helpers.sh"
init_common_variables

# Configuration
FROM_VERSION="1.14.0"
TO_VERSION="1.15.0"
REQUIRED_YQ_VERSION="4.45.4"
CONTROL_PLANE_RELEASE_NAME="platform-base"

# Show usage
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_standard_usage "${FROM_VERSION}" "${TO_VERSION}"
    exit 0
fi

# Main execution
main() {
    setup_temp_dir
    check_dependencies "${REQUIRED_YQ_VERSION}" false false || exit 1
    
    NAMESPACE=$(prompt_for_namespace)
    verify_namespace "${NAMESPACE}"
    
    # Extract values
    VALUES_FILE="${TEMP_DIR}/current-values.yaml"
    extract_helm_values "${CONTROL_PLANE_RELEASE_NAME}" "${NAMESPACE}" "${VALUES_FILE}"
    
    # Generate output
    OUTPUT_FILE="control-plane-${TO_VERSION}.yaml"
    cp "${VALUES_FILE}" "${OUTPUT_FILE}"
    
    # Apply transformations (add your version-specific logic here)
    yq eval '.global.newFeature.enabled = true' -i "${OUTPUT_FILE}"
    
    print_success "Generated: ${OUTPUT_FILE}"
}

main "$@"
```

---

## Contributing

When adding new functions to the helper library:

1. Ensure it's truly reusable (needed by 2+ scripts)
2. Add comprehensive comments in the code
3. Update this README with usage examples
4. Test with multiple scripts
5. Maintain backwards compatibility

---

## Support

For issues or questions about the helper library:
- Review this documentation
- Check `template-upgrade.sh` for reference
- Contact the TIBCO Platform team

---

**Version:** 1.0.0 
