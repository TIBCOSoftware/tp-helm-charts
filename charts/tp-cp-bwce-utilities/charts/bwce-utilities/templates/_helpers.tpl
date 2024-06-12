{{/*
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "bwce-utilities.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bwce-utilities.fullname" }}tp-cp-bwce-utilities{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bwce-utilities.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bwce-utilities.labels" -}}
helm.sh/chart: {{ include "bwce-utilities.chart" . }}
{{ include "bwce-utilities.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bwce-utilities.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bwce-utilities.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "bwce-utilities.consts.infra.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "bwce-utilities.consts.infra.ecrImageRepo" }}stratosphere{{end}}
{{- define "bwce-utilities.consts.infra.acrImageRepo" }}stratosphere{{end}}
{{- define "bwce-utilities.consts.infra.harborImageRepo" }}stratosphere{{end}}
{{- define "bwce-utilities.consts.infra.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}


{{- define "bwce-utilities.consts.bwce.jfrogImageRepo" }}tibco-platform-local-docker/bwce{{end}}
{{- define "bwce-utilities.consts.bwce.ecrImageRepo" }}piap{{end}}
{{- define "bwce-utilities.consts.bwce.acrImageRepo" }}piap{{end}}
{{- define "bwce-utilities.consts.bwce.harborImageRepo" }}piap{{end}}
{{- define "bwce-utilities.consts.bwce.defaultImageRepo" }}tibco-platform-local-docker/bwce{{end}}

{{- define "bwce-utilities.consts.integration.jfrogImageRepo" }}tibco-platform-local-docker/integration{{end}}
{{- define "bwce-utilities.consts.integration.ecrImageRepo" }}piap{{end}}
{{- define "bwce-utilities.consts.integration.acrImageRepo" }}piap{{end}}
{{- define "bwce-utilities.consts.integration.harborImageRepo" }}piap{{end}}
{{- define "bwce-utilities.consts.integration.defaultImageRepo" }}tibco-platform-local-docker/integration{{end}}

{{- define "bwce-utilities.consts.plugins.jfrogImageRepo" }}tibco-platform-local-docker/bwce{{end}}
{{- define "bwce-utilities.consts.plugins.ecrImageRepo" }}tci{{end}}
{{- define "bwce-utilities.consts.plugins.acrImageRepo" }}tci{{end}}
{{- define "bwce-utilities.consts.plugins.harborImageRepo" }}tci{{end}}
{{- define "bwce-utilities.consts.plugins.defaultImageRepo" }}tibco-platform-local-docker/bwce{{end}}

{{- define "bwce-utilities.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "reldocker.tibco.com" "required" "false" "Release" .Release )}}
  {{- end }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bwce-utilities.infra.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "bwce-utilities.image.registry" .) }} 
    {{- include "bwce-utilities.consts.infra.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.infra.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.infra.harborImageRepo" .}}
  {{- else }}
    {{- include "bwce-utilities.consts.infra.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bwce-utilities.bwce.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "bwce-utilities.image.registry" .) }} 
    {{- include "bwce-utilities.consts.bwce.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.bwce.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.bwce.harborImageRepo" .}}
  {{- else }}
    {{- include "bwce-utilities.consts.bwce.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bwce-utilities.integration.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "bwce-utilities.image.registry" .) }} 
    {{- include "bwce-utilities.consts.integration.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.integration.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.integration.harborImageRepo" .}}
  {{- else }}
    {{- include "bwce-utilities.consts.integration.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bwce-utilities.plugins.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "bwce-utilities.image.registry" .) }} 
    {{- include "bwce-utilities.consts.plugins.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.plugins.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bwce-utilities.image.registry" .) }}
    {{- include "bwce-utilities.consts.plugins.harborImageRepo" .}}
  {{- else }}
    {{- include "bwce-utilities.consts.plugins.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "bwce-utilities.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "true"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "bwce-utilities.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "bwce-utilities.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane provider */}}
{{- define "bwce-utilities.cp-provider" -}}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "bwce-utilities.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

