# Jaeger Upgrade Plan: 0.72.41 (v1) → 4.8.0 (v2)

## Overview

| | Old | New |
|---|---|---|
| **Chart Version** | 0.72.41 | 4.8.0 |
| **App Version** | 1.66.0 (Jaeger v1) | 2.18.0 (Jaeger v2) |
| **Architecture** | Microservices (collector, query, agent) | All-in-one unified container |
| **Config Format** | CLI flags + env vars | OTEL Collector-style YAML (`userconfig`) |
| **Image** | `o11y-jaeger-collector`, `o11y-jaeger-query` | `o11y-jaeger` (single image) |
| **Service Name** | `jaeger-collector`, `jaeger-query` (separate) | `jaeger` (unified) |
| **Default Storage** | cassandra | elasticsearch |

## What Changed

### Chart (`charts/jaeger-480/`)

**`templates/_helpers.tpl`** — Merged TIBCO-specific helpers:
- `jaeger.image.registry` / `jaeger.image.repository` — TIBCO container registry
- `jaeger.image` — produces `<registry>/<repo>/o11y-jaeger:<tag>`
- `jaeger.imagePullSecrets` — uses `global.cp.containerRegistry.secret`
- `jaeger.tibco.selectorLabels` — platform labels (`platform.tibco.com/workload-type`, `dataplane-id`, `capability-instance-id`)
- `isO11yv3` — detects o11yv3 resource mapping
- `collector.storage.type` / `query.storage.type` — resolves storage from o11yv3 config (localStore→memory, openSearch→elasticsearch)
- `jaeger.es.env` — injects ES credentials as env vars for `${env:...}` expansion in userconfig

**`templates/_capabilities.tpl`** — Ported from old chart (API version detection for HPA, Ingress, CronJob, NetworkPolicy)

**`templates/jaeger/jaeger-deploy.yaml`** — Added TIBCO customizations:
- Conditional deployment guard (o11yv3 exporter enabled OR o11y tracesServer enabled)
- TIBCO selector labels on pods
- TIBCO imagePullSecrets and registry image
- `enableResourceConstraints` guard on resources
- `rollId` annotation for forced restarts
- ES env var injection via `jaeger.es.env` helper
- External ServiceAccount support (`create: false` + `name`)

**`templates/jaeger/jaeger-service-account.yaml`** — Added `create: false` conditional

**`values.yaml`** — Added:
- `global.cp` block with full TIBCO platform values structure
- Hardened `podSecurityContext` (runAsNonRoot, seccompProfile: RuntimeDefault)
- Hardened `securityContext` (readOnlyRootFilesystem, drop ALL capabilities)

### Recipes (`charts/tibco-cp-base/charts/tp-cp-o11y/`)

**`values.yaml`** — `jaeger.version: "0.72.41"` → `"4.8.0"` (both default and withResources)

**`templates/o11y.yaml`** (default recipe, memory storage):
- package.json: consolidated 3 jaeger services → single `jaeger`
- Helm values: replaced collector/query/agent config with unified v2 config
- Storage: memory via `userconfig.extensions.jaeger_storage.backends.primary_store.memory`
- OTLP receivers on 4317 (gRPC) and 4318 (HTTP)

**`templates/o11y-exporter.yaml`** (exporter recipe, ES storage):
- package.json: same consolidation
- Helm values: replaced with v2 ES-backed config
- ES credentials: injected via env vars (`${env:ES_SERVER_URLS}`, `${env:ES_USERNAME}`, `${env:ES_PASSWORD}`)
- UI config: embedded via `uiconfig` values (TIBCO CP menu, linkPatterns)
- Query base path: `/o11y/v1/traceproxy/${DATAPLANE-ID}`

### o11y-service (`charts/o11y-service/`)

**`templates/_helpers.tpl`** — Collector endpoint: `jaeger-collector` → `jaeger`

**`values.yaml`** — Ingress service: `jaeger-query:80` → `jaeger:16686`

## Service Name Change

| Old Service | New Service | Port | Used By |
|---|---|---|---|
| `jaeger-collector` | `jaeger` | 4317 (OTLP gRPC), 4318 (OTLP HTTP) | OTEL collector pipeline |
| `jaeger-query` | `jaeger` | 16686 (Query UI) | Ingress, UI iframe |

All references updated atomically — no partial update window.

## ES Credential Flow (Exporter Recipe)

```
global.cp.resources.o11yv3.tracesServer.config.exporter.elasticSearch.endpoint
  → env var ES_SERVER_URLS (injected by jaeger-deploy.yaml via jaeger.es.env helper)
    → ${env:ES_SERVER_URLS} (resolved by Jaeger v2 in userconfig YAML)
      → jaeger_storage.backends.primary_store.elasticsearch.server_urls
```

## Trace Data Flow

```
App traces → OTEL Collector → jaeger:4317 (OTLP gRPC) → Jaeger v2 → Elasticsearch
                                                              ↓
                                          Ingress → jaeger:16686 (Query UI) → User
```

## Old Traces

No impact. Traces are stored in Elasticsearch indices. The new Jaeger v2 pod connects to the same ES cluster and reads the same indices.

## Testing Checklist

### Pre-deployment
- [ ] `helm template` dry-run renders correct manifests
- [ ] Image `o11y-jaeger:2.18.0` exists in TIBCO registry
- [ ] Elasticsearch cluster accessible from target namespace

### Post-deployment
- [ ] Pod `jaeger` is running (check `kubectl get pods -l app.kubernetes.io/component=all-in-one`)
- [ ] Service `jaeger` exists with ports 4317, 4318, 16686
- [ ] TIBCO labels present on pod (`platform.tibco.com/workload-type: infra`)
- [ ] Security context applied (runAsUser: 10001, readOnlyRootFilesystem: true)
- [ ] Health check passing (`curl jaeger:13133/status`)

### Trace ingestion
- [ ] OTEL collector config shows `JAEGER_COLLECTOR_ENDPOINT: jaeger.<ns>.svc.cluster.local:4317`
- [ ] Send test trace → appears in Jaeger UI
- [ ] Old traces from ES still queryable

### UI / Ingress
- [ ] Jaeger UI accessible via ingress path `/tibco/agent/o11y/{instanceId}/jaeger-query/`
- [ ] TIBCO CP menu links work (Home, Data Planes, Observability)
- [ ] linkPatterns for app_id navigation work

### Resource / Scaling
- [ ] Resource limits applied (200m/256Mi req, 1000m/1024Mi limit) — exporter recipe only
- [ ] Pod restarts cleanly (delete pod, verify new pod starts)

## Not Updated (Follow-up)

- Recipe variants: `o11y_1.yaml`, `o11y-exporter_1.yaml`, `o11y-exporter2.yaml`, `o11y-backup.yaml`
- `tp-cp-o11y-ohc` chart (similar recipes)
- Directory rename: `charts/jaeger-480/` → `charts/jaeger/` (after validation)
- Cleanup: remove old `charts/jaeger/` directory
