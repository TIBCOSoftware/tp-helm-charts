{{/*
#
# Copyright © 2023 - 2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "dp-config-opensearch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "dp-config-opensearch.fullname" -}}
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
{{- define "dp-config-opensearch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dp-config-opensearch.labels" -}}
helm.sh/chart: {{ include "dp-config-opensearch.chart" . }}
{{ include "dp-config-opensearch.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dp-config-opensearch.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dp-config-opensearch.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
OpenSearch service name
*/}}
{{- define "dp-config-opensearch.opensearchServiceName" -}}
{{- printf "%s-master" .Values.opensearch.clusterName }}
{{- end }}

{{/*
OpenSearch Dashboards service name
*/}}
{{- define "dp-config-opensearch.dashboardsServiceName" -}}
{{- printf "%s-dashboards" .Release.Name }}
{{- end }}
