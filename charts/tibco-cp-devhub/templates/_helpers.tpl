{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tibcohub-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "tibcohub-base.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tibcohub-base.component" -}}tibcohub-base{{- end }}

{{- define "tibcohub-base.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tibcohub-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tibcohub-base.name" . }}
app.kubernetes.io/component: {{ include "tibcohub-base.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tibcohub-base.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tibcohub-base.team" -}}
{{- "cic-compute" }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tibcohub-base.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tibcohub-base.labels" -}}
helm.sh/chart: {{ include "tibcohub-base.chart" . }}
{{ include "tibcohub-base.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tibcohub-base.team" .}}
platform.tibco.com/component: {{ include "tibcohub-base.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "tibcohub-base.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tibcohub-base.enableResourceConstraints" -}}
{{- default "false" .Values.global.tibco.enableResourceConstraints | quote }}
{{- end }}

{{- define "tibcohub-base.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{- define "tibcohub-base.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tibcohub-base.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}