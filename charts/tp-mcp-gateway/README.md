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
| Datastore | PostgreSQL (**external by default**; the bundled one is opt-in) + Redis, via the vendored `mcp-stack` sub-chart | SQLite + in-memory cache |
| Pods | gateway + `mcp-stack` workloads | single gateway pod |
| External dependencies | yes | none |
| Set | `mcp-stack.enabled: true` (default), plus a database choice — see **Install** | `lite.enabled: true`, `mcp-stack.enabled: false` |

`mcp-stack` is a **vendored** dependency (`repository: file://charts/mcp-stack`), so it travels
inside the packaged `.tgz`. Installing this chart needs no other chart repository.

## Values overlays

Four overlays ship **inside** the chart, alongside `values.yaml`. Each is a small delta, not a
complete values file.

| Overlay | Use |
|---|---|
| `values-cp.yaml` | Control-Plane-managed Data Plane: Lite mode, discovery + tibco-proxy on |
| `values-cp-platform.yaml` | The gateway installed **inside the Control Plane's own cluster** (the platform gateway). Not for a Data Plane, and not the normal path — see the note below the table |
| `values-lite.yaml` | Lite mode, nothing else changed |
| `values-standalone.yaml` | Lite mode with authentication disabled, discovery off — **local evaluation only** |

`values-cp.yaml` and `values-cp-platform.yaml` are one word apart and describe **different
clusters**: `values-cp.yaml` means *installed BY the Control Plane onto a Data Plane*, `values-cp-platform.yaml`
means *installed IN the Control Plane*. For the platform gateway the chart is normally a subchart of
`tibco-cp-mcp-hub`, and Helm cannot feed a `-f` profile to a subchart, so that overlay is only for a
direct install.

Because they ship inside the chart, `-f values-lite.yaml` only resolves if the file is on your
disk. Add the chart repository and unpack the chart first:

```sh
helm repo add tibco <chart-repo-url>     # the TIBCO chart repository you have access to
helm repo update
helm pull tibco/tp-mcp-gateway --version 1.22.4 --untar
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

Full mode additionally pulls the mirrored third-party images `common-redis-official` and, with the
bundled PostgreSQL, `common-postgres` from the same registry, so mirror those as well.

Image pins are **tag-only at GA**: every `digest:` is deliberately empty. Digests are populated
only on the alpha lane, by the release automation; a hand-cut GA has no equivalent pinner.

## Registry access — required, no usable default

Image references are assembled from `global.cp.containerRegistry`, and **two of its defaults are
empty on purpose**, so the chart does not ship a hardcoded registry host or credential:

| key | default | effect if left unset |
|---|---|---|
| `global.cp.containerRegistry.url` | `""` | renders `image: "/tibco-platform-docker-prod/tp-mcp-gateway:1.22.2"` — a hostless reference that cannot be pulled |
| `global.imagePullSecrets` | `[]` | no credential is attached; a private registry returns 401 |

`global.imagePullSecrets` is a list of **bare Secret names**, not of objects — set it as
`global.imagePullSecrets[0]=<name>`. The `[0].name=<name>` form renders
`- name: map[name:<name>]`, which names no real Secret and fails as an `ImagePullBackOff`
*after* a successful `helm install`.

A Control Plane supplies both. Installing this chart **directly** you must supply them yourself.
`repository` defaults to `tibco-platform-docker-prod`; override it if you pull from elsewhere.

## Requirements

- Kubernetes **≥ 1.22** (`kubeVersion: ">=1.22.0-0"`). In **Full** mode the bundled PostgreSQL and Redis
  volume claims request `ReadWriteOncePod` by default, which Kubernetes enables by default only from
  1.27. On an older cluster set `mcp-stack.postgres.persistence.useReadWriteOncePod=false` and
  `mcp-stack.redis.persistence.useReadWriteOncePod=false`. Lite mode uses a plain `ReadWriteOnce` volume.
- **Both modes create PersistentVolumeClaims** (Lite: 1Gi for SQLite; Full: Redis 3Gi, plus PostgreSQL
  5Gi when bundled) without a `storageClassName`, so the cluster needs a default StorageClass.

## Install

```sh
# Lite — no external datastore
helm install mcp-gateway tibco/tp-mcp-gateway --version 1.22.4 \
  -f tp-mcp-gateway/values-lite.yaml \
  --set global.cp.containerRegistry.url=<registry-host> \
  --set global.imagePullSecrets[0]=<pull-secret-name>

