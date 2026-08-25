{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.fullname
     -------------------------------------------------------------------- */}}
{{- /* Always release-scoped: global.fullnameOverride and global.nameOverride are intentionally ignored so (a) multiple gateways co-exist per DP without Helm ownership collisions and (b) this stays in lockstep with tp-mcp-gateway.serviceName under ALL inputs (PCP-20591). */}}
{{- define "mcp-stack.fullname" -}}
{{- printf "%s-mcp-stack" .Release.Name -}}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.labels
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.labels" -}}
app.kubernetes.io/name: {{ include "mcp-stack.fullname" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.capabilityLabels

     >>> LOCAL TIBCO MODIFICATION — NOT PART OF THE UPSTREAM mcp-stack CHART <<<
     (vendored from github.com/IBM/mcp-context-forge). Added for PCP-19047.

     Why: the upstream `mcp-stack.labels` sets app.kubernetes.io/name to the
     release-scoped fullname (e.g. "<release>-mcp-stack"), which the CP
     capability lookup and tp-dp-monitor-agent do NOT recognise. The platform
     spec requires the gateway Service + pods to carry
     app.kubernetes.io/name = tp-mcp-gateway plus the platform.tibco.com/*
     identity labels — exactly what the LITE path emits via
     `tp-mcp-gateway.selectorLabels` in the PARENT chart
     (charts/tp-mcp-gateway/templates/_helpers.tpl).

     A subchart cannot `include` a parent-defined template, so the identical
     label set is re-declared here. dataplane-id / capability-instance-id read
     the shared .Values.global.cp.* (Helm propagates the parent global into
     subcharts — the same channel global.networkPolicy / global.otel already
     use), guarded so the subchart still renders if global is absent.

     This is a DROP-IN REPLACEMENT for `mcp-stack.labels` on the GATEWAY
     resources only: it re-emits helm.sh/chart + managed-by so nothing is lost
     and overrides app.kubernetes.io/name. Applied in service-mcp.yaml and
     deployment-mcpgateway.yaml (metadata + pod template); the new
     app.kubernetes.io/name value is matched by the ServiceMonitor selector in
     servicemonitor-mcpgateway.yaml.

     >>> KEEP IN SYNC with tp-mcp-gateway.selectorLabels in the parent chart. <<<
     One intentional difference from the parent helper: the dataplane-id /
     capability-instance-id reads below are wrapped in `{{ if and .Values.global
     .Values.global.cp }}` because the parent's global block is not guaranteed
     present in this subchart's value scope. That guard is deliberate subchart
     hardening, NOT drift — keep it when syncing label names/values from the parent.

     On every upstream re-sync of mcp-stack: do NOT drop this define and do NOT
     let the merge revert the "PCP-19047 LOCAL MOD" edits in service-mcp.yaml,
     deployment-mcpgateway.yaml, servicemonitor-mcpgateway.yaml and
     hpa-mcpgateway.yaml.
     Spec: https://tibco.atlassian.net/wiki/spaces/TCP/pages/396158725/Monitoring+and+k8s+metadata
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.capabilityLabels" -}}
app.kubernetes.io/name: tp-mcp-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "mcp-hub"
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- /* app.kubernetes.io/version is intentionally omitted: in this subchart .Chart.AppVersion
       is mcp-stack's (e.g. 1.0.0-RC-3), NOT the gateway's, so emitting it would mislabel the
       gateway with an unrelated version. Upstream mcp-stack.labels also omitted it, and it is
       not one of the Confluence-spec-required capability labels. */}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform.tibco.com/workload-type: "capability-service"
{{- /* Always render a quoted string (never bare YAML null) — an unset value would
       otherwise produce `key:` with a null value, which the k8s API rejects for labels. */}}
{{- /* [PCP-20920] the guard must include the LEAF: `and .Values.global .Values.global.cp` alone
       still emits a bare null when cp exists but the leaf is absent (e.g. instanceId set,
       dataplaneId not) — exactly the case the comment above says must never happen. */}}
platform.tibco.com/dataplane-id: {{ if and .Values.global .Values.global.cp .Values.global.cp.dataplaneId }}{{ .Values.global.cp.dataplaneId | quote }}{{ else }}""{{ end }}
platform.tibco.com/capability-instance-id: {{ if and .Values.global .Values.global.cp .Values.global.cp.instanceId }}{{ .Values.global.cp.instanceId | quote }}{{ else }}""{{ end }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.serviceAccountName

     Returns the ServiceAccount name to use.
     - serviceAccount.create=true : provided name, else the chart fullname
       (this branch is UNCHANGED from upstream).
     - serviceAccount.create=false: 3-tier resolution (PCP-20561) —
         (1) explicit .Values.serviceAccount.name if non-empty, else
         (2) the orchestrator-injected DP ServiceAccount
             (.Values.global.cp.resources.serviceaccount.serviceAccountName),
             else
         (3) "default".

     >>> LOCAL TIBCO MODIFICATION (PCP-20561) — NOT PART OF THE UPSTREAM
         mcp-stack CHART (vendored from github.com/IBM/mcp-context-forge). <<<

     Why: in full DP mode serviceAccount.create is false and upstream falls
     straight back to "default", silently DROPPING the orchestrator-injected
     per-DP ServiceAccount that the LITE path already honours via
     .Values.global.cp.resources.serviceaccount.serviceAccountName
     (see charts/tp-mcp-gateway/templates/lite-deployment.yaml:46-47 and the
     parent values.yaml cp block). Reusing that injected SA is what gives the
     gateway pods their intended DP identity/RBAC.

     CASING IS LOAD-BEARING: the path is lowercase `serviceaccount` then camel
     `serviceAccountName` — verified against the parent values.yaml and
     lite-deployment.yaml. The injected read is fully nil-safe (guarded at every
     level) because this subchart can be rendered standalone where global / global.cp
     is absent — same `if and .Values.global .Values.global.cp ...` hardening style
     already used by mcp-stack.capabilityLabels above for dataplane-id/instance-id.

     >>> KEEP IN SYNC (PCP-20561): on every upstream re-sync of mcp-stack do NOT
         let the merge revert the create=false 3-tier branch back to the bare
         `default "default" .Values.serviceAccount.name`, and do NOT drop the
         companion mcp-stack.useServiceAccount guard below. <<<
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mcp-stack.fullname" .) .Values.serviceAccount.name }}
{{- else if .Values.serviceAccount.name }}
{{- .Values.serviceAccount.name }}
{{- else if and .Values.global .Values.global.cp .Values.global.cp.resources .Values.global.cp.resources.serviceaccount .Values.global.cp.resources.serviceaccount.serviceAccountName }}
{{- .Values.global.cp.resources.serviceaccount.serviceAccountName }}
{{- else }}
{{- "default" }}
{{- end }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.useServiceAccount

     >>> LOCAL TIBCO MODIFICATION (PCP-20561) — NOT PART OF THE UPSTREAM
         mcp-stack CHART (vendored from github.com/IBM/mcp-context-forge). <<<

     Single source of truth for the "should a serviceAccountName be rendered?"
     guard. Returns the string "true" when ANY of the following is set, "" (empty)
     otherwise:
       - .Values.serviceAccount.create
       - .Values.serviceAccount.name
       - the SAME nil-safe orchestrator-injected SA term used by
         mcp-stack.serviceAccountName above.

     Consumers gate the field with `{{ if (include "mcp-stack.useServiceAccount" .) }}`.
     The injected read is nil-safe for standalone subchart renders, matching the
     guard style used by mcp-stack.serviceAccountName / mcp-stack.capabilityLabels.

     >>> KEEP IN SYNC (PCP-20561) with mcp-stack.serviceAccountName: the injected-SA
         term here MUST mirror tier (2) of that helper. <<<
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.useServiceAccount" -}}
{{- if .Values.serviceAccount.create -}}
true
{{- else if .Values.serviceAccount.name -}}
true
{{- else if and .Values.global .Values.global.cp .Values.global.cp.resources .Values.global.cp.resources.serviceaccount .Values.global.cp.resources.serviceaccount.serviceAccountName -}}
true
{{- end -}}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.postgresSecretName
     Returns the Secret name that the Postgres deployment should mount.
     If users set `postgres.existingSecret`, that name is used.
     Otherwise a release-scoped name is returned.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.postgresSecretName" -}}
{{- if .Values.postgres.external.enabled }}
{{- .Values.postgres.external.existingSecret | default (printf "%s-postgres-external" (include "mcp-stack.fullname" .)) }}
{{- else if .Values.postgres.existingSecret }}
{{- .Values.postgres.existingSecret }}
{{- else }}
{{- printf "%s-postgres-secret" (include "mcp-stack.fullname" .) }}
{{- end }}
{{- end }}

{{- /* --------------------------------------------------------------------
     PCP-20620: external-PostgreSQL connection resolvers.

     When the gateway is provisioned through the MCP Hub with a CP DBCONFIG
     resource instance selected, the orchestrator decrypts that instance and
     injects its fields at `global.cp.resources.dbconfig.*`
     (dbHost / dbPort / dbName / dbUser / secretDbPassword) — the same path the
     tibco-developer-hub chart consumes. The Hub itself cannot forward the
     connection (the resource-instances API REDACTS the password on read), so
     the chart must read it from the injected global block.

     Precedence (DBCONFIG-first — intentional):
       orchestrator-injected `global.cp.resources.dbconfig.<key>`  (CP DBCONFIG
         selection — authoritative when present)
       → else explicit `postgres.external.<field>`
     `coalesce` returns the first non-empty value, so an injected DBCONFIG value
     WINS over the explicit `postgres.external.*`. This ordering is REQUIRED, not
     a convenience: the parent chart (tp-mcp-gateway/values.yaml) still ships a
     non-blank external DATABASE topology default (`mcpforgedb`), so if the explicit
     value were tried first a CP DBCONFIG selection could never override it (that was
     the original bug, which then applied to the HOST default too). NOTE
     (PCP-21192): the user/password CREDENTIAL defaults are now BLANK (formerly the
     guessable `postgres/postgres`); supply the credential via a CP DBCONFIG, an
     explicit `postgres.external.user`/`password`, or `postgres.external.existingSecret`.
     The external HOST default is now BLANK as well — it used to be the shared-CP
     `postgresql.tibco-ext.svc.cluster.local`, a Control-Plane in-cluster Service name
     that does not resolve from a Data Plane. Nothing here depends on it being
     non-blank; the DBCONFIG-first ordering above is retained for `database`.
     When no DBCONFIG is injected (plain `helm install`, or a manual external PG
     set via `postgres.external.*` / `existingSecret`) the explicit values are
     used unchanged. The lookup uses a DIRECT `dig` per field (NOT a
     toYaml/fromYaml round-trip) so the stored value is returned verbatim, with no
     extra YAML re-typing pass, and is nil-safe when `global.cp.resources.dbconfig`
     is absent or null.

     Numeric-looking values: the orchestrator injects each dbconfig field as the
     decrypted Go STRING via yaml.Marshal (tp-cp-orchestrator utils.AddKeyValueToYaml),
     and Go's YAML marshaller QUOTES a numeric-looking string — so e.g. an
     all-digit password arrives as `secretDbPassword: "12345678"` and Helm parses
     it as a string (no float coercion). Only a MANUAL `helm install` that sets
     `postgres.external.*` to an UNQUOTED number would hit Helm's float64 coercion;
     quote such values. NOTE: a fail-closed guard in secret-postgres.yaml rejects an
     incomplete DBCONFIG injection (host present but missing password/user/db) so a
     CP host can never be silently paired with a mismatched or (post-PCP-21192) blank
     shared-CP credential.
     -------------------------------------------------------------------- */}}
{{- /* Resolve the dbconfig map ONCE at the node level (dig to `dbconfig`, not into
       a leaf): `dict` default + `| default dict` make this nil-safe even when
       `global.cp.resources.dbconfig` is present-but-null (a leaf-level dig would
       descend into null and panic). `get` then reads the stored value verbatim —
       no YAML re-typing. */}}
{{- define "mcp-stack.externalPg.host" -}}
{{- $cfg := dig "cp" "resources" "dbconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "dbHost") .Values.postgres.external.host "" -}}
{{- end -}}

{{- define "mcp-stack.externalPg.port" -}}
{{- $cfg := dig "cp" "resources" "dbconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "dbPort") .Values.postgres.external.port "5432" | toString -}}
{{- end -}}

{{- define "mcp-stack.externalPg.database" -}}
{{- $cfg := dig "cp" "resources" "dbconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "dbName") .Values.postgres.external.database "" -}}
{{- end -}}

{{- define "mcp-stack.externalPg.user" -}}
{{- $cfg := dig "cp" "resources" "dbconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "dbUser") .Values.postgres.external.user "" -}}
{{- end -}}

{{- define "mcp-stack.externalPg.password" -}}
{{- $cfg := dig "cp" "resources" "dbconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "secretDbPassword") .Values.postgres.external.password "" -}}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.databaseUrlEncode   (LOCAL TIBCO MOD — PCP-21191)
     Emits a POSIX-sh prelude that percent-encodes POSTGRES_USER/POSTGRES_PASSWORD
     and exports a well-formed DATABASE_URL at container start.

     WHY: Kubernetes $(VAR) env substitution is a literal textual replace and does
     NOT URL-encode. A PostgreSQL user/password containing URL-reserved characters
     (@ : / # ? ...) therefore corrupts the DSN (e.g. the '@' in a password splits
     the netloc early, breaking host/port parsing) and the gateway/migration cannot
     connect. This widened with the external customer-managed DB paths (PCP-20620 /
     PCP-21401), whose passwords are arbitrary.

     HOW: python3 is already present in the gateway/migration image (ubi-minimal).
     The encoder reads os.environ DIRECTLY (never shell / $(VAR) interpolation) so a
     password containing shell metacharacters ($, `, ', ", newline) is safe;
     safe="" percent-encodes every reserved char. User + password are encoded and an
     IPv6 host literal is bracketed. The db name is passed through RAW: SQLAlchemy 2.x
     make_url() decodes the userinfo but NOT the path, so encoding the db name would
     make it connect to a literal "%2F"-name; normal PG identifiers are URL-clean.
     SQLAlchemy (postgresql+psycopg) RFC-3986 percent-decodes the userinfo, so libpq
     receives the original raw credential.

     The [ -z "${DATABASE_URL:-}" ] guard preserves an operator-supplied override
     (mcpContextForge.config.DATABASE_URL delivered via envFrom). Fail-closed: a
     python error aborts container start rather than exporting an empty/bad URL.

     KEEP-IN-SYNC on upstream mcp-stack (github.com/IBM/mcp-context-forge) re-sync.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.databaseUrlEncode" -}}
if [ -z "${DATABASE_URL:-}" ]; then
  DATABASE_URL="$(python3 -B -c 'import os, urllib.parse as _u; _e = lambda _k: _u.quote(os.environ.get(_k, ""), safe=""); _h = os.environ["POSTGRES_HOST"]; _h = ("[" + _h + "]") if (":" in _h and not _h.startswith("[")) else _h; print("postgresql+psycopg://%s:%s@%s:%s/%s" % (_u.quote(os.environ["POSTGRES_USER"], safe=""), _e("POSTGRES_PASSWORD"), _h, os.environ["POSTGRES_PORT"], os.environ["POSTGRES_DB"]))')" || { echo "FATAL: could not assemble DATABASE_URL (PCP-21191 encoder)" >&2; exit 1; }
  export DATABASE_URL
fi
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.redisUrlEncode   (LOCAL TIBCO MOD — PCP-21191)
     Re-exports REDIS_URL with a percent-encoded password for any auth path that
     assembles it from discrete $(VAR) placeholders — the bundled in-cluster Redis
     WITH auth (redis[s]://:$(REDIS_PASSWORD)@host:port/db) AND, since PCP-20474, the
     effective-external path (redis.external.* or an orchestrator-injected
     global.cp.resources.redisconfig), which shares the same $(VAR) no-encoding flaw
     as DATABASE_URL. Rendered ONLY on those branches by the caller; the
     existingSecret / external.url / no-auth paths keep their existing REDIS_URL env
     value (an external URL is already Hub-encoded — PCP-20560). Scheme
     ("redis" | "rediss") and the logical db index are passed in by the caller (db
     defaults to "0" for the bundled path — byte-identical to before). Reads
     os.environ; fail-closed. KEEP-IN-SYNC on upstream re-sync.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.redisUrlEncode" -}}
{{- /* Only re-encode when REDIS_URL is still the chart's canonical UNENCODED value
       (i.e. exactly what the env template assembled from REDIS_PASSWORD/HOST/PORT/db). An
       operator override supplied via mcpContextForge.extraEnv would differ and is left
       untouched — mirroring the DATABASE_URL guard. Fail-closed: REDIS_PASSWORD required.
       The logical db index is passed by the caller (`.db`, default "0" for the bundled path so
       this line is byte-identical to before PCP-20474). */}}
_pcp_canon="{{ .scheme }}://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/{{ .db | default "0" }}"
if [ "${REDIS_URL:-}" = "$_pcp_canon" ]; then
  REDIS_URL="$(python3 -B -c 'import os, urllib.parse as _u; print("{{ .scheme }}://:%s@%s:%s/{{ .db | default "0" }}" % (_u.quote(os.environ["REDIS_PASSWORD"], safe=""), os.environ["REDIS_HOST"], os.environ["REDIS_PORT"]))')" || { echo "FATAL: could not assemble REDIS_URL (PCP-21191 encoder)" >&2; exit 1; }
  export REDIS_URL
fi
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helpers: mcp-stack.redisExternal* (PCP-20474)

     >>> LOCAL TIBCO MODIFICATION (PCP-20474) — NOT PART OF THE UPSTREAM
         mcp-stack CHART (vendored from github.com/IBM/mcp-context-forge). <<<

     Why: Redis is now a first-class Control Plane resource (resourceId
     'REDISCONFIG'). When an operator selects a Redis instance in the CP, the
     orchestrator injects the chosen instance at
     global.cp.resources.redisconfig.* — EXACTLY the same global.cp.resources.*
     channel the DBCONFIG injection (mcp-stack.externalPg.* above) and the
     serviceaccount injection already ride. Helm shares only global.* with this
     subchart, so the injected block lands here.

     These helpers BRIDGE that injected block onto the existing redis.external.*
     contract WITHOUT changing the shipped defaults. External activation is driven
     SOLELY by the Hub-set redis.external.enabled toggle (post-B1); the injected
     global.cp.resources.redisconfig.* values are consumed ONLY when that toggle is
     on, where they COALESCE-WIN over the plain redis.external.* host/port/db/password
     and surface the injected redisTls flag. When the block is ABSENT every
     helper falls back to the plain .Values.redis.external.* value, so the
     default render is byte-identical to before this change.

     Frozen field-key contract (lowercased resourceId 'redisconfig'):
       redisHost           -> redis.external.host (+ enabled=true)
       redisPort           -> redis.external.port
       redisDb             -> redis.external.db
       secretRedisPassword -> redis.external.password
       redisTls            -> redis.tls.enabled (+ rediss:// scheme)

     Every read uses the SAME `dig "cp" "resources" "redisconfig" dict (.Values.global
     | default dict) | default dict` node-level resolve as mcp-stack.externalPg.*
     (nil-safe even when global / global.cp.resources.redisconfig is absent or
     present-but-null), since this subchart can render standalone.

     >>> KEEP ON upstream mcp-stack re-sync. The injected-block term MUST mirror
         the global.cp.resources.* path used by the externalPg / serviceaccount
         helpers. <<<
     -------------------------------------------------------------------- */}}
{{- /* True ("true") when an orchestrator-injected redisconfig instance is present (redisHost set). */}}
{{- define "mcp-stack.redisConfigInjected" -}}
{{- $cfg := dig "cp" "resources" "redisconfig" dict (.Values.global | default dict) | default dict -}}
{{- if get $cfg "redisHost" -}}true{{- end -}}
{{- end }}

{{- /* "true" when external Redis is in play. Activation is driven SOLELY by the
       Hub-set redis.external.enabled toggle — NOT by the mere presence of an
       orchestrator-injected redisconfig instance. This mirrors the proven-safe
       Postgres pattern (mcp-stack.externalPg gates on postgres.external.enabled,
       and the injected dbconfig is only a coalesce value-source): a REDISCONFIG
       resource instance may exist on the DP while the user still chose built-in
       Redis, and its presence must NOT silently override that choice. The injected
       global.cp.resources.redisconfig.* values remain COALESCE sources only (see
       redisExternalHost/Port/Db/Password/Tls), consumed once this toggle is on.
       Keep this toggle-driven to prevent an injection-presence regression. */}}
{{- define "mcp-stack.redisExternalEnabled" -}}
{{- if .Values.redis.external.enabled -}}true{{- end -}}
{{- end }}

{{- /* Effective external host: injected redisHost wins, else the chart value. */}}
{{- define "mcp-stack.redisExternalHost" -}}
{{- $cfg := dig "cp" "resources" "redisconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "redisHost") .Values.redis.external.host "" -}}
{{- end }}

{{- /* Effective external port: injected redisPort wins, else the chart value. */}}
{{- define "mcp-stack.redisExternalPort" -}}
{{- $cfg := dig "cp" "resources" "redisconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "redisPort") .Values.redis.external.port "6379" | toString -}}
{{- end }}

{{- /* Effective external db: injected redisDb wins (incl. an explicit 0), else the chart value.
       `coalesce` would drop an injected 0/"0", so dig-then-explicit-presence is used; an injected
       redisDb of 0 / "0" is intentionally honoured. */}}
{{- define "mcp-stack.redisExternalDb" -}}
{{- $cfg := dig "cp" "resources" "redisconfig" dict (.Values.global | default dict) | default dict -}}
{{- $db := get $cfg "redisDb" -}}
{{- /* `get` returns "" for an absent key (not nil), so treat both invalid AND empty-string as
       "not injected" and fall back to .Values.redis.external.db. An injected 0 / "0" is still a
       non-empty value, so it is honoured. */}}
{{- if or (kindIs "invalid" $db) (eq (toString $db) "") -}}{{- .Values.redis.external.db -}}{{- else -}}{{- $db -}}{{- end -}}
{{- end }}

{{- /* Effective external password: injected secretRedisPassword wins, else the chart value. */}}
{{- define "mcp-stack.redisExternalPassword" -}}
{{- $cfg := dig "cp" "resources" "redisconfig" dict (.Values.global | default dict) | default dict -}}
{{- coalesce (get $cfg "secretRedisPassword") .Values.redis.external.password "" | default "" -}}
{{- end }}

{{- /* "true" when client TLS should be on: explicit redis.tls.enabled OR injected redisTls.
       PCP-20474: the orchestrator emits redisTls as a STRING ('true'/'false', default 'false'),
       and a non-empty string is truthy in Go templates — so the string 'false' would force TLS on.
       Compare to the literal 'true' via toString, which makes BOTH a genuine boolean true and the
       string 'true' match while the string 'false' correctly yields redis:// / no REDIS_SSL.
       The injected redisTls term is gated on mcp-stack.redisExternalEnabled (the Hub-set
       redis.external.enabled toggle) — NOT the mere presence of an injected redisconfig — so it
       applies ONLY when external Redis is actually in play. This mirrors the B1 activation fix:
       otherwise a built-in render (redis.external.enabled=false) that happens to carry an injected
       redisconfig with redisTls='true' would flip the BUNDLED REDIS_URL to rediss:// + REDIS_SSL
       against the plaintext bundled Redis and crash. The explicit redis.tls.enabled term is kept
       intact so an operator can still request client TLS directly. */}}
{{- define "mcp-stack.redisExternalTls" -}}
{{- $cfg := dig "cp" "resources" "redisconfig" dict (.Values.global | default dict) | default dict -}}
{{- if or .Values.redis.tls.enabled (and (eq (include "mcp-stack.redisExternalEnabled" .) "true") (eq (toString (get $cfg "redisTls")) "true")) -}}true{{- end -}}
{{- end }}

{{- /* "true" when the new external-redis Secret (password) should render:
       external is effectively enabled, no existingSecret was supplied, and a password is present. */}}
{{- define "mcp-stack.renderExternalRedisSecret" -}}
{{- if and (eq (include "mcp-stack.redisExternalEnabled" .) "true") (not .Values.redis.external.existingSecret) (include "mcp-stack.redisExternalPassword" .) -}}true{{- end -}}
{{- end }}

{{- /* Name of the chart-generated external-redis Secret (mirrors <fullname>-postgres-external). */}}
{{- define "mcp-stack.redisExternalSecretName" -}}
{{- printf "%s-redis-external" (include "mcp-stack.fullname" .) -}}
{{- end }}

{{- /* "true" when the BUNDLED in-cluster Redis (deployment/service/secret/pvc/configmap) should
       render: redis.enabled AND external is NOT in play. Since redisExternalEnabled is driven
       SOLELY by the redis.external.enabled toggle (post-B1), this is equivalent to the legacy
       `and redis.enabled (not redis.external.enabled)` gate — a mere orchestrator-injected
       redisconfig instance does NOT suppress the bundled Redis. Consumers call this helper instead
       of the inline `and ...` so the gate is defined once. */}}
{{- define "mcp-stack.bundledRedisEnabled" -}}
{{- if and .Values.redis.enabled (not (eq (include "mcp-stack.redisExternalEnabled" .) "true")) -}}true{{- end -}}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.redisSecretName
     Returns the Secret name for Redis authentication.
     If users set `redis.auth.existingSecret`, that name is used.
     Otherwise a release-scoped name is returned.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.redisSecretName" -}}
{{- if .Values.redis.auth.existingSecret }}
{{- .Values.redis.auth.existingSecret }}
{{- else }}
{{- printf "%s-redis-secret" (include "mcp-stack.fullname" .) }}
{{- end }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.redisTlsSecretName

     LOCAL TIBCO MOD (PCP-20275): single source of truth for the bundled
     Redis server-TLS cert Secret name. EVERY consumer (the secret-redis-tls.yaml
     generator, the Redis Deployment cert mount + probes, the gateway CA mount,
     the redis-exporter + redis-commander CA mounts) references THIS helper —
     genSelfSignedCert is called exactly ONCE (in templates/secret-redis-tls.yaml).
     If serverTls.existingSecret is set, that operator/cert-manager-owned name wins.
     Keep on upstream mcp-stack (github.com/IBM/mcp-context-forge) re-sync.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.redisTlsSecretName" -}}
{{- if .Values.redis.serverTls.existingSecret }}
{{- .Values.redis.serverTls.existingSecret }}
{{- else }}
{{- printf "%s-redis-tls" (include "mcp-stack.fullname" .) }}
{{- end }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.redisTlsAltNames

     LOCAL TIBCO MOD (PCP-20275): DNS SANs for the self-signed Redis server
     cert, derived from the SAME <fullname>-redis Service the gateway dials
     (deployment-mcpgateway.yaml REDIS_HOST default). The bare short name MUST
     be first so it is also used as the cert CommonName. Returns a JSON/Go-style
     string list consumable via `fromJsonArray`. AC-6 asserts the dialed host
     (<fullname>-redis) is present.
     Keep on upstream mcp-stack re-sync.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.redisTlsAltNames" -}}
{{- $svc := printf "%s-redis" (include "mcp-stack.fullname" .) -}}
{{- $ns := .Release.Namespace -}}
{{- $names := list
      $svc
      (printf "%s.%s" $svc $ns)
      (printf "%s.%s.svc" $svc $ns)
      (printf "%s.%s.svc.cluster.local" $svc $ns)
      "localhost" -}}
{{- $names | toJson -}}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.bundledRedisServerTls

     LOCAL TIBCO MOD (PCP-20275): single source of truth for the "bundled
     in-cluster Redis serves TLS" predicate. Returns the string "true" or
     "false" (templates can't return a real bool from `include`). Every
     consumer template was duplicating this same `and ...` expression; they
     now call `eq (include "mcp-stack.bundledRedisServerTls" .) "true"` so the
     gate is defined ONCE. The condition is: serverTls is on, the bundled Redis is
     enabled, and neither an external nor an overridden host target is in play.
     LOCAL TIBCO MOD (PCP-20474): also require NOT external
     (mcp-stack.redisExternalEnabled != "true", i.e. the redis.external.enabled
     toggle is off) so an external-Redis render can never leave bundledServerTls
     true and leak the bundled self-signed CA mount onto the EXTERNAL target. Note
     this keys off the redis.external.enabled toggle, NOT the mere presence of an
     injected redisconfig instance (post-B1 injection presence alone does not make
     Redis external). (The deployment fail-fast also rejects serverTls + external
     Redis, so this is belt-and-suspenders.)
     Keep on upstream mcp-stack (github.com/IBM/mcp-context-forge) re-sync.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.bundledRedisServerTls" -}}
{{- if and .Values.redis.serverTls.enabled .Values.redis.enabled (not .Values.mcpContextForge.env.redis.host) (not (eq (include "mcp-stack.redisExternalEnabled" .) "true")) -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.pgadminSecretName
     Returns the Secret name for PgAdmin credentials.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.pgadminSecretName" -}}
{{- if .Values.pgadmin.existingSecret }}
{{- .Values.pgadmin.existingSecret }}
{{- else }}
{{- printf "%s-pgadmin" (include "mcp-stack.fullname" .) }}
{{- end }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.storageClassName

     >>> LOCAL TIBCO MODIFICATION (PCP-20593) — NOT PART OF THE UPSTREAM
         mcp-stack CHART (vendored from github.com/IBM/mcp-context-forge). <<<

     Single source of truth for resolving the storageClassName a PVC should
     request. Call with a dict carrying the per-component override and the root
     context, e.g.:
         {{ include "mcp-stack.storageClassName"
              (dict "local" .Values.postgres.persistence.storageClassName "ctx" $) }}

     Precedence (matches the platform "bind the DP-injected storage class unless
     the component explicitly overrides it" rule):
       (1) the passed `local` value, if non-empty -> use it
           (preserves any per-component persistence.storageClassName override);
       (2) else the orchestrator-injected
           global.cp.resources.storage.storageClassName, if present AND non-empty;
       (3) else output NOTHING — the caller then omits the storageClassName key
           entirely so the PVC binds the cluster's default StorageClass.

     "-" SENTINEL (PCP-20593): the platform uses "-" to mean "force NO dynamic
     provisioning" — i.e. emit `storageClassName: ""` (empty quoted string) so the
     PVC binds a class-less, statically-provisioned PV rather than a default
     StorageClass. A bare `storageClassName: -` is INVALID YAML-for-k8s and Helm
     rejects the render, so when the EFFECTIVE value (after precedence above)
     resolves to "-" this helper returns the two-character literal `""`, which the
     callers emit verbatim as `storageClassName: ""`. This mirrors
     tibco-developer-hub's `common.storage.class` exactly (and langfuse/_storage.tpl,
     on-premises-third-party postgresql, tp-cp-prometheus, tp-cp-alertmanager).
     Note the deliberate semantic split: empty/unset => OMIT the key (cluster
     DEFAULT StorageClass); "-" => EMIT `storageClassName: ""` (no provisioning).
     Callers keep their `{{ if $sc }}storageClassName: {{ $sc }}{{ end }}` form
     unchanged — `""` is a non-empty $sc so the key still renders for the sentinel,
     while a truly empty $sc still omits it.

     CASING / PATH IS LOAD-BEARING: lowercase `resources.storage`, camel
     `storageClassName` — verified against tibco-developer-hub's
     `common.storage.class` and the parent cp block. The global read guards the
     FULL chain (global -> cp -> resources -> storage) so this subchart still
     renders standalone where global / global.cp is absent (a shallow 2-level
     guard would nil-pointer panic on the deeper .resources.storage reads) — same
     depth as common.storage.class in
     charts/tibco-developer-hub/templates/_helpers.tpl, NOT the 2-level guard used
     by mcp-stack.capabilityLabels (whose reads only go one level past global.cp).

     >>> KEEP IN SYNC (PCP-20593): on every upstream re-sync of mcp-stack do NOT
         drop this define, and keep the global path consistent with the parent cp
         block / tibco-developer-hub common.storage.class. <<<
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.storageClassName" -}}
{{- $local := .local -}}
{{- $ctx := .ctx -}}
{{- $effective := "" -}}
{{- if $local -}}
{{- $effective = $local -}}
{{- else if and $ctx.Values.global $ctx.Values.global.cp $ctx.Values.global.cp.resources $ctx.Values.global.cp.resources.storage $ctx.Values.global.cp.resources.storage.storageClassName -}}
{{- $effective = $ctx.Values.global.cp.resources.storage.storageClassName -}}
{{- end -}}
{{- $effective = trimAll " " (toString $effective) -}}
{{- if eq $effective "-" -}}
{{- printf "%s" "\"\"" -}}
{{- else -}}
{{- $effective -}}
{{- end -}}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.fluentbit.enabled   (PCP-22768)
     Nil-safe walk of .Values.global.tibco.logging.fluentbit.enabled — returns
     the string "true" ONLY when every nesting level exists and `enabled` is
     truthy, else the empty string. The defensive per-level guard mirrors the
     platform per-service fluentbit gate (tibco-cp-ai-agent) so a --reuse-values
     upgrade that drops the nested block cannot error with a nil-map lookup.
     KEEP IN SYNC with the source chart (tp-mcp-gateway/charts/mcp-stack).
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.fluentbit.enabled" -}}
{{- if .Values.global -}}
{{- if .Values.global.tibco -}}
{{- if .Values.global.tibco.logging -}}
{{- if .Values.global.tibco.logging.fluentbit -}}
{{- if .Values.global.tibco.logging.fluentbit.enabled -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: helpers.renderProbe
     Renders a readiness or liveness probe from a shorthand values block.
     Supports "http", "tcp", and "exec".
     -------------------------------------------------------------------- */}}
{{- define "helpers.renderProbe" -}}
{{- $p := .probe -}}
{{- if eq $p.type "http" }}
httpGet:
  path: {{ $p.path }}
  port: {{ $p.port }}
  {{- if $p.scheme }}scheme: {{ $p.scheme }}{{ end }}
{{- else if eq $p.type "tcp" }}
tcpSocket:
  port: {{ $p.port }}
{{- else if eq $p.type "exec" }}
exec:
  command: {{ toYaml $p.command | nindent 4 }}
{{- end }}
initialDelaySeconds: {{ $p.initialDelaySeconds | default 0 }}
periodSeconds:       {{ $p.periodSeconds       | default 10 }}
timeoutSeconds:      {{ $p.timeoutSeconds      | default 1 }}
successThreshold:    {{ $p.successThreshold    | default 1 }}
failureThreshold:    {{ $p.failureThreshold    | default 3 }}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helpers: mcp-stack.image.registry / mcp-stack.image.repository  (PCP-23125)
     Container-registry indirection. Copied from
     charts/tp-dp-infra-mcp-server/templates/_helpers.tpl:57-69 and adapted ONLY in
     name — the house pattern shared by every DP-installed capability chart
     (bwprovisioner:83-90, tp-dp-apim:82-89, tp-dp-discovery-service:55-62,
     dp-bw-adapter:84-91, o11y-service:104-111, ...). They are ZERO-LOGIC on
     purpose: byte-identical to the canonical block in 13 sibling charts, reading
     global.cp.containerRegistry and nothing else. Do not add a branch, a
     short-circuit or a nil-safe traversal here — nil-safety comes from DECLARING
     global.cp.containerRegistry in THIS chart's values.yaml (which is what makes
     the ct standalone render nil-safe) as well as the parent's, exactly as the
     siblings do.

     HOW THEY ARE USED. Call sites compose the EFFECTIVE repository
     <registry>/<repository>/<bare-name> and pass it to "mcp-stack.image"
     (PCP-23214) as the `repository` key of the image block, so tag and digest
     still travel through that ONE helper:

         $img := merge (dict "repository" <composed>) .Values.redis.image
         image: include "mcp-stack.image" $img | quote

     Assembling the `image:` string at the call site instead would silently drop
     the digest — it would still render, still lint and still deploy, back on a
     mutable reference, with nothing reporting it. There is exactly ONE
     image-reference path in this chart and this is not a second one.
     `merge` is destination-wins and MUTATES its first argument, hence the fresh
     `dict` as destination: .Values.* is never the destination and so is never
     mutated into the next render in the same pass.

     Every in-scope image name in values.yaml is therefore a BARE NAME. With no
     globals injected this emits a LEADING SLASH (/tibco-platform-docker-prod/name:tag),
     exactly as it does in all the sibling charts — that is the expected shape,
     not a defect.

     There is NO global.tibco arm. Every DP chart reads global.cp exclusively; the
     one cp-then-tibco chain in the repo (mcp-hub-webserver/_helpers.tpl) governs
     the PULL SECRET only, and that chart's url/repository helpers read
     global.tibco exclusively because it is a CONTROL-PLANE chart. tp-mcp-gateway
     is Data-Plane-installed, so global.cp is the only correct arm. Pinned by
     dev/mcp-gateway-render-tests/container-registry-assert.sh [3]/[4].

     STYLE MODEL is the fluentbit.enabled twin (this file :599-620 and
     charts/tp-mcp-gateway/templates/_helpers.tpl:181-202) — the only pre-existing
     twin pair that is byte-identical modulo the name prefix. The storageClassName
     twin is NOT: it uses a different comment delimiter on each side, and its
     closing `end` action carries the right-trim marker here but not in the parent
     (a full-define diff reports 16c16). That divergence is historical, not
     meaningful; do not reproduce it here and do not "fix" it there.

     BANNER HYGIENE: keep template delimiters out of this comment. A stray
     comment-close sequence inside a Go-template comment ends it early, and every
     line after it is then parsed as live template actions.

     >>> KEEP IN SYNC (PCP-23125): the two defines below are BYTE-IDENTICAL apart
         from the name prefix with tp-mcp-gateway.image.registry /
         tp-mcp-gateway.image.repository in
         charts/tp-mcp-gateway/templates/_helpers.tpl. A subchart-defined template
         is NOT callable from the parent (see the note at
         charts/tp-mcp-gateway/templates/_helpers.tpl:111-133), so the pair is
         duplicated on purpose — same discipline as the storageClassName and
         fluentbit.enabled twins. <<<

     >>> LOCAL TIBCO MODIFICATION (PCP-23125): re-add on every upstream re-vendor
         of mcp-stack. <<<
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}

{{- define "mcp-stack.image.repository" -}}
  {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.image.bareRepository   (PCP-23125)
     FAIL-FAST guard on the one input the two zero-logic helpers above cannot
     validate for themselves. Takes an image repository value as its dot and
     echoes it back UNCHANGED — unless it ALREADY carries a registry host, in
     which case the render is aborted with an actionable message.

     THE DEFECT IT CATCHES. Every routed call site prepends the composed prefix
     blindly, so a value that is still fully qualified renders

       /tibco-platform-docker-prod/csgprdusw2reposaas.jfrog.io/tibco-platform-docker-dev/tp-mcp-gateway:TAG

     which lints clean, renders clean, and fails only at pull time on a customer
     Data Plane. Two entirely ordinary actions produce it: a hand override
     (--set mcp-stack.redis.image.repository=<a qualified ref> copied from a
     pre-PCP-23125 values file, or from a runbook) and — silently, with nothing
     typed at all — `helm upgrade --reuse-values` from any release older than
     PCP-23125, which replays the old qualified value over this chart's new bare
     default. That second case reaches the two sidecar `dig` chains in
     templates/deployment-mcpgateway.yaml as well, whose BARE `| default`
     fallbacks only cover the key being ABSENT, not present-and-stale. Aborting
     the render is the only outcome that surfaces it.

     WHY A FAIL AND NOT A SHORT-CIRCUIT. Detecting the host and skipping the
     prefix would make the chart quietly honour a PER-IMAGE registry: a second,
     undocumented precedence rule underneath the global one, so two Data Planes
     with the same global.cp.containerRegistry could pull from different
     registries with nothing in the rendered YAML explaining why. The house
     pattern has exactly ONE input; this keeps it that way and says so out loud
     instead. Same idiom, and the same reasoning, as the render-time `fail`s in
     the parent chart's templates/mode-validate.yaml and dialhome-validate.yaml,
     and as the malformed-digest / bare-repository `fail`s in mcp-stack.image below.

     THE RULE IS DOCKER'S OWN, NOT "contains a slash". A reference's first path
     segment is a REGISTRY only when a second segment follows it AND it carries
     a '.' or a ':' or is exactly `localhost`; otherwise it is part of the name.
     Keeping the rule that narrow is load-bearing twice over:
       - `ibm/mcp-context-forge` (namespaced, no host) still RENDERS, so the
         segment-shape rule that image-provenance-assert.sh and
         container-registry-assert.sh both rest on keeps a reachable mutation
         vector. A guard that swallowed every multi-segment value would leave
         that rule permanently unexercised — one piece of decoration guarding
         another.
       - it cannot fire on the third-party images this sub-chart deliberately
         keeps on their public registries (mcpFastTimeServer on ghcr.io,
         inspector on ghcr.io, the monitoring and testing stacks). Those are out
         of scope here — PCP-23128 owns them — and none of them is routed
         through this helper in the first place, so they are unaffected twice
         over. container-registry-assert.sh [6] renders fast-time-server on
         ghcr.io and must stay green; that is the standing proof.

     Pinned by dev/mcp-gateway-render-tests/container-registry-assert.sh [G].

     >>> KEEP IN SYNC (PCP-23125): BYTE-IDENTICAL apart from the name prefix with
         tp-mcp-gateway.image.bareRepository in
         charts/tp-mcp-gateway/templates/_helpers.tpl. <<<

     >>> LOCAL TIBCO MODIFICATION (PCP-23125): re-add on every upstream re-vendor
         of mcp-stack. <<<
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.image.bareRepository" -}}
{{- $repo := . | default "" | toString -}}
{{- $segments := splitList "/" $repo -}}
{{- $head := first $segments -}}
{{- if and (gt (len $segments) 1) (or (contains "." $head) (contains ":" $head) (eq $head "localhost")) -}}
{{- fail (printf "mcp-stack.image.bareRepository: the image repository %q already carries a registry host (%q). This chart composes <global.cp.containerRegistry.url>/<global.cp.containerRegistry.repository>/<bare name>, so that host would be prefixed a SECOND time and the pod would ask for a repository no registry can serve. Set this value to the bare name %q and point global.cp.containerRegistry.url / .repository at the registry instead. If you did not set it by hand: a helm upgrade --reuse-values from a release older than PCP-23125 replays the old fully-qualified value, so re-set the key explicitly or upgrade without --reuse-values." $repo $head (last $segments)) -}}
{{- end -}}
{{- $repo -}}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: mcp-stack.image   (PCP-23089)
     Compose a container image reference from a `{repository, tag, digest}`
     value block. Takes the IMAGE BLOCK ITSELF, not the chart context:

         {{ include "mcp-stack.image" .Values.mcpContextForge.image }}

     Four cases, following the upstream Helm convention (cert-manager,
     ingress-nginx):

       tag + digest  ->  repo:1.20.0@sha256:091e...   the shipped shape
       tag only      ->  repo:1.20.0                  today's shape, and what
                                                      a chart whose digest is
                                                      still unset renders
       digest only   ->  repo@sha256:091e...
       neither       ->  render-time failure

     The digest is what actually selects the content; the tag rides along so
     the version stays visible in `kubectl get pod -o wide`, dashboards and
     support tickets. A runtime given both resolves by the digest and ignores
     the tag, so carrying the tag costs nothing at pull time.

     The last case fails rather than rendering a bare repository, which the
     runtime would resolve as `:latest` — a silent floating pull into a
     customer Data Plane. A malformed digest fails here too, rather than at
     pull time on the DP.

     KEEP IN SYNC with "tp-mcp-gateway.image" in the PARENT chart. Two copies
     and not one: this sub-chart is also installed standalone (see
     dev/mcp-gateway-render-tests section F), and a disabled sub-chart's
     templates are not loaded into the parent's render — the same reason
     deployment-mcpgateway.yaml and lite-deployment.yaml already carry paired
     logic.
     -------------------------------------------------------------------- */}}
{{- define "mcp-stack.image" -}}
{{- $repo := .repository | default "" -}}
{{- /* NEITHER `default` nor `toString` alone is render-neutral, and the order matters:
       `.tag | default "" | toString` turns a legitimate `tag: 0` or `tag: false` into ""
       (Go treats both as empty), while `toString` first turns an ABSENT key into the
       string "<nil>". Guard the nil case explicitly, then stringify — verified to match
       the pre-helper `{{ .tag }}` output for 0, false, 1.20, "", absent and a plain
       string. An unquoted YAML `tag: 1.20` is a float64, and printf "%s" on one emits
       the Go error verb `%!s(float64=1.2)`, which is why the stringify is needed at all. */ -}}
{{- $tag := "" -}}{{- if not (kindIs "invalid" .tag) -}}{{- $tag = toString .tag -}}{{- end -}}
{{- $digest := "" -}}{{- if not (kindIs "invalid" .digest) -}}{{- $digest = toString .digest -}}{{- end -}}
{{- if and $digest (not (regexMatch "^sha256:[0-9a-f]{64}$" $digest)) -}}
{{- fail (printf "mcp-stack.image: %s has a malformed digest %q — expected sha256: followed by 64 lowercase hex characters" $repo $digest) -}}
{{- end -}}
{{- if and $tag $digest -}}{{- printf "%s:%s@%s" $repo $tag $digest -}}
{{- else if $tag -}}{{- printf "%s:%s" $repo $tag -}}
{{- else if $digest -}}{{- printf "%s@%s" $repo $digest -}}
{{- else -}}
{{- fail (printf "mcp-stack.image: %s has neither .tag nor .digest — refusing to render a bare repository, which the runtime resolves as :latest" $repo) -}}
{{- end -}}
{{- end -}}
