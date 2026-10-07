<!-- 
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

# dp-config-opensearch

Helm chart to configure OpenSearch cluster and OpenSearch Dashboards for TIBCO Data Plane.

## Description

This chart deploys:
- **OpenSearch** - A distributed search and analytics engine (fork of Elasticsearch)
- **OpenSearch Dashboards** - Visualization and user interface for OpenSearch (fork of Kibana)

Both components are deployed using official OpenSearch Helm charts as dependencies.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for persistence)

## Installation

### Add Helm repository dependencies

```bash
helm dependency update
```

### Install the chart

```bash
helm install dp-config-opensearch . -n <namespace> --create-namespace
```

### Install with custom values

```bash
helm install dp-config-opensearch . -n <namespace> -f custom-values.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `opensearch.enabled` | Enable OpenSearch deployment | `true` |
| `opensearch.clusterName` | OpenSearch cluster name | `opensearch-cluster` |
| `opensearch.replicas` | Number of OpenSearch replicas | `3` |
| `opensearch.resources` | Resource requests/limits for OpenSearch | See values.yaml |
| `opensearch.persistence.enabled` | Enable persistence for OpenSearch | `true` |
| `opensearch.persistence.size` | PVC size for OpenSearch | `10Gi` |
| `opensearch.ingress.enabled` | Enable ingress for OpenSearch | `true` |
| `opensearch-dashboards.enabled` | Enable OpenSearch Dashboards | `true` |
| `opensearch-dashboards.replicaCount` | Number of Dashboards replicas | `1` |
| `opensearch-dashboards.ingress.enabled` | Enable ingress for Dashboards | `true` |
| `domain` | Base domain for ingress hosts | `""` |

### Ingress Configuration

The chart supports multiple ingress options:
- **Ingress** - Standard Kubernetes Ingress
- **HTTPRoute** - Gateway API HTTPRoute
- **Route** - OpenShift Route

### Example values.yaml

```yaml
domain: "example.com"

opensearch:
  enabled: true
  replicas: 3
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "2"
      memory: "4Gi"
  persistence:
    size: 50Gi
  ingress:
    enabled: true
    host: opensearch
  extraEnvs:
    - name: OPENSEARCH_INITIAL_ADMIN_PASSWORD
      value: "YourSecureP@ss123"

opensearch-dashboards:
  enabled: true
  ingress:
    enabled: true
    host: opensearch-dashboards
```

## Accessing the Services

After installation:

- **OpenSearch**: `https://opensearch.<domain>`
- **OpenSearch Dashboards**: `https://opensearch-dashboards.<domain>`

### Default Credentials

- **Username**: `admin`
- **Password**: Set via `opensearch.extraEnvs` with `OPENSEARCH_INITIAL_ADMIN_PASSWORD`

