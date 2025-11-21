{{/* 
Copyright © 2025. Cloud Software Group, Inc.
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
{{- define "tibcohub-recipes.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tibcohub-recipes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tibcohub-recipes.component" -}}tibcohub-recipes{{- end }}

{{- define "tibcohub-recipes.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tibcohub-recipes.team" -}}
{{- "cic-compute" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tibcohub-recipes.appName" }}tp-dp-tibcohub-recipe{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "tibcohub-recipes.labels" -}}
helm.sh/chart: {{ include "tibcohub-recipes.chart" . }}
{{ include "tibcohub-recipes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tibcohub-recipes.team" .}}
platform.tibco.com/component: {{ include "tibcohub-recipes.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "tibcohub-recipes.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tibcohub-recipes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tibcohub-recipes.name" . }}
app.kubernetes.io/component: {{ include "tibcohub-recipes.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tibcohub-recipes.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tibcohub-recipes.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{- define "tibcohub-recipes.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tibcohub-recipes.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tibcohub-recipes.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tibcohub-recipes.enableResourceConstraints" -}}
{{- default "false" .Values.global.tibco.enableResourceConstraints | quote }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tibcohub-recipes.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

