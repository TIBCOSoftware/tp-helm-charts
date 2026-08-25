{{/*
Chart name and version for labels.
*/}}
{{- define "tp-mcp-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The gateway chart is a stateless passthrough for path isolation. A Data Plane can host >1
MCP Gateway, but per-instance PATH isolation is owned entirely by the caller (the MCP Hub) — the chart
no longer derives any per-instance path suffix from global.cp.instanceId. The COMPLETE per-instance
paths are composed by the Hub from its own stable gateway id and passed in verbatim via
haproxy.pathPrefix / publicApi.pathPrefix, which the chart renders as-is. This
keeps path/routing rendering CP-independent so it is identical whether deployed by the Hub (CP-managed)
or standalone (operator-supplied values).
Discovery (PCP-20569, Option B): there is NO dedicated discovery Ingress and NO :8080 discovery
Service anymore. The MCP discovery sidecar is routed entirely IN-POD by the tp-mcp-gateway-proxy sidecar:
the proxy fronts the gateway on :81 (cp-internal) and path-routes the <subPath> prefix (default
"_discovery", relative to the single gateway haproxy.pathPrefix) to the in-pod discovery upstream
(http://127.0.0.1:8080). Because the proxy is the inbound front, discovery.enabled now IMPLIES the
:81 front (the haproxy ingress + Service select :81 when EITHER tibcoProxy.enabled OR
discovery.enabled). The leading-slash sub-path is rendered by tp-mcp-gateway.discoverySubPath below
and injected into the proxy as DISCOVERY_PATH_PREFIX. discovery.pathPrefix is retained as a no-op
back-compat key (no longer read).
Note: global.cp.instanceId is STILL consumed elsewhere in the chart (e.g. the
platform.tibco.com/capability-instance-id metadata label below); it is simply no longer part of
path/routing rendering.
*/}}

{{/*
Common labels — superset, used in metadata.labels.
Spec: https://tibco.atlassian.net/wiki/spaces/TCP/pages/396158725/Monitoring+and+k8s+metadata
*/}}
{{- define "tp-mcp-gateway.labels" -}}
helm.sh/chart: {{ include "tp-mcp-gateway.chart" . }}
{{ include "tp-mcp-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels — stable identity, used in selectors and pod template.
Required by the Confluence spec for monitor-agent discovery and CP
capability health lookup. Do not drift from these names/values.
*/}}
{{- define "tp-mcp-gateway.selectorLabels" -}}
app.kubernetes.io/name: tp-mcp-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "mcp-hub"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
o11y-service ConfigMap name — same as bwprovisioner.
*/}}
{{- define "tp-mcp-gateway.o11yservice.configmap" }}o11y-service{{ end -}}

{{/*
CP proxy domain — used by tp-mcp-gateway-proxy sidecar to reach cp-proxy.
*/}}
{{- define "tp-mcp-gateway.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{/*
Gateway service name — differs between lite and full mode. In full mode this is the value
service-mcp.yaml renders for the Service: {{ include "mcp-stack.fullname" . }}-mcpgateway, which
for the (deterministic, release-scoped) mcp-stack.fullname is always <release>-mcp-stack-mcpgateway.
We emit that literal here rather than calling `include "mcp-stack.fullname"` directly, because the
subchart's named templates are NOT loaded when the dependency is excluded (lite.enabled=false AND
mcp-stack.enabled=false), and the cross-chart include would then fail with a confusing "no template"
error. Lockstep with the rendered Service is enforced by tests/fullname-collision-assert.sh, which
asserts serviceName == the rendered Service name across all inputs. mcp-stack.fullname ignores both
fullnameOverride and nameOverride, so the backend never diverges from the Service (PCP-20591).
*/}}
{{- define "tp-mcp-gateway.serviceName" -}}
{{- if .Values.lite.enabled -}}
{{ .Release.Name }}-mcp-gateway
{{- else -}}
{{ .Release.Name }}-mcp-stack-mcpgateway
{{- end -}}
{{- end }}