Password requirements:
- Minimum 8 characters
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one digit (0-9)
- At least one special character (!@#$%^&*()_+-=)

## Upgrading from a chart older than 1.17.1 — one-time Jaeger retention remediation

**Who this applies to:** any environment whose Jaeger indices were created by
`dp-config-opensearch` **1.17.0 or older** — that is, every environment installed before the
PCP-24038 fix. Indices created by 1.17.1 or later are not affected and need none of this.

### Why it is needed

1.17.1 removed the `rollover` action from the Jaeger ISM policy (PCP-24038). Jaeger writes
date-named daily indices (`jaeger-span-YYYY-MM-DD`), which have no rollover alias, so the action
never completes: the index reports either `Missing rollover_alias index setting` once the rollover
conditions are met, or `Pending rollover of index` before then. Either way the `hot` state never
finishes, so the transition to `warm`/`delete` never fires and **retention silently never runs** —
indices accumulate until the OpenSearch volume fills.

Updating the policy does **not** fix the indices already on it. ISM pins each managed index to the
policy *version* it was initialised with (`policy_seq_no` in the ISM `explain` output), so an index
created before the upgrade keeps executing the old rollover action even though
`jaeger-30d-policy` itself is now correct. Clearing that is a one-time operator step, deliberately
not automated here: unattended bulk index mutation from a post-upgrade hook is exactly the risk the
fix set out to avoid.

The commands below were verified end to end on a real cluster (PCP-24173) — including watching a
remediated index run `hot` -> `warm` -> `force_merge` -> `delete` and actually disappear. Run them
in **bash**.

### Setup

```bash
NS=opensearch-system              # namespace of the dp-config-opensearch release
CLUSTER=opensearch-cluster        # .Values.opensearch.clusterName
POD=$CLUSTER-master-0
# The admin password is the OPENSEARCH_INITIAL_ADMIN_PASSWORD this chart passes through
# .Values.opensearch.extraEnvs; read it back off the running StatefulSet rather than retyping it.
# Select the container by NAME, not by index — a sidecar would shift containers[0].
PW=$(kubectl get sts -n "$NS" "$CLUSTER-master" \
       -o jsonpath='{.spec.template.spec.containers[?(@.name=="opensearch")].env[?(@.name=="OPENSEARCH_INITIAL_ADMIN_PASSWORD")].value}')
# An empty PW makes every call below an unauthenticated 401, and step 1 would render that as
# "nothing affected". Fail here instead. If this release supplies the password through
# valueFrom/secretKeyRef rather than a literal value, this jsonpath matches nothing — read the
# referenced secret instead.
: "${PW:?could not read OPENSEARCH_INITIAL_ADMIN_PASSWORD off the ${CLUSTER}-master StatefulSet}"

# Read calls. Body on stdout, so it can be piped to jq — but NOT unchecked. Steps 1 and 3 are the
# entire safety net, and jq over a 401/404 body prints nothing at all, which reads exactly like
# "no index is affected" / "verified clean". So a read failure has to be loud too.
os() {   # os <METHOD> <PATH>
  local out code
  out=$(kubectl exec -n "$NS" "$POD" -c opensearch -- \
          curl -sk -u "admin:$PW" -w '\n%{http_code}' -X "$1" "https://localhost:9200$2")
  code=${out##*$'\n'}
  case "$code" in
    2*) printf '%s' "${out%$'\n'*}" ;;
    *)  echo "!! HTTP $code from $2 — the result is NOT trustworthy" >&2
        printf '%s\n' "${out%$'\n'*}" >&2; return 1 ;;
  esac
}

# Write calls. The remediation below MUST use this rather than os(): a silently failed add would
# leave every matched index UNMANAGED — retention completely off, which is strictly worse than
# the wedged state being repaired.
#
# A 2xx check alone is NOT enough. _ism/remove and _ism/add are bulk APIs: on a partial failure
# they still answer HTTP 200, with {"failures": true, "failed_indices": [...]}. That envelope is
# exactly what _ism/retry returned during this runbook's verification, at HTTP 200.
os_w() { # os_w <METHOD> <PATH> [JSON-BODY]
  local out code body
  if [ "$#" -gt 2 ]; then
    out=$(kubectl exec -n "$NS" "$POD" -c opensearch -- \
            curl -sk -u "admin:$PW" -w '\n%{http_code}' -X "$1" "https://localhost:9200$2" \
            -H 'Content-Type: application/json' -d "$3")
  else
    out=$(kubectl exec -n "$NS" "$POD" -c opensearch -- \
            curl -sk -u "admin:$PW" -w '\n%{http_code}' -X "$1" "https://localhost:9200$2")
  fi
  code=${out##*$'\n'}; body=${out%$'\n'*}
  printf '%s\nHTTP %s\n' "$body" "$code"
  case "$code" in 2*) ;; *) echo "!! FAILED — do not continue" >&2; return 1 ;; esac
  case "$body" in
    *'"failures":true'*|*'"failures": true'*)
      echo "!! per-index failures inside a 200 response — do not continue" >&2; return 1 ;;
  esac
  return 0
}

IDX='jaeger-span-*,jaeger-service-*'
```

> The credential is passed as a `curl -u` argument to `kubectl exec`, so it lands in the pod's
> process table and in the API server's exec audit record. That is accepted here — you already
> hold the credential and exec rights — but do not paste these commands into a shared terminal
> recording, and prefer a short-lived shell.

`IDX` is the `ism_template` pattern pair this chart's policy binds to
(`templates/index-jaeger-ism-policy.yaml`), so it selects exactly the indices the policy governs.
Unlike the Elasticsearch ILM APIs, the ISM APIs tolerate a pattern that also matches the
`jaeger-*-read` / `jaeger-*-write` aliases, so no exclusions are needed here.

### 1. Am I affected?

```bash
os GET "/_plugins/_ism/explain/$IDX?pretty"
```

An index is affected when its `action.name` is `rollover`, or when its `policy_seq_no` is lower
than the `_seq_no` the policy itself currently reports:

```bash
SEQ=$(os GET "/_plugins/_ism/policies/jaeger-30d-policy" | jq '._seq_no')
os GET "/_plugins/_ism/explain/$IDX" | jq -r --argjson seq "$SEQ" '
  to_entries[] | select(.value | type == "object")
  | select(.value.action.name == "rollover" or (.value.policy_seq_no // -1) < $seq)
  | "\(.key)  policy_seq_no=\(.value.policy_seq_no)  action=\(.value.action.name // "-")  \(.value.info.message // "")"'
```

Both symptoms have the same cause and the same fix. Note that the `jaeger-span-000001` /
`jaeger-service-000001` bootstrap indices are affected too — they are created by the chart and
inherit the policy just like the daily ones.

### 2. Remediate

Remove the policy from the indices and add it back, so ISM re-initialises them against the current
policy version.

> ⚠️ **Between these two commands retention is OFF for every matched index** — `_ism/remove`
> unmanages the healthy ones too, and only `_ism/add` puts them back. Run them chained, and if the
> add reports anything but `HTTP 200`, **re-run it before doing anything else**. The `:?` guards
> abort instead of expanding to an empty index expression if you pasted this into a fresh shell
> without the Setup block.

```bash
: "${NS:?run the Setup block first}" "${POD:?}" "${IDX:?}"

os_w POST "/_plugins/_ism/remove/$IDX" &&
os_w POST "/_plugins/_ism/add/$IDX" '{"policy_id": "jaeger-30d-policy"}'
```

### 3. Verify

Re-run the detection command from step 1. Within a few ISM job intervals
(`plugins.index_state_management.job_interval`, 5 minutes by default) it should list **nothing**:
every index reports the policy's current `policy_seq_no` and is no longer in the `rollover` action.

Immediately after `_ism/add` the same indices are still listed, with `policy_seq_no=null` — ISM has
attached the policy but has not run the job that initialises the managed index yet. That is
expected, not a failure. Wait one full `job_interval` and re-check; the message then becomes
`Successfully initialized policy: jaeger-30d-policy` and `policy_seq_no` matches the policy.

Do not verify by requiring a specific `action.name` such as `transition`. Once unwedged, an index
advances by its real age — one older than 10 days legitimately reports `force_merge`, and one past
30 days reports `delete` — so pinning the expected action would flag a successful remediation as a
failure. The invariants that matter are: current `policy_seq_no`, and no `rollover`.

Indices past 30 days are deleted on the following passes:

```bash
os GET "/_cat/indices/*jaeger*?v&s=index"
```

### Commands that do NOT work

Earlier revisions of this fix carried a different runbook in a template comment. It was never
executed, and none of it works — recorded here so it is not reintroduced:

| Command | What actually happens |
|---------|----------------------|
| `POST _plugins/_ism/change_policy/jaeger-span-*,jaeger-service-*` | `400 parse_exception: request body is required` — the API needs a `{"policy_id": ...}` body, which the documented form omitted. |
| the same call **with** a `policy_id` body | Returns `{"updated_indices": 6, "failures": false}` and changes nothing. `change_policy` only *queues* the switch; ISM applies it when the index next reaches a safe point between actions, which a wedged index never does. |
| `POST _plugins/_ism/retry/jaeger-span-*,jaeger-service-*` | `{"updated_indices": 0, "failures": true, ... "This index is not in failed state."}` — `retry` accepts only indices whose managed-index has reached the terminal failed state, not ones looping inside an action. |

## Uninstallation

```bash
helm uninstall dp-config-opensearch -n <namespace>
```

## Dependencies

| Chart | Version | Repository |
|-------|---------|------------|
| opensearch | 3.4.0 | https://opensearch-project.github.io/helm-charts/ |
| opensearch-dashboards | 3.4.0 | https://opensearch-project.github.io/helm-charts/ |

## License

# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.


Licensed under the Apache License, Version 2.0.
