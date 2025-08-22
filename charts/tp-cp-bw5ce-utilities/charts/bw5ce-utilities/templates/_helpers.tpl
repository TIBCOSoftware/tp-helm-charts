{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "bw5ce-utilities.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bw5ce-utilities.fullname" }}tp-cp-bw5ce-utilities{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bw5ce-utilities.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bw5ce-utilities.labels" -}}
helm.sh/chart: {{ include "bw5ce-utilities.chart" . }}
{{ include "bw5ce-utilities.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bw5ce-utilities.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bw5ce-utilities.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Network Policy labels
*/}}
{{- define "bw5ce-utilities.networkPolicyLabels" -}}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
networking.platform.tibco.com/proxy-egress: enable
{{- end }}

{{- define "bw5ce-utilities.image.registry" }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false" "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.infra.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.bw5ce.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.integration.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.plugins.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "bw5ce-utilities.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "true"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "bw5ce-utilities.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "bw5ce-utilities.container-registry.custom-cert-secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_CERTIFICATE_SECRET" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "bw5ce-utilities.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "bw5ce-utilities.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "bw5ce-utilities.enableResourceConstraints" -}}
{{- include "cp-env.get" (dict "key" "CP_ENABLE_RESOURCE_CONSTRAINTS" "default" "false" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "bw5ce-utilities.cp-http-proxy" }}
  {{- include "cp-env.get" (dict "key" "CP_HTTP_PROXY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "bw5ce-utilities.cp-https-proxy" }}
  {{- include "cp-env.get" (dict "key" "CP_HTTPS_PROXY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "bw5ce-utilities.cp-no-proxy" }}
  {{- include "cp-env.get" (dict "key" "CP_NO_PROXY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
