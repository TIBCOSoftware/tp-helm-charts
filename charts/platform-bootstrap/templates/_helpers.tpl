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
{{- define "platform-bootstrap.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "platform-bootstrap.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "platform-bootstrap.component" -}}platform-bootstrap{{- end }}

{{- define "platform-bootstrap.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "platform-bootstrap.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "platform-bootstrap.appName" -}}
{{- "cp-bootstrap" }}
{{- end }}

{{- define "platform-bootstrap.cp-instance-id" -}}
{{- .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "platform-bootstrap.globalResourceName" }}{{ include "platform-bootstrap.appName" . }}-{{ include "platform-bootstrap.cp-instance-id" . }}{{ end -}}

{{- define "platform-bootstrap.serviceAccount" -}}
{{- if empty .Values.global.tibco.serviceAccount -}}
{{- "control-plane-sa" }}
{{- else -}}
{{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}

{{- define "platform-bootstrap.pvc" -}}
{{- default "control-plane-pvc" .Values.global.external.storage.pvcName }}
{{- end }}

{{- define "platform-bootstrap.env" -}}
{{- "cp-env" }}
{{- end }}

{{- define "platform-bootstrap.otel.config" -}}
{{- "cp-otel-service" }}
{{- end }}

{{- define "platform-bootstrap.otel.secret" -}}
{{- "cp-otel-service" }}
{{- end }}

{{- define "platform-bootstrap.otel.services" -}}
{{- "otel-services" }}
{{- end }}

{{- define "platform-bootstrap.container-registry.secret" -}}tibco-container-registry-credentials{{- end }}

{{- define "platform-bootstrap.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* Node Cidr for the cluster */}}
{{- define "platform-bootstrap.nodeCIDR" }}
{{- .Values.global.external.clusterInfo.nodeCIDR -}}
{{- end }}

{{/* Pod Cidr for the cluster */}}
{{- define "platform-bootstrap.podCIDR" }}
{{- if .Values.global.tibco.createNetworkPolicy }}
{{- if empty .Values.global.external.clusterInfo.podCIDR }}
{{- .Values.global.external.clusterInfo.nodeCIDR }}
{{- else }}
{{- .Values.global.external.clusterInfo.podCIDR }}
{{- end }}
{{- end }}
{{- end }}

{{/* Service Cidr for the cluster */}}
{{- define "platform-bootstrap.serviceCIDR" }}
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
{{- define "platform-bootstrap.labels" -}}
helm.sh/chart: {{ include "platform-bootstrap.chart" . }}
{{ include "platform-bootstrap.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "platform-bootstrap.team" .}}
{{- end }}
platform.tibco.com/controlplane-instance-id: {{ include "platform-bootstrap.cp-instance-id" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "platform-bootstrap.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-bootstrap.name" . }}
app.kubernetes.io/component: {{ include "platform-bootstrap.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "platform-bootstrap.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
