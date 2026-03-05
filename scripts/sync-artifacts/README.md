# sync-artifacts

This folder contains helper scripts for **syncing container images and Helm charts**.

## Scope

- This documentation covers:
  - `sync-images.sh` (container images)
  - `sync-charts.sh` (Helm charts)
- `sync-images.sh` is **for copying images between registries**.
- `sync-charts.sh` is **for pulling and pushing Helm charts only**.

---

# sync-images.sh

`sync-images.sh` is a **non-interactive** script driven by environment variables that:

- Copies container images directly between registries using `docker buildx imagetools`
- Preserves multi-architecture manifests during copy
- Reads image lists from the `../../artifacts` directory

---

## Prerequisites

- Docker must be installed and running (`docker info` must succeed)
- Docker Buildx must be available (`docker buildx version` must succeed)
- Network access to both source and target registries (buildx copies directly between registries)

---

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `SOURCE_REGISTRY` | Source Docker registry URL |
| `SOURCE_REGISTRY_USERNAME` | Username for source registry authentication |
| `SOURCE_REGISTRY_PASSWORD` | Password for source registry authentication |
| `RELEASE_VERSION` | Release version in `<major>.<minor>.<patch>` format (e.g., `1.15.0`) |
| `TARGET_REGISTRY` | Target Docker registry URL |

### Optional

| Variable | Description |
|----------|-------------|
| `SOURCE_REGISTRY_REPO` | Source repository path. Default: `tibco-platform-docker-prod` |
| `CAPABILITY_NAME` | If set, only sync images from `<CAPABILITY_NAME>-<RELEASE_VERSION>-images.txt`. Otherwise, all `*-<RELEASE_VERSION>-images.txt` files are used. |
| `TARGET_REGISTRY_USERNAME` | Username for target registry authentication |
| `TARGET_REGISTRY_PASSWORD` | Password for target registry authentication |
| `TARGET_REGISTRY_REPO` | Target repository path |
| `WRITE_SCRIPT_LOGS_TO_FILE` | If `true`, writes logs to `image_sync_<timestamp>.log`. Default: `false` |
| `MAX_RETRY` | Number of retries for copy operations. Default: `0` (no retry) |
| `WAIT_BEFORE_RETRY` | Seconds to wait before each retry. Default: `0` (no wait) |
| `DOCKER_QUIET` | If `false`, show buildx output. Default: `true` (output suppressed) |

---

## How to run

From this directory:

```bash
export SOURCE_REGISTRY="your-source-registry.io"
export SOURCE_REGISTRY_USERNAME="your-username"
export SOURCE_REGISTRY_PASSWORD="your-password"
export RELEASE_VERSION="1.15.0"
export TARGET_REGISTRY="your-target-registry.io"

./sync-images.sh
```

---

## Image Selection

Images are read from the `../../artifacts` directory.

**Note**: The `../../artifacts` directory must exist. If missing, clone the public repo:
- `https://github.com/TIBCOSoftware/tp-helm-charts`

### Default: All images for release version

Without `CAPABILITY_NAME`, searches recursively for all files matching:
- `*-<RELEASE_VERSION>-images.txt` under `../../artifacts/`

### With CAPABILITY_NAME

Uses only the specific file:
- `../../artifacts/<CAPABILITY_NAME>/<CAPABILITY_NAME>-<RELEASE_VERSION>-images.txt`

---

## Image list file format (`*-images.txt`)

Each non-empty line is:

```text
<image-name>:<tag>
```

Example:

```text
msg-ems-all:10.4.0-95
tp-provisioner-agent:1.15.0
```

The script ignores blank lines, lines starting with `#`, and lines containing `*`.

---

## Execution Behavior

- **Copy**: Uses `docker buildx imagetools create` to copy images directly between registries
- **Command**: `docker buildx imagetools create --tag <TARGET>/<image:tag> <SOURCE>/<image:tag>`
- **Retry**: Configurable via `MAX_RETRY` (default: no retry) with `WAIT_BEFORE_RETRY` delay between attempts
- **Quiet Mode**: By default, buildx output is suppressed. Set `DOCKER_QUIET=false` to show output.

