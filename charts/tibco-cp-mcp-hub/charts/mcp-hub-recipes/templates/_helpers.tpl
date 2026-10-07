{{/*
Copyright © 2026. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}


{{/*
================================================================
                  SECTION COMMON VARS
================================================================
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "mcp-hub-recipes.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mcp-hub-recipes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "mcp-hub-recipes.component" -}}mcp-hub-recipes{{- end }}

{{- define "mcp-hub-recipes.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "mcp-hub-recipes.team" -}}
{{- "platform-mcp-hub" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "mcp-hub-recipes.appName" }}mcp-hub-recipe-extraction{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================
*/}}

{{/*
Common labels
*/}}
{{- define "mcp-hub-recipes.labels" -}}
helm.sh/chart: {{ include "mcp-hub-recipes.chart" . }}
{{ include "mcp-hub-recipes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "mcp-hub-recipes.team" .}}
platform.tibco.com/component: {{ include "mcp-hub-recipes.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "mcp-hub-recipes.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mcp-hub-recipes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcp-hub-recipes.name" . }}
app.kubernetes.io/component: {{ include "mcp-hub-recipes.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "mcp-hub-recipes.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "mcp-hub-recipes.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{- define "mcp-hub-recipes.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "mcp-hub-recipes.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty.

     PCP-21919 / PCP-9150 -- keep this resolution order identical to
     mcp-hub-webserver.container-registry.secret; the full rationale lives there.
       1. .Values.imagePullSecret                    explicit per-release override
       2. global.cp.containerRegistry.secret         DP wiring (measured); checked first so a
                                                     customer Secret beats a CP-minted one
       3. global.tibco.containerRegistry.secret      CP wiring (measured) -- the arm that
                                                     actually fires for this chart on a CP
       4. username + password                        legacy minted Secret. UNCHANGED.
       5. none                                       empty -> caller omits imagePullSecrets

     Parenthesised traversal is required, not stylistic: `global.cp` is absent unless the CP
     injects it, and a bare lookup would abort the render with a nil-pointer error. */}}
{{- define "mcp-hub-recipes.container-registry.secret" }}
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
{{- define "mcp-hub-recipes.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}
