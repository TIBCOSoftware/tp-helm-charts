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
{{- define "dp-oauth2proxy-recipes.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dp-oauth2proxy-recipes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "dp-oauth2proxy-recipes.component" -}}dp-oauth2proxy-recipes{{- end }}

{{- define "dp-oauth2proxy-recipes.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "dp-oauth2proxy-recipes.team" -}}
{{- "cic-compute" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "dp-oauth2proxy-recipes.appName" }}dp-oauth2proxy-recipe{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "dp-oauth2proxy-recipes.labels" -}}
helm.sh/chart: {{ include "dp-oauth2proxy-recipes.chart" . }}
{{ include "dp-oauth2proxy-recipes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "dp-oauth2proxy-recipes.team" .}}
platform.tibco.com/component: {{ include "dp-oauth2proxy-recipes.component" . }}
platform.tibco.com/controlplane-instance-id: {{ .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dp-oauth2proxy-recipes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dp-oauth2proxy-recipes.name" . }}
app.kubernetes.io/component: {{ include "dp-oauth2proxy-recipes.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "dp-oauth2proxy-recipes.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "dp-oauth2proxy.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "dp-oauth2proxy.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "dp-oauth2proxy-recipes.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
  {{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "dp-oauth2proxy-recipes.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

