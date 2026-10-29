# MCP Gateway — mcp-stack sub-chart (TIBCO Platform)

`mcp-stack` is the full-stack sub-chart bundled by the TIBCO Platform MCP Gateway
chart (`tp-mcp-gateway`). It deploys the MCP Gateway application (HTTP / WebSocket
server) together with its backing services: a PostgreSQL database (persistent
storage), a Redis cache (sessions & completions), and optional PgAdmin and
Redis-Commander web UIs.

This sub-chart is not deployed on its own. It is a dependency of the parent
`tp-mcp-gateway` chart, which selects Full mode (this stack) or Lite mode
(single-pod SQLite + in-memory cache). See the parent chart `tp-mcp-gateway` for
deploy modes, and this chart's `values.yaml` / `values.schema.json` for the full
list of configuration values.

> Provenance: `mcp-stack` is vendored from the upstream project
> `github.com/IBM/mcp-context-forge` (chart path `charts/mcp-stack`) and is kept
> in sync with it. TIBCO-local modifications carry in-file markers so upstream
> re-syncs can preserve them.

**GitOps / client-side rendering (ArgoCD, Flux, a bare `helm template`):** the bundled
Redis password (`redis.auth.password`) is generated once and kept via a live-cluster
`lookup` on every `helm install`/`helm upgrade` — see `templates/secret-redis.yaml`.
A client-side renderer has no cluster to look up against, so it mints a *fresh*
password on every render. Both `deployment-redis.yaml` and
`deployment-mcpgateway.yaml` carry a `checksum/redis-secret` annotation computed
from that same password, so Redis and the gateway always roll together when it
changes — they never end up on two different passwords. Under GitOps auto-sync
this means: **every sync renders a new password, and every sync restarts both
Redis and the gateway.** The OutOfSync badge and the drift are cosmetic; the
repeated restart of two Deployments on every reconciliation is not — budget for
it like any other workload whose pod spec changes every sync. Set
`redis.auth.existingSecret` to an operator-managed Secret for a stable GitOps
install with no restarts (same requirement as `redis.serverTls.existingSecret`,
PCP-20275), or configure your tool's own diff-ignore for this Secret's data if
the restarts are acceptable for your deployment.
