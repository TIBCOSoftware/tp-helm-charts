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
platform.tibco.com/controlplane-instance-id: {{ include "dp-oauth2proxy-recipes.cp-instance-id" . }}
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


{{- define "dp-oauth2proxy-recipes.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "dp-oauth2proxy-recipes.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "dp-oauth2proxy-recipes.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "dp-oauth2proxy-recipes.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "dp-oauth2proxy-recipes.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{- define "dp-oauth2proxy.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "reldocker.tibco.com" "required" "false" "Release" .Release )}}
  {{- end }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "dp-oauth2proxy.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "dp-oauth2proxy.image.registry" .) }} 
    {{- include "dp-oauth2proxy-recipes.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "dp-oauth2proxy.image.registry" .) }}
    {{- include "dp-oauth2proxy-recipes.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "dp-oauth2proxy.image.registry" .) }}
    {{- include "dp-oauth2proxy-recipes.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "dp-oauth2proxy-recipes.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "dp-oauth2proxy-recipes.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "true"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "dp-oauth2proxy-recipes.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "dp-oauth2proxy-recipes.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}
