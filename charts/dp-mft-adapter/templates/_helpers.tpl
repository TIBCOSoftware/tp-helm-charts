{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
  This file is subject to the license terms contained
  in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "mftadapter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fixed workload / service / DNS name. The MFT webserver and MCP server reach the adapter
at this in-cluster name, so it is intentionally not release-name derived.
*/}}
{{- define "mftadapter.fullname" }}mftadapter{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mftadapter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mftadapter.labels" -}}
helm.sh/chart: {{ include "mftadapter.chart" . }}
{{ include "mftadapter.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mftadapter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mftadapter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "mft"
platform.tibco.com/workload-type: "infra"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
CP proxy domain the adapter uses to pull the on-prem instance registry (tokenless, BW pattern).
*/}}
{{- define "mftadapter.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{/*
OTLP metrics endpoint — the DP user-app metrics collector (HTTP input on :4318).
*/}}
{{- define "mftadapter.otlp.metricsUrl" }}http://otel-userapp-metrics.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local:4318/v1/metrics{{ end -}}

{{/* Container image registry + repository come from the CP-injected global contract. */}}
{{- define "mftadapter.image.registry" -}}
{{- .Values.global.cp.containerRegistry.url -}}
{{- end -}}

{{- define "mftadapter.image.repository" -}}
{{- .Values.global.cp.containerRegistry.repository -}}
{{- end -}}
