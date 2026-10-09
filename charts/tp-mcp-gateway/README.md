# tp-mcp-gateway

TIBCO Platform **MCP Gateway** — the Data Plane component that exposes MCP (Model Context
Protocol) servers discovered on a Data Plane, and federates them to the Control Plane's MCP Hub.

One optional instance per Data Plane. Deployed and configured from MCP Hub; this chart is also
installable directly.

---

## Modes

The chart ships two mutually exclusive runtime shapes. Pick one — they differ in their datastore,
not just in scale.

| | **Full** (chart default) | **Lite** |
|---|---|---|
| Datastore | PostgreSQL + Redis, via the vendored `mcp-stack` sub-chart | SQLite + in-memory cache |
| Pods | gateway + `mcp-stack` workloads | single gateway pod |
| External dependencies | yes | none |
| Set | `mcp-stack.enabled: true` (default) | `lite.enabled: true`, `mcp-stack.enabled: false` |

`mcp-stack` is a **vendored** dependency (`repository: file://charts/mcp-stack`), so it travels
inside the packaged `.tgz`. Installing this chart needs no other chart repository.

## Values overlays

Three overlays ship **inside** the chart, alongside `values.yaml`. Each is a small delta, not a
complete values file.

| Overlay | Use |
|---|---|
| `values-cp.yaml` | Control-Plane-managed Data Plane: Lite mode, discovery + tibco-proxy on |
| `values-lite.yaml` | Lite mode, nothing else changed |
| `values-standalone.yaml` | Lite mode with authentication disabled, discovery off — **local evaluation only** |

Because they ship inside the chart, `-f values-lite.yaml` only resolves if the file is on your
disk. Add the chart repository and unpack the chart first:

```sh
helm repo add tibco <chart-repo-url>     # the TIBCO chart repository you have access to
helm repo update
helm pull tibco/tp-mcp-gateway --version 1.21.0 --untar
# -> ./tp-mcp-gateway/values-lite.yaml
```

`tibco` is just the local alias for that repository; the commands below assume it.

> `values-standalone.yaml` sets `AUTH_REQUIRED: "false"`, `MCP_REQUIRE_AUTH: "false"`,
> `ALLOW_UNAUTHENTICATED_ADMIN: "true"` and `ALLOWED_ORIGINS: '["*"]'`. It is not a production
> posture — it exists so the gateway can be run without a Control Plane.

## Components and images

Four first-party images, all built from
[`tibco/tp-mcp-gateway`](https://github.com/tibco/tp-mcp-gateway):

| Component | Image (`*.image.repository`) | Role |
|---|---|---|
| Gateway | `tp-mcp-gateway` | the MCP gateway itself (`lite.image`, and the `mcp-stack` migration / context-forge positions) |
| Discovery | `tp-mcp-discovery` | finds MCP-capable apps on the Data Plane |
| Proxy | `tp-mcp-gateway-proxy` | ingress/egress proxy, external and CP-internal listeners |
| Dial-home agent | `tp-mcp-gateway-dialhome-agent` | registers the gateway back to the Control Plane |

Image pins are **tag-only at GA**: every `digest:` is deliberately empty. Digests are populated
only on the alpha lane, by the release automation; a hand-cut GA has no equivalent pinner.

## Registry access — required, no usable default

Image references are assembled from `global.cp.containerRegistry`, and **two of its defaults are
empty on purpose**, so the chart does not ship a hardcoded registry host or credential:

| key | default | effect if left unset |
|---|---|---|
| `global.cp.containerRegistry.url` | `""` | renders `image: "/tibco-platform-docker-prod/tp-mcp-gateway:1.21.0"` — a hostless reference that cannot be pulled |
| `global.imagePullSecrets` | `[]` | no credential is attached; a private registry returns 401 |

`global.imagePullSecrets` is a list of **bare Secret names**, not of objects — set it as
`global.imagePullSecrets[0]=<name>`. The `[0].name=<name>` form renders
`- name: map[name:<name>]`, which names no real Secret and fails as an `ImagePullBackOff`
*after* a successful `helm install`.

A Control Plane supplies both. Installing this chart **directly** you must supply them yourself.
`repository` defaults to `tibco-platform-docker-prod`; override it if you pull from elsewhere.

## Requirements

- Kubernetes **≥ 1.22** (`kubeVersion: ">=1.22.0-0"`) — required by `ReadWriteOncePod`.
- Full mode additionally needs whatever storage class `mcp-stack`'s PostgreSQL requests.

## Install

```sh
# Lite — no external datastore
helm install mcp-gateway tibco/tp-mcp-gateway --version 1.21.0 \
  -f tp-mcp-gateway/values-lite.yaml \
  --set global.cp.containerRegistry.url=<registry-host> \
  --set global.imagePullSecrets[0]=<pull-secret-name>

# Full — PostgreSQL + Redis via the vendored mcp-stack
helm install mcp-gateway tibco/tp-mcp-gateway --version 1.21.0 \
  --set global.cp.containerRegistry.url=<registry-host> \
  --set global.imagePullSecrets[0]=<pull-secret-name>
```

Confirm the references resolve before installing:

```sh
helm template mcp-gateway tibco/tp-mcp-gateway --version 1.21.0 \
  --set global.cp.containerRegistry.url=<registry-host> | grep 'image:'
```

Every line must carry a registry host. A leading `/` means `url` is still unset.

### External PostgreSQL

Full mode can point at an existing database instead of the bundled one, under
`mcp-stack.postgres.external`. See the commentary in `values.yaml` for the exact keys and which
of them are required together.

## Upgrading

Do **not** use `helm upgrade --reuse-values` for a chart-version change. `--reuse-values` reuses
the *coalesced* values from the previous release, so defaults that moved in the new chart —
including image pins — are silently discarded and the upgrade reports success. Use `-f` with your
own values file, or `--reset-then-reuse-values`.

## Related

- MCP Hub (Control Plane console): chart `tibco-cp-mcp-hub`
- Gateway source: <https://github.com/tibco/tp-mcp-gateway>