# Full, with the BUNDLED PostgreSQL + Redis from the vendored mcp-stack.
# Create the credential Secret first (see below) -- do NOT rely on the chart's default password.
helm install mcp-gateway tibco/tp-mcp-gateway --version 1.22.4 \
  --set mcp-stack.postgres.enabled=true \
  --set mcp-stack.postgres.external.enabled=false \
  --set mcp-stack.postgres.existingSecret=<postgres-secret-name> \
  --set global.cp.containerRegistry.url=<registry-host> \
  --set global.imagePullSecrets[0]=<pull-secret-name>
```

**Full mode needs a database, and the chart default does not provide one.** Out of the box
`mcp-stack.postgres.enabled` is `false` and `mcp-stack.postgres.external.enabled` is `true` with an
**empty** host and no credential, so a Full install with only the registry settings has neither a
database nor a usable connection to one. Either enable the bundled PostgreSQL as above, or supply a
complete external connection (next section).

**Do not deploy the bundled PostgreSQL with its default credential.** Left alone, the chart creates
the database user `admin` with the published password `test123` (the chart's own comment says
"CHANGE ME in production"), and the Secret is built straight from those values; nothing generates a
random one. Pre-create a Secret with a unique password and point `mcp-stack.postgres.existingSecret`
at it, as in the example above:

```sh
kubectl create secret generic <postgres-secret-name> \
  --from-literal=POSTGRES_USER=<user> \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)" \
  --from-literal=POSTGRES_DB=postgresdb
```

With `existingSecret` set the chart renders no credential Secret of its own. The gateway and the
migration Job read `POSTGRES_USER` / `POSTGRES_PASSWORD` from yours, and the PostgreSQL pod reads all
three keys. **`POSTGRES_DB` must be `postgresdb`**: the gateway and the migration Job connect to that
fixed name (`mcp-stack.mcpContextForge.env.postgres.db`), not to the value in your Secret, so any other
name creates a database nothing connects to. To use another name, set
`mcp-stack.mcpContextForge.env.postgres.db` to the same value as `POSTGRES_DB`.
`values-standalone.yaml` is the only profile that is meant to run on defaults, and it is for local
evaluation only.

Confirm the references resolve before installing:

```sh
helm template mcp-gateway tibco/tp-mcp-gateway --version 1.22.4 \
  --set global.cp.containerRegistry.url=<registry-host> | grep 'image:'
