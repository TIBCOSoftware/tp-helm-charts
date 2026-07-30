{{/*
Copyright © 2026. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Chart name and version for labels.
*/}}
{{- define "tp-infra-mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname — hardcoded, matching provisioner pattern.
*/}}
{{- define "tp-infra-mcp-server.fullname" }}tp-dp-infra-mcp-server{{ end -}}

{{/*
Common labels.
*/}}
{{- define "tp-infra-mcp-server.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "tp-infra-mcp-server.chart" . }}
platform.tibco.com/capability: infra-mcp-server
{{ include "tp-infra-mcp-server.selectorLabels" . }}
{{- end }}

{{/*
Selector labels — includes platform-specific labels matching provisioner pattern.
*/}}
{{- define "tp-infra-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "infra-mcp"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
ServiceAccount name — supports BYOSA (bring your own service account).
*/}}
{{- define "tp-infra-mcp-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
  {{- .Values.serviceAccount.name -}}
{{- else -}}
  {{- include "tp-infra-mcp-server.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
CP domain — cp-proxy service in the DP namespace.
*/}}
{{- define "tp-infra-mcp-server.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{/*
Image registry.
*/}}
{{- define "tp-infra-mcp-server.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}

{{/*
Image repository.
*/}}
{{- define "tp-infra-mcp-server.image.repository" -}}
  {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}
