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
{{- define "tp-cp-bootstrap.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-bootstrap.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-bootstrap.component" -}}tp-cp-bootstrap{{- end }}

{{- define "tp-cp-bootstrap.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tp-cp-bootstrap.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "tp-cp-bootstrap.appName" -}}
{{- "cp-bootstrap" }}
{{- end }}

{{- define "tp-cp-bootstrap.cp-instance-id" -}}
{{- .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "tp-cp-bootstrap.globalResourceName" }}{{ include "tp-cp-bootstrap.appName" . }}-{{ include "tp-cp-bootstrap.cp-instance-id" . }}{{ end -}}

{{- define "tp-cp-bootstrap.serviceAccount" -}}
{{- if empty .Values.global.tibco.serviceAccount -}}
{{- "control-plane-sa" }}
{{- else -}}
{{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}

{{- define "tp-cp-bootstrap.pvc" -}}
{{- if empty .Values.global.external.pvc -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.pvc | quote }}
{{- end }}
{{- end }}

{{- define "tp-cp-bootstrap.env" -}}
{{- "cp-env" }}
{{- end }}

{{- define "tp-cp-bootstrap.otel.config" -}}
{{- "cp-otel-service" }}
{{- end }}

{{- define "tp-cp-bootstrap.otel.secret" -}}
{{- "cp-otel-service" }}
{{- end }}

{{- define "tp-cp-bootstrap.otel.services" -}}
{{- "otel-services" }}
{{- end }}

{{- define "tp-cp-bootstrap.container-registry.secret" -}}tibco-container-registry-credentials{{- end }}

{{- define "tp-cp-bootstrap.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* Node Cidr for the cluster */}}
{{- define "tp-cp-bootstrap.nodeCIDR" }}
{{- .Values.global.external.clusterInfo.nodeCIDR -}}
{{- end }}

{{/* Pod Cidr for the cluster */}}
{{- define "tp-cp-bootstrap.podCIDR" }}
{{- if .Values.global.tibco.createNetworkPolicy }}
{{- if empty .Values.global.external.clusterInfo.podCIDR }}
{{- .Values.global.external.clusterInfo.nodeCIDR }}
{{- else }}
{{- .Values.global.external.clusterInfo.podCIDR }}
{{- end }}
{{- end }}
{{- end }}

{{/* Service Cidr for the cluster */}}
{{- define "tp-cp-bootstrap.serviceCIDR" }}
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
{{- define "tp-cp-bootstrap.labels" -}}
helm.sh/chart: {{ include "tp-cp-bootstrap.chart" . }}
{{ include "tp-cp-bootstrap.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-bootstrap.team" .}}
{{- end }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-bootstrap.cp-instance-id" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-bootstrap.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-bootstrap.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-bootstrap.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-bootstrap.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