### Benefits of buildx approach

- **No local disk space needed**: Images are copied directly between registries without pulling locally
- **Preserves multi-arch manifests**: Multi-platform images remain intact during copy
- **Faster**: No intermediate download/upload steps

### Insecure (HTTP) Registries

For insecure HTTP registries, configure a buildx builder with insecure registry settings:

1. Create a buildx config file (e.g., `~/.docker/buildkitd.toml`):
   ```toml
   [registry."your-registry"]
     http = true
     insecure = true
   ```

2. Create a builder with this config:
   ```bash
   docker buildx create --name insecure-builder --config ~/.docker/buildkitd.toml --use
   ```

See [BuildKit TOML configuration](https://docs.docker.com/build/buildkit/toml-configuration/) for more details.

---

## Output

- Logs are optionally written to `image_sync_<YYYYMMDD_HHMMSS>.log` (when `WRITE_SCRIPT_LOGS_TO_FILE=true`)
- Summary includes:
  - Number of images copied successfully
  - Number of images failed to copy (with names)

---

# sync-charts.sh

`sync-charts.sh` is a **non-interactive** script driven by environment variables that:

- Pulls Helm charts from a source repository
- Pushes charts to either **ChartMuseum** or an **OCI registry**
- Reads chart lists from the `../../artifacts` directory

---

## Prerequisites

### Helm Version Requirements

| Helm Version | OCI Registry | ChartMuseum |
|--------------|--------------|-------------|
| **v3.17.0+** | ✅ Supported | ✅ Supported (requires `cm-push` plugin) |
| **v4.0.0+** | ✅ Supported | ❌ Not supported (`cm-push` plugin incompatible) |

- Helm must be installed (`helm` on PATH)
- Minimum version: **Helm v3.17.0**
- For **ChartMuseum pushes** (Helm v3 only): Helm plugin `helm-push` must be installed (provides `helm cm-push`)

Plugin install command (Helm v3 only):

```bash
helm plugin install https://github.com/chartmuseum/helm-push
```

> **Note:** If using Helm v4, you must use an OCI registry (`TARGET_REPO_URL=oci://...`). ChartMuseum is not supported with Helm v4. See [helm-push/issues/225](https://github.com/chartmuseum/helm-push/issues/225) for details.

---

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `SOURCE_REPO_NAME` | Name of the source Helm repository. If it exists in `helm repo list`, it will be updated. If not, the public TIBCO repo will be added with this name. |
| `RELEASE_VERSION` | Release version in `<major>.<minor>.<patch>` format (e.g., `1.15.0`) |
| `TARGET_REPO_URL` | Target repository URL. Use `oci://...` for OCI registries, otherwise treated as ChartMuseum URL. |

### Optional

| Variable | Description |
|----------|-------------|
| `CAPABILITY_NAME` | If set, only sync charts from `<CAPABILITY_NAME>-<RELEASE_VERSION>-charts.txt`. Otherwise, all `*-<RELEASE_VERSION>-charts.txt` files are used. |
| `TARGET_REPO_USERNAME` | Username for target repository authentication |
| `TARGET_REPO_PASSWORD` | Password for target repository authentication |
| `TARGET_REPO_NAME` | Helm repo name for ChartMuseum target (ignored for OCI). If not provided, uses `target-repo-temp`. |
| `TARGET_REPO_INSECURE` | If `true`, use `--plain-http` for OCI registries (for HTTP/insecure registries). Default: `false` |
| `WRITE_SCRIPT_LOGS_TO_FILE` | If `true`, writes logs to `chart_sync_<timestamp>.log`. Default: `false` |
| `MAX_RETRY` | Number of retries for pull/push operations. Default: `0` (no retry) |
| `WAIT_BEFORE_RETRY` | Seconds to wait before each retry. Default: `0` (no wait) |

---

## How to run

### Example 1: Sync all charts for a release to ChartMuseum (Helm v3 only)

```bash
export SOURCE_REPO_NAME="tibco-platform"
export RELEASE_VERSION="1.15.0"
export TARGET_REPO_URL="https://charts.example.com/api/charts"
export TARGET_REPO_NAME="my-chartmuseum"
export TARGET_REPO_USERNAME="admin"
export TARGET_REPO_PASSWORD="secret"

./sync-charts.sh
```

### Example 2: Sync specific capability to OCI registry

```bash
export SOURCE_REPO_NAME="tibco-platform"
export RELEASE_VERSION="1.15.0"
export CAPABILITY_NAME="control-plane"
export TARGET_REPO_URL="oci://registry.example.com/helm-charts"
export TARGET_REPO_USERNAME="user"
export TARGET_REPO_PASSWORD="token"

./sync-charts.sh
```

### Example 3: Sync to local HTTP registry with logging

```bash
export SOURCE_REPO_NAME="tibco-platform"
export RELEASE_VERSION="1.15.0"
export TARGET_REPO_URL="oci://localhost:5000/charts"
export TARGET_REPO_INSECURE="true"  # Required for HTTP registries
export WRITE_SCRIPT_LOGS_TO_FILE="true"

./sync-charts.sh
```

---

## Source Repository Behavior

The script checks if `SOURCE_REPO_NAME` exists in `helm repo list`:

- **If exists**: Runs `helm repo update <SOURCE_REPO_NAME>`
- **If not exists**: Adds `https://tibcosoftware.github.io/tp-helm-charts` with the given name and updates it

---

## Chart Selection

Charts are read from the `../../artifacts` directory.

**Note**: The `../../artifacts` directory must exist. If missing, clone the public repo:
- `https://github.com/TIBCOSoftware/tp-helm-charts`

### Default behavior (no CAPABILITY_NAME)

Searches for all files matching:
- `../../artifacts/*/<name>-<RELEASE_VERSION>-charts.txt`

### With CAPABILITY_NAME set

Uses only:
- `../../artifacts/<CAPABILITY_NAME>/<CAPABILITY_NAME>-<RELEASE_VERSION>-charts.txt`

---

## Chart list file format (`*-charts.txt`)

Each non-empty line is:

```text
<chart-name>:<version>
```

Example:

```text
tibco-cp-base:1.15.0-alpha.21
tp-dp-monitor-agent:1.15.218
```

The script ignores blank lines and lines starting with `#`.

---

## Target Repository Behavior

### OCI Registry (TARGET_REPO_URL starts with `oci://`)

- `TARGET_REPO_NAME` is ignored
- If `TARGET_REPO_USERNAME` and `TARGET_REPO_PASSWORD` are provided, performs `helm registry login`
- Pushes charts using `helm push <chart.tgz> <TARGET_REPO_URL>`

### ChartMuseum (TARGET_REPO_URL does not start with `oci://`)

- **Helm v3 only** (not supported with Helm v4)
- Requires `helm cm-push` plugin
- If `TARGET_REPO_NAME` is not provided, uses temporary name `target-repo-temp`
- If `TARGET_REPO_NAME` exists in helm repos:
  - **URL matches**: Updates the repo
  - **URL mismatch**: Exits with error
- If `TARGET_REPO_NAME` does not exist: Adds it with optional authentication
- Pushes charts using `helm cm-push <chart.tgz> <TARGET_REPO_NAME>`

---

## Cleanup

The script **always** cleans up:
- Removes `temp_charts/` directory after execution
- Removes `target-repo-temp` helm repo if it was created

---

## Output

- Console output shows progress and summary
- If `WRITE_SCRIPT_LOGS_TO_FILE=true`, logs are written to `chart_sync_<YYYYMMDD_HHMMSS>.log`
