<!--
 Copyright (c) 2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
-->

# tp-dp-infra-mcp-server

TIBCO® Platform Infra Model Context Protocol (MCP) Server for data plane. Provides read-only kubectl
and helm command execution via [MCP protocol](https://modelcontextprotocol.io/)
for AI-driven root cause analysis (TESSA).

## Overview

The TIBCO® Platform Infra Model Context Protocol (MCP) Server runs on each data plane and exposes two interfaces:

| Port | Protocol | Purpose |
|------|----------|---------|
| 8091 (REST) | HTTP | REST API for kubectl/helm command execution |
| 8092 (MCP)  | MCP  | Model Context Protocol for AI assistant integration |

TESSA (TIBCO AI assistant) on the control plane reaches the MCP server
through the dp-proxy pipeline:

```
TESSA -> platform-mcp-server (CP) -> dp-proxy -> HAProxy Ingress (DP) -> infra-mcp-server (DP)
```

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Kubernetes | >= 1.21.0 |
| Helm | >= 3.14 |
| `dp-configure-namespace` chart | Installed in each DP namespace (creates RBAC) |
| `dp-core-infrastructure` chart | >= 1.15.0 |

## Installation

This chart is deployed as a platform capability through the TIBCO Platform
Control Plane. It is not typically installed manually.

To provision via the CP UI:
1. Navigate to **Data Planes > Capabilities > Add Capability**
2. Select **TIBCO® Platform Infra Model Context Protocol (MCP) Server**
3. Configure service account and logging options
4. Review the recipe YAML and provision

### Manual installation (dev/test)

```bash
helm install tp-dp-infra-mcp-server charts/tp-dp-infra-mcp-server \
  --namespace <dp-namespace> \
  --set global.cp.dataplaneId=<dataplane-id> \
  --set global.cp.instanceId=<instance-id> \
  --set global.cp.containerRegistry.url=<registry-url> \
  --set image.tag=<image-tag>
```

## Architecture

### Charts involved

Two charts collaborate to deploy the infra-mcp-server:

| Chart | Responsibility | When it runs |
|-------|---------------|--------------|
| `dp-configure-namespace` | Creates RBAC (Role/ClusterRole + Bindings) and a provisioner Role | Data plane bootstrap (before any capability) |
| `tp-dp-infra-mcp-server` | Creates ServiceAccount (unless BYOSA), Deployment, Service, Ingress | Capability provisioning |

This separation ensures RBAC is managed by infrastructure operators while
the capability chart only handles workload resources.

### Resources created by this chart

| Resource | Name | Description |
|----------|------|-------------|
| Deployment | `tp-dp-infra-mcp-server` | Single-replica pod with REST + MCP ports |
| Service | `tp-dp-infra-mcp-server` | ClusterIP with ports `rest` (80->8091) and `mcp` (8092->8092) |
| ServiceAccount | `tp-dp-infra-mcp-server` | Created when `serviceAccount.create: true` |
| ConfigMap | `tp-dp-infra-mcp-server-config` | kubectl/helm security policies (allowlists) |
| Ingress (HAProxy) | `haproxy-infra-mcp-server` | Private CP-to-DP ingress to the REST service port (default; replaced by a custom-controller route when `global.cp.routeResources` selects one — see [Custom routing](#custom-routing-globalcprouteresources)) |
| FluentBit ConfigMap | `tp-dp-infra-mcp-server-fluentbit-config` | Optional sidecar logging config |

## Service Account & RBAC

Three modes are supported. See [docs/service-account-design.md](docs/service-account-design.md) for detailed diagrams.

### Mode 1 -- Default (namespace-scoped)

Standard deployment. Pod can read resources within its data plane namespace(s).

```yaml
# dp-configure-namespace values
rbac:
  infraMcp: true
  infraMcpClusterScoped: false       # namespace-scoped (default)

# tp-dp-infra-mcp-server values
serviceAccount:
  create: true                     # chart creates SA (default)
```

### Mode 2 -- Cluster-scoped

Full cluster diagnostics. Pod can read resources across all namespaces.

```yaml
# dp-configure-namespace values
rbac:
  infraMcp: true
  infraMcpClusterScoped: true        # cluster-wide access

# tp-dp-infra-mcp-server values
serviceAccount:
  create: true
```

### Mode 3 -- BYOSA (Bring Your Own Service Account)

Customer pre-creates their own SA with custom RBAC.

```yaml
# dp-configure-namespace values
rbac:
  infraMcp: false                    # skip RBAC creation

# tp-dp-infra-mcp-server values
serviceAccount:
  create: false                    # don't create SA
  name: "my-custom-sa"            # use pre-existing SA
```

### RBAC permissions (Modes 1 & 2)

The read-only Role/ClusterRole grants access to:

| API Group | Resources | Verbs |
|-----------|-----------|-------|
| `""` (core) | pods, pods/log, services, endpoints, configmaps, secrets, events, PVCs | get, list, watch |
| `apps` | deployments, replicasets, statefulsets, daemonsets | get, list, watch |
| `batch` | jobs, cronjobs | get, list, watch |
| `autoscaling` | horizontalpodautoscalers | get, list, watch |
| `networking.k8s.io` | ingresses, networkpolicies | get, list, watch |
| `metrics.k8s.io` | pods (+ nodes in cluster-scoped) | get, list |

Additional resources in cluster-scoped mode: `namespaces`, `nodes`.

Custom rules can be appended via `rbac.infraMcpExtraRules` in dp-configure-namespace.

### Multi-namespace data planes

When a data plane spans multiple namespaces, `dp-configure-namespace` creates
a Role + RoleBinding in **every** DP namespace. Additional namespaces use
cross-namespace subject references to point to the SA in the primary namespace:

```yaml
# RoleBinding in additional namespace
subjects:
- kind: ServiceAccount
  name: tp-dp-infra-mcp-server
  namespace: <primary-namespace>    # cross-namespace reference
```

## Security

### Command allowlisting

The ConfigMap defines strict allowlists for kubectl and helm:

| Tool | Allowed | Blocked |
|------|---------|---------|
| kubectl | `get`, `describe`, `logs` | `delete`, `create`, `apply`, `patch`, `edit`, `replace`, `exec`, `drain`, `cordon`, `taint` |
| helm | `list`, `status`, `get`, `history` | `install`, `upgrade`, `uninstall`, `delete`, `rollback` |

### Pod security

- Runs as non-root (UID 1000)
- Read-only root filesystem
- All capabilities dropped
- Seccomp profile: RuntimeDefault
- No privilege escalation

### Provisioner Role (least-privilege)

The `dp-configure-namespace` chart creates a provisioner Role that allows
the shared DP service account to manage only the infra-mcp-server's SA:

- `create` -- unrestricted (Kubernetes limitation: `resourceNames` doesn't apply to create)
- `get`, `update`, `delete` -- restricted to the specific SA name via `resourceNames`

## Configuration

### Key values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `serviceAccount.create` | `true` | Create a dedicated ServiceAccount |
| `serviceAccount.name` | `""` | Override SA name (defaults to chart fullname) |
| `image.name` | `infra-mcp-server` | Container image name (no `tp-` prefix; PCP-23235) |
| `image.tag` | `"121"` | Container image tag — moves with `image.name` |
| `config.LOG_LEVEL` | `"info"` | Application log level |
| `config.KUBECTL_TIMEOUT` | `"30"` | kubectl command timeout (seconds) |
| `config.HELM_TIMEOUT` | `"30"` | helm command timeout (seconds) |
| `haproxy.enabled` | `true` | Enable the bundled HAProxy ingress for CP-to-DP routing |
| `haproxy.pathPrefix` | `/tibco/agent/integration/infra-mcp-server` | HAProxy path prefix (bundled HAProxy route only) |
| `imagePullSecret` | `""` | Name of a pre-existing image-pull Secret. Break-glass override for a manual `helm upgrade`; see below |
| `global.cp.containerRegistry.secret` | `""` | Pull-secret name supplied by the platform. When empty the `imagePullSecrets` key is omitted entirely |
| `global.cp.logging.fluentbit.enabled` | `false` | Enable FluentBit sidecar for log shipping |
| `global.cp.enableResourceConstraints` | `true` | Apply CPU/memory limits |

### Custom routing (`global.cp.routeResources`)

The private control-plane to data-plane route is selected by `global.cp.routeResources`, which the
orchestrator injects per data plane. The routed path is a configurable prefix plus this capability's
fixed tail `/integration/infra-mcp-server`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `global.cp.routeResources.pathPrefix` | `/tibco/agent` | Configurable routing prefix |
| `global.cp.routeResources.ingress.ingressController` | `""` | `""` (bundled HAProxy) \| `haProxy` \| `nginx` \| `traefik` \| `openshiftRouter` |
| `global.cp.routeResources.ingress.ingressClassName` | `""` | Required when `ingressController` is non-empty and not the bundled HAProxy |
| `global.cp.routeResources.ingress.fqdn` | `""` | Route host, required when `ingressController` is set |
| `global.cp.routeResources.ingress.annotations` | `{}` | User annotations, added to the controller defaults |
| `global.cp.routeResources.gatewayapi.gatewayAPIControllerName` | `""` | Non-empty selects Gateway API and renders an `HTTPRoute` |
| `global.cp.routeResources.gatewayapi.gatewayName` / `.gatewayNamespace` | `""` | Parent `Gateway` reference |
| `global.cp.routeResources.gatewayapi.gatewayHostOrDomainName` | `""` | `HTTPRoute` hostname |
| `global.cp.routeResources.gatewayapi.gatewaySectionName` | `""` | Optional `Gateway` listener section |

| Selection | Object(s) rendered |
|-----------|--------------------|
| both empty (default) | `Ingress` `haproxy-infra-mcp-server` — unchanged from previous releases |
| `ingressController: haProxy` | `Ingress` `haproxy-tp-dp-infra-mcp-server` |
| `ingressController: nginx` | `Ingress` `nginx-tp-dp-infra-mcp-server` |
| `ingressController: traefik` | `Middleware` `tp-dp-infra-mcp-server-strip-prefix` + `Ingress` `traefik-tp-dp-infra-mcp-server` |
| `ingressController: openshiftRouter` | `Route` `im-tp-dp-infra-mcp-server` |
| `gatewayAPIControllerName` non-empty | `HTTPRoute` `im-tp-dp-infra-mcp-server` |

The default render is unchanged when `routeResources` is left at its defaults, so existing data planes
are unaffected. `haproxy.enabled: false` suppresses the route in every mode. This follows the same
shape as the other capability charts carrying this contract (`artifactmanager`, `o11y-service`).
### Container registry pull secret

This chart is a name consumer only -- it never sees registry credentials. On a data plane,
`dp-configure-namespace` mints the `kubernetes.io/dockerconfigjson` Secret from
url/username/password, names it after the data plane id, and the orchestrator injects only that
NAME here. The name is resolved in this order:

1. `imagePullSecret`
2. `global.cp.containerRegistry.secret` -- the data-plane wiring, and the only arm that fires in production
3. `global.tibco.containerRegistry.secret` -- the control-plane spelling
4. `global.tibco.containerRegistry.username` + `.password` -> `tibco-container-registry-credentials`
5. nothing resolves -> the `imagePullSecrets` key is omitted entirely (anonymous pull)

Arms 3 and 4 read the control-plane spelling and cannot fire on a data plane, where the
orchestrator injects only `global.cp`. They exist so the resolver is complete for a control-plane
or standalone values render. **Do not reach for arm 4 to fix a data-plane pull failure** -- the
Secret it names is a control-plane Secret that does not exist in a data-plane namespace, so naming
it is strictly worse than arm 5 omitting the key.

`imagePullSecret` (arm 1) is a break-glass override for a manual `helm upgrade`, which does happen
during development and support triage. It is **not** a supported way to configure a data plane: the
capability release is orchestrator-managed, so the value survives only until the next
orchestrator-driven upgrade reconciles the release. To change the pull secret durably, set it on
the data plane through the control plane (*Update Container Registry -> Kubernetes secret*), which
propagates to `global.cp.containerRegistry.secret`.

### Resource constraints

When `global.cp.enableResourceConstraints: true` (default):

| Container | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| infra-mcp-server | 100m | 500m | 128Mi | 512Mi |
| fluentbit (optional) | 10m | 50m | 15Mi | 30Mi |

## Observability

When `global.cp.logging.fluentbit.enabled: true`, a FluentBit sidecar is
added to the pod. It collects application logs and ships them to the
OpenTelemetry collector at `otel-services.<namespace>.svc.cluster.local:4318`.

## Recipe registration

The capability is registered in the CP via a recipe in `tp-cp-configuration`.
Capability name: `inframcpserver`. Provisioning role: `DEV_OPS`.

The recipe includes:
- Chart version and image tag references
- Data plane identity variables (`${DATAPLANE_ID}`, `${NAMESPACE}`)
- Service account configuration from the provisioning UI
- Optional FluentBit sidecar configuration

## Related resources

- [Service Account & RBAC Design](docs/service-account-design.md) -- detailed RBAC design with diagrams
- [dp-configure-namespace](../dp-configure-namespace/) -- infrastructure chart that creates RBAC
- [MCP Protocol specification](https://modelcontextprotocol.io/)
