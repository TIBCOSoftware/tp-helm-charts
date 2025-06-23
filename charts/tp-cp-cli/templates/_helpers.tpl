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
{{- define "tpcli-utilities.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "tpcli-utilities.fullname" }}tp-cp-cli{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tpcli-utilities.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tpcli-utilities.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tpcli-utilities.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
{{- end }}

{{/*
Common labels
*/}}
{{- define "tpcli-utilities.labels" -}}
helm.sh/chart: {{ include "tpcli-utilities.chart" . }}
{{ include "tpcli-utilities.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{- define "tpcli-utilities.image.registry" }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "csgprduswrepoedge.jfrog.io" "required" "false" "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tpcli-utilities.infra.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tpcli-utilities.tpcli.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tpcli-utilities.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tpcli-utilities.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "tpcli-utilities.container-registry.custom-cert-secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_CERTIFICATE_SECRET" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}