{{/*
Public OAuth audience base — a BARE ORIGIN (scheme://host), no path, no trailing slash.
Used as APP_DOMAIN, the inbound-OAuth audience trust anchor (PCP-20050). The gateway itself
appends APP_ROOT_PATH + /servers/<id>/mcp, so this MUST stay a bare origin (also the contract
the email/admin/CSRF URL builders rely on — embedding the path here would double-prefix them).
Host precedence: explicit publicApi.appDomain override -> ingress.fqdn -> Gateway API host.
Returns "" when none resolve, so callers omit APP_DOMAIN and the gateway keeps its own default.
*/}}
{{- define "tp-mcp-gateway.appDomain" -}}
{{- if and .Values.publicApi .Values.publicApi.appDomain -}}
{{- .Values.publicApi.appDomain | trimSuffix "/" -}}
{{- else -}}
{{- $r := .Values.global.cp.resources -}}
{{- $host := "" -}}
{{- if and $r $r.ingress $r.ingress.fqdn -}}
{{- $host = $r.ingress.fqdn -}}
{{- else if and $r $r.gatewayapi $r.gatewayapi.gatewayHostOrDomainName -}}
{{- $host = $r.gatewayapi.gatewayHostOrDomainName -}}
{{- end -}}
{{- if $host -}}
{{- printf "https://%s" $host -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
>>> LOCAL TIBCO MODIFICATION (PCP-20593) <<<
Parent-chart twin of the subchart's mcp-stack.storageClassName helper.

A subchart-defined template is NOT callable from the parent chart, so the LITE
PVC (templates/lite-pvc.yaml) re-declares the identical resolution here. KEEP IN
SYNC with mcp-stack.storageClassName in
charts/tp-mcp-gateway/charts/mcp-stack/templates/_helpers.tpl — same
precedence and same "-" sentinel.

Precedence:
  (1) the passed `local` value (lite.storage.className), if non-empty;
  (2) else the orchestrator-injected global.cp.resources.storage.storageClassName
      (full deep-guarded chain so a standalone render without global cannot panic);
  (3) else output NOTHING — the caller omits the key (cluster DEFAULT StorageClass).
"-" SENTINEL: when the EFFECTIVE value resolves to "-" this returns the two-char
literal `""` so the caller emits `storageClassName: ""` (no dynamic provisioning),
never the Helm-rejected bare `storageClassName: -`. Mirrors common.storage.class.

NOTE (Hub recipe path): lite.storage.className is set to ${STORAGE_CLASS_NAME},
so the local value still WINS there — this only adds a global fallback for the
empty-local case; no regression to the recipe path.
*/}}
{{- define "tp-mcp-gateway.storageClassName" -}}
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
{{- end }}

{{/*
Normalized public path prefix — "" or "/clean-segment" (single leading slash, no trailing slash).
trimAll collapses "", "/", and trailing-slash inputs uniformly so APP_ROOT_PATH, OAUTH_REDIRECT_URI,
and the public ingress/route paths render without double slashes regardless of how the operator or
recipe formats publicApi.pathPrefix (PCP-20050).
*/}}
{{- define "tp-mcp-gateway.pathPrefix" -}}
{{- $p := .Values.publicApi.pathPrefix | default "" | trimAll "/" -}}
{{- if $p -}}{{- printf "/%s" $p -}}{{- end -}}
{{- end }}

{{/*
Discovery in-pod sub-path (PCP-20569, Option B). The tp-mcp-gateway-proxy sidecar path-routes this
LEADING-SLASH sub-path to the in-pod discovery upstream — injected as DISCOVERY_PATH_PREFIX.
Returns "/<clean-segment>" (single leading slash, no trailing slash). The subPath is fully
normalized via trimAll " /" (any surrounding whitespace AND leading/trailing slashes collapsed);
discovery.subPath defaults to "_discovery". A slash-only/whitespace-only subPath ("/", "//", "  ")
is truthy so `default` skips it, yet trimAll collapses it to "" — re-default when the trimmed result
is empty so a spaced/slash-only subPath can't yield a malformed prefix and discovery never overlaps
the gateway root. discovery.pathPrefix is intentionally NOT read here.
NOTE: discovery.subPath is honored only in LITE mode — full mode hardcodes the literal "/_discovery"
in charts/mcp-stack/templates/deployment-mcpgateway.yaml because a sub-chart cannot read the parent's
discovery.subPath. A non-default subPath is therefore lite-only.
*/}}
{{- define "tp-mcp-gateway.discoverySubPath" -}}
{{- $sub := .Values.discovery.subPath | default "_discovery" | trimAll " /" -}}
{{- if not $sub -}}{{- $sub = "_discovery" -}}{{- end -}}
{{- printf "/%s" $sub -}}
{{- end }}

