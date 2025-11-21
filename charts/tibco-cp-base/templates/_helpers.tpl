{{/* 

Copyright © 2023 - 2025. Cloud Software Group, Inc.
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
{{- define "tibco-cp-base.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tibco-cp-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tibco-cp-base.component" -}}tibco-cp-base{{- end }}

{{- define "tibco-cp-base.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tibco-cp-base.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "tibco-cp-base.appName" -}}
{{- "cp-base" }}
{{- end }}

{{- define "tibco-cp-base.cp-instance-id" -}}
{{- .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "tibco-cp-base.globalResourceName" }}{{ include "tibco-cp-base.appName" . }}-{{ include "tibco-cp-base.cp-instance-id" . }}{{ end -}}

{{- define "tibco-cp-base.serviceAccount" -}}
{{- if empty .Values.global.tibco.serviceAccount -}}
{{- "control-plane-sa" }}
{{- else -}}
{{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}

{{- define "tibco-cp-base.pvc" -}}
{{- default "control-plane-pvc" .Values.global.external.storage.pvcName }}
{{- end }}

{{- define "tibco-cp-base.env" -}}
{{- "cp-env" }}
{{- end }}

{{- define "tibco-cp-base.otel.config" -}}
{{- "cp-otel-service" }}
{{- end }}

{{- define "tibco-cp-base.otel.secret" -}}
{{- "cp-otel-service" }}
{{- end }}

{{- define "tibco-cp-base.otel.services" -}}
{{- "otel-services" }}
{{- end }}

{{- define "tibco-cp-base.container-registry.secret" -}}tibco-container-registry-credentials{{- end }}

{{- define "tibco-cp-base.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* Node Cidr for the cluster */}}
{{- define "tibco-cp-base.nodeCIDR" }}
{{- .Values.global.external.clusterInfo.nodeCIDR -}}
{{- end }}

{{/* Pod Cidr for the cluster */}}
{{- define "tibco-cp-base.podCIDR" }}
{{- if .Values.global.tibco.createNetworkPolicy }}
{{- if empty .Values.global.external.clusterInfo.podCIDR }}
{{- .Values.global.external.clusterInfo.nodeCIDR }}
{{- else }}
{{- .Values.global.external.clusterInfo.podCIDR }}
{{- end }}
{{- end }}
{{- end }}

{{/* Service Cidr for the cluster */}}
{{- define "tibco-cp-base.serviceCIDR" }}
{{- .Values.global.external.clusterInfo.serviceCIDR }}
{{- end }}


{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "tibco-cp-base.labels" -}}
helm.sh/chart: {{ include "tibco-cp-base.chart" . }}
{{ include "tibco-cp-base.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tibco-cp-base.team" .}}
{{- end }}
platform.tibco.com/controlplane-instance-id: {{ include "tibco-cp-base.cp-instance-id" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tibco-cp-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tibco-cp-base.name" . }}
app.kubernetes.io/component: {{ include "tibco-cp-base.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tibco-cp-base.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
