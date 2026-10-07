{{/*
Copyright © 2026. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "mcp-hub-webserver.consts.appName" }}tp-cp-mcp-hub-webserver{{ end -}}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}
{{- define "mcp-hub-webserver.cp-env-configmap" }}cp-env{{ end -}}


{{/* Create chart name and version as used by the chart label. */}}
{{- define "mcp-hub-webserver.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "mcp-hub-webserver.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "mcp-hub-webserver.consts.appName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "mcp-hub-webserver.cp-instance-id" . }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "mcp-hub-webserver.shared.labels.standard" -}}
{{ include  "mcp-hub-webserver.shared.labels.selector" . }}
helm.sh/chart: {{ include "mcp-hub-webserver.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}


{{- define "mcp-hub-webserver.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "mcp-hub-webserver.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/*
mcp-hub-webserver.image   (PCP-23089)
The full webserver image reference: <registry>/<repository>/tp-mcp-hub, then

  tag + digest  ->  ...:1.20.0@sha256:091e...   the shipped shape
  tag only      ->  ...:1.20.0                  today's shape, and what a chart
                                                whose digest is still unset renders
  digest only   ->  ...@sha256:091e...
  neither       ->  render-time failure

The digest is what selects the content; the tag rides along so the version stays
readable. A runtime given both resolves by the digest and ignores the tag.

MCP_HUB_WEBSERVER_IMAGE_TAG is deliberately NOT reused for the digest: it is also
written to the `platform.tibco.com/app-version` LABEL (deployment.yaml) and to an
env var, and a Kubernetes label value admits only alphanumerics, '-', '_' and '.'
— a `@sha256:` suffix would make the Deployment invalid. Hence a second key,
consumed here only.

Mirrors "tp-mcp-gateway.image" / "mcp-stack.image" in the gateway chart.
*/}}
{{- define "mcp-hub-webserver.image" -}}
{{- $repo := printf "%s/%s/tp-mcp-hub" (include "mcp-hub-webserver.image.registry" .) (include "mcp-hub-webserver.image.repository" .) -}}
{{- /* NEITHER `default` nor `toString` alone is render-neutral, and the order matters:
       `.tag | default "" | toString` turns a legitimate `tag: 0` or `tag: false` into ""
       (Go treats both as empty), while `toString` first turns an ABSENT key into the
       string "<nil>". Guard the nil case explicitly, then stringify — verified to match
       the pre-helper `{{ .tag }}` output for 0, false, 1.20, "", absent and a plain
       string. An unquoted YAML `tag: 1.20` is a float64, and printf "%s" on one emits
       the Go error verb `%!s(float64=1.2)`, which is why the stringify is needed at all. */ -}}
{{- $tag := "" -}}{{- if not (kindIs "invalid" .Values.config.MCP_HUB_WEBSERVER_IMAGE_TAG) -}}{{- $tag = toString .Values.config.MCP_HUB_WEBSERVER_IMAGE_TAG -}}{{- end -}}
{{- $digest := "" -}}{{- if not (kindIs "invalid" .Values.config.MCP_HUB_WEBSERVER_IMAGE_DIGEST) -}}{{- $digest = toString .Values.config.MCP_HUB_WEBSERVER_IMAGE_DIGEST -}}{{- end -}}
{{- if and $digest (not (regexMatch "^sha256:[0-9a-f]{64}$" $digest)) -}}
{{- fail (printf "mcp-hub-webserver.image: MCP_HUB_WEBSERVER_IMAGE_DIGEST is malformed (%q) — expected sha256: followed by 64 lowercase hex characters" $digest) -}}
{{- end -}}
{{- if and $tag $digest -}}{{- printf "%s:%s@%s" $repo $tag $digest -}}
{{- else if $tag -}}{{- printf "%s:%s" $repo $tag -}}
{{- else if $digest -}}{{- printf "%s@%s" $repo $digest -}}
{{- else -}}
{{- fail "mcp-hub-webserver.image: neither MCP_HUB_WEBSERVER_IMAGE_TAG nor MCP_HUB_WEBSERVER_IMAGE_DIGEST is set — refusing to render a bare repository, which the runtime resolves as :latest" -}}
{{- end -}}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "mcp-hub-webserver.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty.

     PCP-21919 / PCP-9150 -- a customer on a custom container registry hands the Control Plane
     a PRE-EXISTING pull Secret instead of raw credentials, so resolve in this order:
       1. .Values.imagePullSecret                    explicit per-release override (pre-existing
                                                     behaviour; must keep winning)
       2. global.cp.containerRegistry.secret         DATA-PLANE wiring. First because if the CP
                                                     ever injects it too it carries the CUSTOMER's
                                                     Secret while (3) carries the CP-minted one.
       3. global.tibco.containerRegistry.secret      CONTROL-PLANE wiring -- the arm that actually
                                                     fires for this chart today. DO NOT REMOVE.
       4. username + password                        legacy: the Secret the CP mints. UNCHANGED.
       5. none of the above                          empty -> every caller omits the
                                                     imagePullSecrets key entirely.

     Both (2) and (3) are honoured because the two planes are wired differently; measured on a
     live instance, with the per-release evidence, in the PCP-21919 commit body and PR #10098.

     The parenthesised traversal is deliberate, not style: `global.cp` is absent unless the CP
     injects it, and a bare .Values.global.cp.containerRegistry.secret aborts the render with
     "nil pointer evaluating interface {}.containerRegistry" in that case. */}}
{{- define "mcp-hub-webserver.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else if (((.Values.global).cp).containerRegistry).secret }}
  {{- (((.Values.global).cp).containerRegistry).secret }}
{{- else if (((.Values.global).tibco).containerRegistry).secret }}
  {{- (((.Values.global).tibco).containerRegistry).secret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "mcp-hub-webserver.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "mcp-hub-webserver.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else if eq .Values.global.tibco.mcpHub.mode "standalone" }}
  {{- /* PCP-20304: standalone has no CP-provisioned `cp1-sa`, so use the namespace
         `default` SA. Referencing a non-existent SA blocks pod creation (PVC then hangs
         Pending). The standalone hub makes no k8s API calls → the default SA suffices.
         CP mode (mode=cp) is unchanged → keeps global.tibco.serviceAccount (cp1-sa). */}}
  {{- "default" }}
{{- else }}
  {{- default "" .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{/*
CP OTel collector host — the OTLP log INGRESS the FluentBit sidecar forwards to.
This MUST be the `otel-services` collector (it owns the CP logs pipeline →
Elasticsearch `tibco-cp-logs`), NOT `o11y-service` (the o11y query backend, which
listens on 7820 and has no 4318/OTLP listener). PCP-19635: the prior body
returned `o11y-service.<ns>` while the comment said otel-services, so Hub logs
were POSTed to a port nothing listens on and never reached ES. Verified on a live
CP that otel-services.<ns>.svc.cluster.local:4318 /v1/logs lands docs in
tibco-cp-logs. (Renamed from the misleading `o11y-service-host`.)
*/}}
{{- define "mcp-hub-webserver.otel-collector-host" }}
{{- "otel-services."}}{{ .Release.Namespace }}{{".svc.cluster.local" }}
{{- end }}

{{/* Control plane database configuration configmap name (read by the postgres pre-install Job and PG env vars) */}}
{{- define "mcp-hub-webserver.consts.db.configuration" }}provider-cp-database-config{{ end -}}

{{/* Control plane database master credentials Secret (read by the postgres pre-install Job to create per-app user/db) */}}
{{- define "mcp-hub-webserver.consts.db.credentials" }}provider-cp-database-credentials{{ end -}}

{{/* Control plane core env ConfigMap. Holds optional per-app tunables such as
     `<chart>.psqlMaxOpenConnections` etc., referenced via configMapKeyRef +
     optional: true so absent keys leave the env unset (backend then uses its
     hardcoded defaults). Centralized so all CP charts reference the same name. */}}
{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}

{{/* Control plane base env ConfigMap (created by the tibco-cp-base release).
     Holds platform-wide values such as CP_DNS_DOMAIN (= global.external.dnsDomain,
     wildcard-free). Referenced by configMapKeyRef so the value tracks the rest of
     the control plane. */}}
{{- define "tp-control-plane-base-env-configmap" }}cp-env{{ end -}}