```

Every line must carry a registry host. A leading `/` means `url` is still unset.

### External PostgreSQL

External PostgreSQL is the **chart default** for Full mode, but it ships with no host and no
credential on purpose, so you must supply them: `mcp-stack.postgres.external.host`, and either
`existingSecret` or an explicit `user` / `password`. See the commentary in `values.yaml` for the
exact keys and which of them are required together. To use the bundled PostgreSQL instead, set
`mcp-stack.postgres.enabled=true` and `mcp-stack.postgres.external.enabled=false`.

## Upgrading

Do **not** use `helm upgrade --reuse-values` for a chart-version change. `--reuse-values` reuses
the *coalesced* values from the previous release, so defaults that moved in the new chart —
including image pins — are silently discarded and the upgrade reports success. Use `-f` with your
own values file, or `--reset-then-reuse-values`.

### Public endpoint is an allowlist by default (new in 1.22)

From 1.22 the public endpoint publishes an **allowlist** of paths rather than the whole
`<pathPrefix>/` prefix: the documented MCP client paths, the RFC 9728 OAuth protected-resource
discovery document and the approved OAuth paths. `/admin`, `/rpc`, `/tools`, `/gateways` and the
rest of the management surface are **no longer routed** on the public edge.

**This is a reduction of the public surface, not an isolation boundary — do not rely on it as one.**
It is enforced per controller, and the strength differs:

- **Gateway API controllers that implement only the Core conformance tier** (the GKE gateway
  included) cannot express a wildcard path segment, so a **Lite** gateway is routed at
  `<pathPrefix>/servers` with a `PathPrefix` match. The bare server list and the per-server REST
  sub-resources therefore **remain publicly routed** for a Lite gateway; a Full gateway publishes no
  `<pathPrefix>/servers` rule there (see "Public access and the Full mode" below). ISTIO and
  NGINX_GATEWAY_FABRIC use a stricter regex allowlist.
- NGINX Ingress enforces a regex allowlist. HAProxy Ingress enforces its allowlist through a controller
  snippet annotation: if the controller rejects that snippet the Ingress still looks correct but
  `<pathPrefix>/servers` becomes publicly routed, so alert on the controller log line
  `unable to Sync HAProxy configuration`.
- Traefik is allowlisted too, but has **no switch** to turn that off.
- OpenShift router (`global.cp.resources.ingress.ingressController: openshiftRouter`, new in 1.22.2)
  renders one public `Route` per allowlisted path. A Route carries a single path, so this edge cannot
  express a wildcard segment either: like the Core tier above, for a **Lite** gateway the bare
  `<pathPrefix>/servers` list and the per-server REST sub-resources **remain publicly routed**, and the
  router forwards `..` and `%2F` inside a published prefix without normalising it. A Full gateway gets no
  `<pathPrefix>/servers` Route (see "Public access and the Full mode" below). There is no switch to turn
  the allowlist off. The
  edge needs `global.cp.resources.ingress.fqdn` set to a lowercase DNS name without a wildcard (all the
  Routes share that host), and it refuses a `haproxy.router.openshift.io/rewrite-target` annotation in
  `global.cp.resources.ingress.annotations`. Both are render errors that name the key.

Three switches under `publicApi`, all defaulting to `true`, restore the previous behaviour **only**
for the controller they name:

| key | what `false` does |
|---|---|
| `publicApi.nginxAllowlistEnabled` | NGINX Ingress serves the whole `<pathPrefix>/` prefix again |
| `publicApi.haproxyAllowlistEnabled` | HAProxy Ingress serves the whole prefix again |
| `publicApi.gatewayApiAllowlistEnabled` | restores blanket routing for the **Core-conformance tier only**; ISTIO and NGINX_GATEWAY_FABRIC keep their regex allowlist regardless; refused for a Full gateway |

If you reach `/admin` or the REST API over the public edge today, that stops working after the
upgrade. Set a key to `false` **only** to restore the previous behaviour, and prefer a narrower fix
first: a dedicated `HTTPRoute` of your own for the one path you need. Reaching the admin console
through the Control Plane uses the private tunnel and is unaffected either way. See the commentary
at each key in `values.yaml`.

### Public access and the Full mode

On the OpenShift router and on Gateway API controllers other than Istio and NGINX Gateway Fabric, a
Full gateway is not published on the public endpoint; it is reachable on the private path (Control
Plane, in-cluster clients). Use a Lite gateway, or a supported Ingress controller, for public MCP
access. Its OAuth callback and authorize routes and its OAuth discovery routes are still published.

Why: those two edges can only express a path prefix, so they cannot publish a gateway's per-server MCP
endpoints without also publishing its server registry paths, which belong to the private path. A Lite
gateway keeps its public MCP route on those edges as before. On those Gateway API controllers a Full
gateway also refuses `publicApi.gatewayApiAllowlistEnabled=false`, which would publish the whole gateway
prefix; `helm upgrade --reuse-values` carries a previous `false` over, so pass
`--set publicApi.gatewayApiAllowlistEnabled=true` (or drop the key). The edges that can express the exact
per-server path (traefik, nginx, haProxy, and Gateway API on Istio or NGINX Gateway Fabric) publish a Full
gateway's MCP endpoints as before. The guard is `dev/mcp-gateway-render-tests/full-gw-public-edge-assert.sh`
(PCP-26950).

### Unknown ingress controller values fail the render (new in 1.22.2)

`global.cp.resources.ingress.ingressController` is matched case-insensitively. `haProxy`, `nginx`,
`traefik` and `openshiftRouter` each render a public edge; `kong` is accepted, but this chart renders
**no** public route for it yet (PCP-26720). Any other non-empty value now fails `helm upgrade` with an
error that names the value. Before 1.22.2 such a value rendered no public entry point and no error, and
the gateway still reported ONLINE. An empty value is accepted and renders no Ingress-family public edge
(Gateway API is selected independently), so a values file that leaves the key unset is unaffected.

## Related

- MCP Hub (Control Plane console): chart `tibco-cp-mcp-hub`
- Gateway source: <https://github.com/tibco/tp-mcp-gateway>
