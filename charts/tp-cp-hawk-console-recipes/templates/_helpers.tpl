{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
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
{{- define "tp-cp-hawk-console-recipes.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-hawk-console-recipes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-hawk-console-recipes.component" -}}tp-cp-hawk-console-recipes{{- end }}

{{- define "tp-cp-hawk-console-recipes.part-of" -}}
{{- "tibco-platform-data-plane" }}
{{- end }}

{{- define "tp-cp-hawk-console-recipes.team" -}}
{{- "tp-hawk" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-hawk-console-recipes.appName" }}tp-cp-hawk-console-recipes{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================
*/}}

{{/*
Common labels
*/}}
{{- define "tp-cp-hawk-console-recipes.labels" -}}
helm.sh/chart: {{ include "tp-cp-hawk-console-recipes.chart" . }}
{{ include "tp-cp-hawk-console-recipes.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-hawk-console-recipes.team" .}}
platform.tibco.com/component: {{ include "tp-cp-hawk-console-recipes.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-hawk-console-recipes.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-hawk-console-recipes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-hawk-console-recipes.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-hawk-console-recipes.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-hawk-console-recipes.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{- define "tp-cp-hawk-console-recipes.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "csgprdusw2reposaas.jfrog.io" "required" "false" "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-hawk-console-recipes.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-hawk-console-recipes.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "true"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-cp-hawk-console-recipes.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-hawk-console-recipes.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control cpIsSingleNamespace flag */}}
{{- define "tp-cp-hawk-console-recipes.cp-is-single-namespace" }}
{{- if .Values.cpIsSingleNamespace }}
  {{- .Values.cpIsSingleNamespace }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SUBSCRIPTION_SINGLE_NAMESPACE" "default" "true" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane provider */}}
{{- define "tp-cp-hawk-console-recipes.cp-provider" -}}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Shared chart resource suffix */}}
{{- define "tp-cp-hawk-console-recipes.resourceSuffix" }}
{{- if not .Values.resourceSuffix }}
  {{- $_ := set .Values "resourceSuffix" (randAlphaNum 4 | lower) }}
{{- end }}
{{- .Values.resourceSuffix }}
{{- end }}
