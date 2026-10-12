{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
  This file is subject to the license terms contained
  in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-web-server.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tp-cp-web-server.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-web-server.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-web-server.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-web-server.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ .Values.global.tibco.controlPlaneInstanceId }}
{{- end -}}

{{- define "tp-cp-web-server.shared.labels.standard" -}}
{{ include  "tp-cp-web-server.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-web-server.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-web-server.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/*
  Label helpers for the STANDALONE DP MCP aggregator Deployment. These mirror the
  web-server label helpers but override app.kubernetes.io/name with the aggregator's
  own appName so the aggregator Services (external :8080 + internal :8081) select
  ONLY the aggregator pod, DISJOINT from the web-server selector.
*/}}
{{- define "tp-cp-mcp-aggregator.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-mcp-aggregator.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-web-server.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-web-server.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ .Values.global.tibco.controlPlaneInstanceId }}
{{- end -}}

{{- define "tp-cp-mcp-aggregator.shared.labels.standard" -}}
{{ include  "tp-cp-mcp-aggregator.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-web-server.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-web-server.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "cp-core-configuration.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
   {{- "control-plane-sa" }}
{{- else -}}
   {{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}


