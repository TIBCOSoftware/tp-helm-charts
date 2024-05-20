{{/*
Copyright © 2024. Cloud Software Group, Inc.
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
{{- define "compositions.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "compositions.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "compositions.component" -}}compositions{{- end }}

{{- define "compositions.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "compositions.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "compositions.appName" -}}
{{- "compositions" }}
{{- end }}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "compositions.labels" -}}
helm.sh/chart: {{ include "compositions.chart" . }}
{{ include "compositions.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "compositions.team" .}}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "compositions.selectorLabels" -}}
app.kubernetes.io/name: {{ include "compositions.name" . }}
app.kubernetes.io/component: {{ include "compositions.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "compositions.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
