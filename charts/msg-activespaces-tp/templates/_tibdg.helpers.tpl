{{/*
Expand the name of the chart.
*/}}
{{- define "tibdg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tibdg.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tibdg.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tibdg.labels" -}}
helm.sh/chart: {{ include "tibdg.chart" . }}
{{ include "tibdg.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tibdg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tibdg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create a pipe-delimited FTL server url
adapted from https://stackoverflow.com/a/49147648/8370398
*/}}
{{- define "ftl-server-url" -}}
{{- $corename := printf "%s-core" (include "msg.as.basename" .) -}}
{{- $ftl := dict "servers" (list) -}}
{{- $scheme := $.Values.secure.tls | ternary "https" "http" -}}
{{- range until ( int $.Values.ftlserver.count ) }}
{{- $noop := printf "%s://%s-%d.%s-pods:%d" $scheme $corename . $corename (int $.Values.ftlserver.ports.http) | append $ftl.servers | set $ftl "servers" -}}
{{- end -}}
{{- join "|" $ftl.servers -}}
{{- end -}}
