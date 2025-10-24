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
{{- define "tp-cp-tibcohub-contrib.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-tibcohub-contrib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-tibcohub-contrib.component" -}}tp-cp-tibcohub-contrib{{- end }}

{{- define "tp-cp-tibcohub-contrib.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tp-cp-tibcohub-contrib.team" -}}
{{- "cic-compute" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-tibcohub-contrib.appName" }}capability-contribution--tibcohub{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}} 
{{- define "tp-cp-tibcohub-contrib.labels" -}}
helm.sh/chart: {{ include "tp-cp-tibcohub-contrib.chart" . }}
{{ include "tp-cp-tibcohub-contrib.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-tibcohub-contrib.team" .}}
platform.tibco.com/component: {{ include "tp-cp-tibcohub-contrib.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-tibcohub-contrib.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-tibcohub-contrib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-tibcohub-contrib.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-tibcohub-contrib.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-tibcohub-contrib.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tp-cp-tibcohub-contrib.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "csgprduswrepoedge.jfrog.io" "required" "false" "Release" .Release )}}
  {{- end }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-tibcohub-contrib.image.repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-tibcohub-contrib.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-cp-tibcohub-contrib.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "tp-cp-tibcohub-contrib.container-registry.custom-cert-secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_CERTIFICATE_SECRET" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-tibcohub-contrib.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-cp-tibcohub-contrib.enableResourceConstraints" -}}
{{- include "cp-env.get" (dict "key" "CP_ENABLE_RESOURCE_CONSTRAINTS" "default" "false" "required" "false"  "Release" .Release )}}
{{- end }}

{{/*
Network Policy labels
*/}}
{{- define "tp-cp-tibcohub-contrib.networkPolicyLabels" -}}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
networking.platform.tibco.com/proxy-egress: enable
{{- end }}