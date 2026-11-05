{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
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
{{- define "mft-recipes.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mft-recipes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "mft-recipes.component" -}}mft-recipes{{- end }}

{{- define "mft-recipes.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "mft-recipes.team" -}}
{{- "tibco-platform-mft" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "mft-recipes.appName" }}tp-cp-mft-recipes{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================
*/}}

{{/*
Common labels
*/}}
{{- define "mft-recipes.labels" -}}
helm.sh/chart: {{ include "mft-recipes.chart" . }}
{{ include "mft-recipes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "mft-recipes.team" .}}
platform.tibco.com/component: {{ include "mft-recipes.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "mft-recipes.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mft-recipes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mft-recipes.name" . }}
app.kubernetes.io/component: {{ include "mft-recipes.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "mft-recipes.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "mft-recipes.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{- define "mft-recipes.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "mft-recipes.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "mft-recipes.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "mft-recipes.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}
