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
{{- define "flogo-recipes.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flogo-recipes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flogo-recipes.component" -}}flogo-recipes{{- end }}

{{- define "flogo-recipes.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "flogo-recipes.team" -}}
{{- "platform-flogo-base" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "flogo-recipes.appName" }}flogo-recipe-extraction{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "flogo-recipes.labels" -}}
helm.sh/chart: {{ include "flogo-recipes.chart" . }}
{{ include "flogo-recipes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "flogo-recipes.team" .}}
platform.tibco.com/component: {{ include "flogo-recipes.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "flogo-recipes.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flogo-recipes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flogo-recipes.name" . }}
app.kubernetes.io/component: {{ include "flogo-recipes.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "flogo-recipes.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "flogo-recipes.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{- define "flogo-recipes.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "flogo-recipes.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "flogo-recipes.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "flogo-recipes.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}
