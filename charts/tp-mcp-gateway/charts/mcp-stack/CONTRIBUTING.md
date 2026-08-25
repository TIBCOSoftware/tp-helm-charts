# Contributing to the mcp-stack sub-chart

`mcp-stack` is a **vendored sub-chart** of the TIBCO Platform MCP Gateway chart
(`tp-mcp-gateway`) and lives inside the `tp-helm-charts` repository. It is not a
standalone project — do not fork or clone it on its own.

## How to contribute

- Make changes in place under
  `charts/tp-mcp-gateway/charts/mcp-stack/` in `tp-helm-charts`, on a branch, and
  open a pull request following the standard `tp-helm-charts` review and release
  process.
- Bump the chart `version` in `Chart.yaml` for any chart change, and update the
  parent `tp-mcp-gateway` dependency pin accordingly.
- Validate locally before submitting: `helm lint charts/tp-mcp-gateway` and
  `helm template` the parent chart in full mode. Update `values.schema.json` and
  `CHANGELOG.md` when values or behaviour change.

## Provenance / keep-in-sync

This sub-chart is vendored from the upstream project
`github.com/IBM/mcp-context-forge` (chart path `charts/mcp-stack`) and is kept in
sync with it. TIBCO-local modifications carry in-file markers (e.g.
`KEEP-IN-SYNC` / "do not revert on upstream re-sync") — **preserve these markers**
when re-syncing from upstream so local changes are not lost.
