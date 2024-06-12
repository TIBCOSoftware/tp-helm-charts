{{/*
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "fileserver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fileserver.fullname" }}tp-cp-tenant-integration-fileserver{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fileserver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fileserver.labels" -}}
helm.sh/chart: {{ include "fileserver.chart" . }}
{{ include "fileserver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "fileserver.cic-env-configmap" }}cic-env{{ end -}}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-control-plane-on-prem-dnsdomains{{ end -}}

{{/*
Selector labels
*/}}
{{- define "fileserver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fileserver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}



{{- define "fileserver.consts.integration.jfrogImageRepo" }}tibco-platform-local-docker/integration{{end}}
{{- define "fileserver.consts.integration.ecrImageRepo" }}piap{{end}}
{{- define "fileserver.consts.integration.acrImageRepo" }}piap{{end}}
{{- define "fileserver.consts.integration.harborImageRepo" }}piap{{end}}
{{- define "fileserver.consts.integration.defaultImageRepo" }}tibco-platform-local-docker/integration{{end}}


{{- define "fileserver.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "reldocker.tibco.com" "required" "false" "Release" .Release )}}
  {{- end }}
{{- end }}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "fileserver.integration.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "fileserver.image.registry" .) }} 
    {{- include "fileserver.consts.integration.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "fileserver.image.registry" .) }}
    {{- include "fileserver.consts.integration.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "fileserver.image.registry" .) }}
    {{- include "fileserver.consts.integration.harborImageRepo" .}}
  {{- else }}
    {{- include "fileserver.consts.integration.defaultImageRepo" .}}
  {{- end }}
{{- end -}}



{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "fileserver.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "true"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "fileserver.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "fileserver.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane provider */}}
{{- define "fileserver.cp-provider" -}}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "fileserver.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}