{{- /* --------------------------------------------------------------------
     Helper: tp-mcp-gateway.fluentbit.enabled   (PCP-22768)
     Nil-safe walk of .Values.global.tibco.logging.fluentbit.enabled — returns
     the string "true" ONLY when every nesting level exists and `enabled` is
     truthy, else the empty string. Used by the lite-deployment template to gate
     the lite-mode fluentbit sidecar. Mirrors mcp-stack.fluentbit.enabled in the
     vendored sub-chart (which gates full mode). Nil-safe so a --reuse-values
     upgrade dropping the nested block cannot error.
     -------------------------------------------------------------------- */}}
{{- define "tp-mcp-gateway.fluentbit.enabled" -}}
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
     Helpers: tp-mcp-gateway.image.registry / tp-mcp-gateway.image.repository  (PCP-23125)
     Container-registry indirection. Copied from
     charts/tp-dp-infra-mcp-server/templates/_helpers.tpl:57-69 and adapted ONLY in
     name — the house pattern shared by every DP-installed capability chart
     (bwprovisioner:83-90, tp-dp-apim:82-89, tp-dp-discovery-service:55-62,
     dp-bw-adapter:84-91, o11y-service:104-111, ...). They are ZERO-LOGIC on
     purpose: byte-identical to the canonical block in 13 sibling charts, reading
     global.cp.containerRegistry and nothing else. Do not add a branch, a
     short-circuit or a nil-safe traversal here — nil-safety comes from DECLARING
     global.cp.containerRegistry in this chart's values.yaml (and in
     charts/mcp-stack/values.yaml, which is what makes the ct standalone render
     nil-safe), exactly as the siblings do.

     HOW THEY ARE USED. Call sites compose the EFFECTIVE repository
     <registry>/<repository>/<bare-name> and pass it to "tp-mcp-gateway.image"
     (PCP-23214) as the `repository` key of the image block, so tag and digest
     still travel through that ONE helper:

         $img := merge (dict "repository" <composed>) .Values.lite.image
         image: include "tp-mcp-gateway.image" $img | quote

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

     STYLE MODEL is the fluentbit.enabled twin (this file :181-202 and
     charts/mcp-stack/templates/_helpers.tpl:599-620): the same dashed banner on
     BOTH sides and defines that are byte-identical modulo the name prefix. The
     storageClassName twin is NOT — it uses a different comment delimiter on each
     side and its closing `end` carries the right-trim marker in the sub-chart but
     not here (a full-define diff reports 16c16). That divergence is historical,
     not meaningful; do not reproduce it and do not "fix" it there.

     BANNER HYGIENE: keep template delimiters out of this comment. A stray
     comment-close sequence inside a Go-template comment ends it early, and every
     line after it is then parsed as live template actions.

     >>> KEEP IN SYNC (PCP-23125): the two defines below are BYTE-IDENTICAL apart
         from the name prefix with mcp-stack.image.registry /
         mcp-stack.image.repository in
         charts/tp-mcp-gateway/charts/mcp-stack/templates/_helpers.tpl. A
         subchart-defined template is NOT callable from the parent (see the note
         at :111-133 above), so the pair is duplicated on purpose — same
         discipline as the storageClassName and fluentbit.enabled twins. <<<
     -------------------------------------------------------------------- */}}
{{- define "tp-mcp-gateway.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}

{{- define "tp-mcp-gateway.image.repository" -}}
  {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: tp-mcp-gateway.image.bareRepository   (PCP-23125)
     FAIL-FAST guard on the one input the two zero-logic helpers above cannot
     validate for themselves. Takes an image repository value as its dot and
     echoes it back UNCHANGED — unless it ALREADY carries a registry host, in
     which case the render is aborted with an actionable message.

     THE DEFECT IT CATCHES. Every routed call site prepends the composed prefix
     blindly, so a value that is still fully qualified renders

       /tibco-platform-docker-prod/csgprdusw2reposaas.jfrog.io/tibco-platform-docker-dev/tp-mcp-gateway:TAG

     which lints clean, renders clean, and fails only at pull time on a customer
     Data Plane. Two entirely ordinary actions produce it: a hand override
     (--set lite.image.repository=<a qualified ref> copied from a pre-PCP-23125
     values file, or from a runbook) and — silently, with nothing typed at all —
     `helm upgrade --reuse-values` from any release older than PCP-23125, which
     replays the old qualified value over this chart's new bare default. Aborting
     the render is the only outcome that surfaces the second case.

     WHY A FAIL AND NOT A SHORT-CIRCUIT. Detecting the host and skipping the
     prefix would make the chart quietly honour a PER-IMAGE registry: a second,
     undocumented precedence rule underneath the global one, so two Data Planes
     with the same global.cp.containerRegistry could pull from different
     registries with nothing in the rendered YAML explaining why. The house
     pattern has exactly ONE input; this keeps it that way and says so out loud
     instead. Same idiom, and the same reasoning, as the render-time `fail`s in
     templates/mode-validate.yaml and templates/dialhome-validate.yaml, and as
     the malformed-digest / bare-repository `fail`s in tp-mcp-gateway.image below.

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
       - it cannot fire on the third-party images that deliberately keep their
         public registries (ghcr.io/ibm/fast-time-server,
         ghcr.io/modelcontextprotocol/inspector, the monitoring/testing stacks).
         Those are out of scope here — PCP-23128 owns them — and none of them is
         routed through this helper in the first place, so they are unaffected
         twice over. container-registry-assert.sh [6] renders fast-time-server on
         ghcr.io and must stay green; that is the standing proof.

     Pinned by dev/mcp-gateway-render-tests/container-registry-assert.sh [G].

     >>> KEEP IN SYNC (PCP-23125): BYTE-IDENTICAL apart from the name prefix with
         mcp-stack.image.bareRepository in
         charts/tp-mcp-gateway/charts/mcp-stack/templates/_helpers.tpl. <<<
     -------------------------------------------------------------------- */}}
{{- define "tp-mcp-gateway.image.bareRepository" -}}
{{- $repo := . | default "" | toString -}}
{{- $segments := splitList "/" $repo -}}
{{- $head := first $segments -}}
{{- if and (gt (len $segments) 1) (or (contains "." $head) (contains ":" $head) (eq $head "localhost")) -}}
{{- fail (printf "tp-mcp-gateway.image.bareRepository: the image repository %q already carries a registry host (%q). This chart composes <global.cp.containerRegistry.url>/<global.cp.containerRegistry.repository>/<bare name>, so that host would be prefixed a SECOND time and the pod would ask for a repository no registry can serve. Set this value to the bare name %q and point global.cp.containerRegistry.url / .repository at the registry instead. If you did not set it by hand: a helm upgrade --reuse-values from a release older than PCP-23125 replays the old fully-qualified value, so re-set the key explicitly or upgrade without --reuse-values." $repo $head (last $segments)) -}}
{{- end -}}
{{- $repo -}}
{{- end -}}

{{- /* --------------------------------------------------------------------
     Helper: tp-mcp-gateway.image   (PCP-23089)
     Compose a container image reference from a `{repository, tag, digest}`
     value block. Takes the IMAGE BLOCK ITSELF, not the chart context:

         {{ include "tp-mcp-gateway.image" .Values.lite.image }}

     Four cases, following the upstream Helm convention (cert-manager,
     ingress-nginx):

       tag + digest  ->  repo:1.20.0@sha256:091e...   the shipped shape
       tag only      ->  repo:1.20.0                  today's shape, and what
                                                      a chart whose digest is
                                                      still unset renders
       digest only   ->  repo@sha256:091e...
       neither       ->  render-time failure

     WHY `:tag@digest` AND NOT `@digest` ALONE. A bare digest is a complete and
     correct reference — the runtime resolves content by the digest and ignores
     the tag when both are present — but it erases the version from
     `kubectl get pod -o wide`, from dashboards and from support tickets. The
     tag therefore costs nothing at pull time and buys back readability. The
     pair is written by ONE release-alpha.sh run from ONE build, so the two
     fields describe the same artifact by construction of the writer; the
     digest is what is actually enforced.

     WHY THE LAST CASE FAILS. Rendering a bare repository makes the runtime
     resolve `:latest` — a silent floating pull into a customer Data Plane.
     Same class of guard as the empty-tag check in dialhome-validate.yaml.
     A malformed digest fails here too, rather than at pull time on the DP.

     KEEP IN SYNC with "mcp-stack.image" in the vendored sub-chart, which is
     this same helper for full mode. Two copies and not one, because the
     sub-chart is ALSO installed standalone (dev/mcp-gateway-render-tests
     section F) and because a disabled sub-chart's templates are not loaded
     into the parent's render — the same reason lite-deployment.yaml and
     deployment-mcpgateway.yaml already carry paired logic.
     -------------------------------------------------------------------- */}}
{{- define "tp-mcp-gateway.image" -}}
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
{{- fail (printf "tp-mcp-gateway.image: %s has a malformed digest %q — expected sha256: followed by 64 lowercase hex characters" $repo $digest) -}}
{{- end -}}
{{- if and $tag $digest -}}{{- printf "%s:%s@%s" $repo $tag $digest -}}
{{- else if $tag -}}{{- printf "%s:%s" $repo $tag -}}
{{- else if $digest -}}{{- printf "%s@%s" $repo $digest -}}
{{- else -}}
{{- fail (printf "tp-mcp-gateway.image: %s has neither .tag nor .digest — refusing to render a bare repository, which the runtime resolves as :latest" $repo) -}}
{{- end -}}
{{- end -}}
