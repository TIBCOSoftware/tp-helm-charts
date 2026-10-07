<!-- 
 Copyright (c) 2023-2026. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file. 
-->

# dp-config-es Helm Chart

This repository hosts the official **dp-config-es Helm Charts** for deploying **elastic search configuration** products to [Kubernetes](https://kubernetes.io/)

## Install Helm (only V3 is supported)

Get the latest [Helm release](https://github.com/helm/helm#install).

## Install Charts

### Add dp-config-es Helm repository

Before installing dp-config-es helm charts, you need to add the [dp-config-es helm repository] to your helm client.

### Install locally with override values

```bash
helm upgrade --install dp-config-es [--namespace <namespace>] --values <new file name>.yaml
Or
helm upgrade --install dp-config-es [--namespace <namespace>] -f <new file name>.yaml
```

**Note:** For instructions on how to install a chart follow the instructions in _README.md_.

## Upgrading from a chart older than 1.21.1 — one-time Jaeger retention remediation

**Who this applies to:** any environment whose Jaeger indices were created by `dp-config-es`
**1.21.0 or older** — that is, every environment installed before the PCP-24038 fix. Indices
created by 1.21.1 or later are not affected and need none of this.

### Why it is needed

1.21.1 removed the `rollover` action from the Jaeger index lifecycle policy (PCP-24038). Jaeger
writes date-named daily indices (`jaeger-span-YYYY-MM-DD`), which are never the write index of a
rollover alias, so that action failed on every index and parked it in a permanent ILM error.
Once an index is wedged in the `hot`/`rollover` action, `warm` and `delete` never run and **its
retention is silently dead** — nothing is logged and nothing alerts, the Elasticsearch volume
just grows until it fills. Application logs share that cluster with traces, so the failure takes
log search down with Jaeger.

The write path self-heals on upgrade. **Retention does not.** ILM caches the policy's phase
definition on each index (`phase_execution.phase_definition` in `_ilm/explain`), so an index
created before the upgrade keeps re-running the *old* rollover step even though the policy itself
is now correct. Clearing that is a one-time operator step, deliberately not automated here:
unattended bulk index mutation from a post-upgrade hook is exactly the risk the fix set out to
avoid.

The commands below were verified end to end on a real cluster (PCP-24173). Run them in **bash**.

### Setup

Everything below runs against the data plane's Elasticsearch. The simplest route is to exec into
an Elasticsearch pod, so no ingress or certificate handling is needed:

```bash
NS=elastic-system                 # namespace of the dp-config-es release
REL=dp-config-es                  # helm release name
POD=$REL-es-default-0
PW=$(kubectl get secret "$REL-es-elastic-user" -n "$NS" -o go-template='{{.data.elastic | base64decode}}')

# Read calls. Body on stdout, so it can be piped to jq — but NOT unchecked. Steps 1 and 3 are the
# entire safety net, and jq over a 401/404 body prints nothing at all, which reads exactly like
# "no index is affected" / "verified clean". So a read failure has to be loud too.
es() {   # es <METHOD> <PATH>
  local out code
  out=$(kubectl exec -n "$NS" "$POD" -c elasticsearch -- \
          curl -sk -u "elastic:$PW" -w '\n%{http_code}' -X "$1" "https://localhost:9200$2")
  code=${out##*$'\n'}
  case "$code" in
    2*) printf '%s' "${out%$'\n'*}" ;;
    *)  echo "!! HTTP $code from $2 — the result is NOT trustworthy" >&2
        printf '%s\n' "${out%$'\n'*}" >&2; return 1 ;;
  esac
}

# Write calls. The remediation below MUST use this rather than es(): a silently failed re-attach
# would leave every matched index UNMANAGED — retention completely off, which is strictly worse
# than the wedged state being repaired.
#
# A 2xx check alone is NOT enough. `_ilm/remove` is a bulk API: when it cannot unmanage some of
# the matched indices it still answers HTTP 200, with {"has_failures": true, "failed_indexes":
# [...]}. Without the second check below, a partial remove would sail through the `&&` and the
# operator would see two green HTTP 200 lines over a cluster that now has unmanaged indices.
es_w() { # es_w <METHOD> <PATH> [JSON-BODY]
  local out code body
  if [ "$#" -gt 2 ]; then
    out=$(kubectl exec -n "$NS" "$POD" -c elasticsearch -- \
            curl -sk -u "elastic:$PW" -w '\n%{http_code}' -X "$1" "https://localhost:9200$2" \
            -H 'Content-Type: application/json' -d "$3")
  else
    out=$(kubectl exec -n "$NS" "$POD" -c elasticsearch -- \
            curl -sk -u "elastic:$PW" -w '\n%{http_code}' -X "$1" "https://localhost:9200$2")
  fi
  code=${out##*$'\n'}; body=${out%$'\n'*}
  printf '%s\nHTTP %s\n' "$body" "$code"
  case "$code" in 2*) ;; *) echo "!! FAILED — do not continue" >&2; return 1 ;; esac
  case "$body" in
    *'"has_failures":true'*|*'"has_failures": true'*)
      echo "!! per-index failures inside a 200 response — do not continue" >&2; return 1 ;;
  esac
  return 0
}
```

> The credential is passed as a `curl -u` argument to `kubectl exec`, so it lands in the pod's
> process table and in the API server's exec audit record. That is accepted here — you already
> hold the credential and exec rights — but do not paste these commands into a shared terminal
> recording, and prefer a short-lived shell.

`IDX` is the index expression used by every command below:

```bash
IDX='*jaeger-span-*,*jaeger-service-*,-*jaeger-*-read,-*jaeger-*-write'
```

- The two positive patterns are the chart's **own index-template patterns**
  (`templates/index-template-jaeger-{span,service}.yaml`), so they select exactly the indices this
  lifecycle policy governs — including a deployment that prefixes its Jaeger index names. Do not
  simplify them to `jaeger-*`: that also sweeps in other Jaeger index families such as
  `jaeger-dependencies-*`, and step 2 would strip whatever policy those had and attach one whose
  `delete` phase fires at 30 days.
- The two exclusions are **required**: those patterns also match the `jaeger-span-read`,
  `jaeger-span-write`, `jaeger-service-read` and `jaeger-service-write` **aliases**, and the ILM
  APIs resolve concrete indices only — including an alias fails the entire request with
  `index [jaeger-span-write] does not exist`.

### 1. Am I affected?

```bash
es GET "/$IDX/_ilm/explain?human"
```

An index is affected when it reports `"action": "rollover"`. The fixed policy has no `hot` phase
at all, so any Jaeger index still sitting in `hot`/`rollover` is by definition running a stale
cached phase definition. Condensed:

```bash
es GET "/$IDX/_ilm/explain?human" | jq -r '
  .indices | to_entries[] | select(.value.action == "rollover")
  | "\(.key)  step=\(.value.step)  failed_step=\(.value.failed_step // "-")  retries=\(.value.failed_step_retry_count // 0)"'
```

Do **not** use `_ilm/explain?only_errors=true` for this. The rollover failure is
`is_auto_retryable_error: true`, so each index flips between `step: ERROR` and the step being
retried; sampled three times seven seconds apart on a cluster with four wedged indices, that
filter returned 4, 4 and then **0** matches. A one-shot `only_errors` check reports a healthy
cluster roughly whenever it lands mid-retry.

### 2. Remediate

Detach the policy and immediately re-attach it, so ILM discards the cached phase definition and
re-reads the current policy.

> ⚠️ **Between these two commands retention is OFF for every matched index** — `_ilm/remove`
> unmanages the healthy ones too, and only the `PUT` puts them back. Run them chained, and if the
> `PUT` reports anything but `HTTP 200`, **re-run it before doing anything else**. The `:?` guards
> abort instead of expanding to an empty index expression if you pasted this into a fresh shell
> without the Setup block.

```bash
: "${NS:?run the Setup block first}" "${POD:?}" "${REL:?}" "${IDX:?}"

es_w POST "/$IDX/_ilm/remove" &&
es_w PUT  "/$IDX/_settings" "{\"index.lifecycle.name\": \"$REL-jaeger-index-30d-lifecycle-policy\"}"
```

> ⚠️ **Force-merge wave.** Re-attaching every index at once means all of them between 10 and 30
> days old enter `warm` on the next poll and `forcemerge` concurrently. On the disk-pressured
> cluster this runbook exists to rescue, that is itself a risk. If the cluster is tight on space
> or I/O, remediate only the indices step 1 flagged, in sequence:

```bash
for i in $(es GET "/$IDX/_ilm/explain?human" \
             | jq -r '.indices | to_entries[] | select(.value.action == "rollover") | .key'); do
  es_w POST "/$i/_ilm/remove" &&
  es_w PUT  "/$i/_settings" "{\"index.lifecycle.name\": \"$REL-jaeger-index-30d-lifecycle-policy\"}"
  sleep 30
done
```

Optional hygiene — drop the stale rollover alias setting the old index template left behind. This
is **not** required for recovery (verified): the fixed policy has no rollover action, so ILM never
reads the setting.

```bash
es_w PUT "/$IDX/_settings" '{"index.lifecycle.rollover_alias": null}'
```

### 3. Verify

This step is not optional: **Elasticsearch does not validate the policy name in a `_settings`
PUT.** Re-attaching to a misspelled policy returns `HTTP 200` and leaves the index managed by a
policy that does not exist — the `HTTP 200` from step 2 proves the request was accepted, not that
the right policy landed. Only the check below shows that.

Re-run the **detection** command from step 1 — that is the one that shows ILM state. No index may
report `"action": "rollover"`, and every Jaeger index must be `"managed": true` on
`<release>-jaeger-index-30d-lifecycle-policy`:

```bash
es GET "/$IDX/_ilm/explain?human" | jq -r '
  .indices | to_entries[]
  | "\(.key)  managed=\(.value.managed)  policy=\(.value.policy // "-")  action=\(.value.action // "-")"'
```

Then confirm retention is actually running: indices already past `delete.min_age` (30 days)
disappear within one ILM poll — `indices.lifecycle.poll_interval`, 10 minutes by default.

```bash
es GET "/_cat/indices/*jaeger*?v&s=index"
```

### Commands that do NOT work

Earlier revisions of this fix carried a different runbook in a template comment. It was never
executed, and none of it works — recorded here so it is not reintroduced:

| Command | What actually happens |
|---------|----------------------|
| `POST /jaeger-span-*,jaeger-service-*/_ilm/retry` | `400 index [jaeger-span-write] does not exist` — the wildcard matches the read/write aliases, which `_ilm/retry` cannot resolve. Nothing is retried. |
| `POST /<alias-free pattern>/_ilm/retry` | `400 cannot retry an action for an index [...] that has not encountered an error` — `_ilm/retry` is all-or-nothing across the expression, and the auto-retry flapping above guarantees some index is out of `ERROR` at any instant. |
| `PUT /jaeger-*/_settings {"index.lifecycle.rollover_alias": null}` alone | Succeeds, fixes nothing. The index stays wedged in `hot`/`rollover`; only the error text changes, to `setting [index.lifecycle.rollover_alias] ... is empty or not defined`. |

The common cause is that `_ilm/retry` re-runs the **cached** failed step, not the updated policy.
Only detaching and re-attaching the policy makes ILM re-read it.

## Contributing to dp-config-es Charts

Fork the `repo`, make changes and then please run `helm lint` to lint charts locally,
and at least install the chart to see if it is working.
:)

On success make a [pull request](https://help.github.com/articles/using-pull-requests) (PR) on to the `master` branch.

We will take these PR changes internally, review and test them.

Upon successful review, someone will give the PR an __LGTM__ (_looks good to me_) in the review thread.

We will add PR changes in upcoming releases and credit the contributor with the PR link in the changelog
(and also close the PR raised by the contributor).


