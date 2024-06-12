{{/* 
   Copyright (c) 2023 - 2024 Cloud Software Group Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.

   File       : _helpers.tpl
   Version    : 1.0.0
   Description: Template helpers that can be shared with other charts. 
   
    NOTES: 
      - Helpers below are making some assumptions regarding files Chart.yaml and values.yaml. Change carefully!
      - Any change in this file needs to be synchronized with all charts
*/}}

{{/*
Create image tag value which defaults to .Chart.AppVersion.
*/}}
{{- define "o11y-service.image.tag" -}}
{{- .Values.tag | default .Chart.AppVersion | trimPrefix "0.0." }}
{{- end -}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "o11y-service.consts.appName" }}o11y-service{{ end -}}

{{- define "o11y-service.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{- define "o11y-service.fullname" }}o11y-service{{ end -}}

{{- define "o11y-service.otel-receiver-service" }}otel-recvservice-name{{ end -}}
{{- define "o11y-service.otel-receiver-port" }}otel-recvservice-port{{ end -}}
{{- define "o11y-service.logserver-logIndex" }}logserver-logIndex{{ end -}}
{{- define "o11y-service.logserver-traceIndex" }}logserver-traceIndex{{ end -}}
{{- define "o11y-service.logserver-proxy-endpoint" }}logserver-proxy-endpoint{{ end -}}
{{- define "o11y-service.logserver-proxy-userName" }}logserver-proxy-userName{{ end -}}
{{- define "o11y-service.logserver-exporter-endpoint" }}logserver-exporter-endpoint{{ end -}}
{{- define "o11y-service.logserver-exporter-userName" }}logserver-exporter-userName{{ end -}}
{{- define "o11y-service.promserver-proxy-endpoint" }}promserver-proxy-endpoint{{ end -}}
{{- define "o11y-service.promserver-proxy-userName" }}promserver-proxy-userName{{ end -}}
{{- define "o11y-service.promserver-exporter-endpoint" }}promserver-exporter-endpoint{{ end -}}
{{- define "o11y-service.logserver-proxy-password" }}logserver-proxy-password{{ end -}}
{{- define "o11y-service.promserver-proxy-password" }}promserver-proxy-password{{ end -}}
{{- define "o11y-service.promserver-exporter-token" }}promserver-exporter-token{{ end -}}

{{- define "o11y-service.jaeger-collector-endpoint" }}jaeger-collector.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local:{{ .Values.global.cp.resources.o11y.tracesServer.config.collector.port }}{{ end -}}
{{- define "o11y-service.finops-collector-endpoint" }}{{ .Values.global.otel.finops.exporters.metricsendpoint }}{{ end -}}

{{- define "o11y-service.role" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-o11y-role{{ end -}}
{{- define "o11y-service.role-bind" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-o11y-role-bind{{ end -}}


{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "o11y-service.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "o11y-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "o11y-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "o11y-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.o11yservice.serviceAccount . }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "o11y-service.labels" -}}
helm.sh/chart: {{ include "o11y-service.chart" . }}
{{ include "o11y-service.shared.labels.selector" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "o11y-service.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "o11y-service.consts.appName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "o11y"
platform.tibco.com/workload-type: "infra"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "o11y-service.shared.labels.standard" -}}
{{ include  "o11y-service.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "o11y-service.consts.appName" . }}
helm.sh/chart: {{ include "o11y-service.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "o11y-service.const.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "o11y-service.const.ecrImageRepo" }}stratosphere{{end}}
{{- define "o11y-service.const.acrImageRepo" }}stratosphere{{end}}
{{- define "o11y-service.const.harborImageRepo" }}stratosphere{{end}}
{{- define "o11y-service.const.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "o11y-service.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "o11y-service.image.repository" -}}
  {{- if contains "jfrog.io" (include "o11y-service.image.registry" .) }}
    {{- include "o11y-service.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "o11y-service.image.registry" .) }}
    {{- include "o11y-service.const.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "o11y-service.image.registry" .) }}
    {{- include "o11y-service.const.harborImageRepo" .}}
  {{- else }}
    {{- include "o11y-service.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}