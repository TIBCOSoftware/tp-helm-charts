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
