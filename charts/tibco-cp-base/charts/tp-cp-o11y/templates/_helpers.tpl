{{/* 

Copyright © 2023 - 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-o11y.consts.appName" }}o11y-service{{ end -}}

{{- define "tp-cp-o11y-mcp-server.consts.appName" }}tp-o11y-mcp-server{{ end -}}

{{- define "tp-cp-o11y.fullname" }}o11y-service{{ end -}}

{{- define "tp-cp-o11y-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-cp-o11y.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-o11y.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-o11y.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tp-cp-o11y.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.o11yservice.serviceAccount . }}
{{- end }}
{{- end }}

{{/**/}}
{{/*Common labels*/}}
{{/**/}}
{{/*{{- define "tp-cp-o11y.labels" -}}*/}}
{{/*helm.sh/chart: {{ include "tp-cp-o11y.chart" . }}*/}}
{{/*{{ include "tp-cp-o11y.shared.labels.selector" . }}*/}}
{{/*{{- if .Chart.AppVersion }}*/}}
{{/*app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}*/}}
{{/*{{- end }}*/}}
{{/*app.kubernetes.io/managed-by: {{ .Release.Service }}*/}}
{{/*{{- end }}*/}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-o11y.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-o11y.consts.appName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "o11y"
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-o11y.shared.labels.standard" -}}
{{ include  "tp-cp-o11y.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-o11y.consts.appName" . }}
helm.sh/chart: {{ include "tp-cp-o11y.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "tp-cp-o11y.image.registry" }}
   {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-o11y.image.repository" -}}
  {{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "tp-cp-o11y.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- if empty .Values.global.tibco.serviceAccount -}}
    {{- "control-plane-sa" }}
  {{- else -}}
    {{- .Values.global.tibco.serviceAccount | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-cp-o11y.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-o11y.cp-instance-id" }}
  {{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Control plane OTEL service. default value otel-services */}}
{{- define "tp-cp-o11y.otel.services" -}}
   {{- "otel-services."}}{{ .Release.Namespace }}{{".svc.cluster.local" }}
{{- end }}

{{- define "tp-cp-o11y.cp-dp-url" -}}
  {{- if (include "tp-cp-o11y.isSingleNamespace" .) }}
    {{- "dp-%s."}}{{ .Release.Namespace }}{{".svc.cluster.local" -}}
  {{- else }}
    {{- "dp-%s."}}{{include "tp-cp-o11y.cp-instance-id" .}}{{"-tibco-sub-%s.svc.cluster.local" -}}
  {{- end -}}
{{ end -}}

{{- define "tp-cp-o11y.isSingleNamespace" }}
  {{- $isSubscriptionSingleNamespace := "" -}}
    {{- if .Values.global.tibco.useSingleNamespace -}}
        {{- $isSubscriptionSingleNamespace = "1" -}}
    {{- end -}}
  {{ $isSubscriptionSingleNamespace }}
{{- end }}

{{- define "tp-cp-o11y.CPCustomerEnv" }}
  {{- $isCPCustomerEnv := "false" -}}
    {{- if .Values.global.tibco.useSingleNamespace  -}}
        {{- $isCPCustomerEnv = "true" -}}
    {{- end -}}
  {{ $isCPCustomerEnv }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-o11y.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-cp-o11y.enableResourceConstraints" -}}
{{- default "false" .Values.global.tibco.enableResourceConstraints | quote }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "tp-cp-o11y.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-o11y.component" -}}o11y-service{{- end }}

{{- define "tp-cp-o11y.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tp-cp-o11y.team" -}}
{{- "cic-compute" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-o11y.appName" }}o11y-service{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================
*/}}

{{/*
Common labels
*/}}
{{- define "tp-cp-o11y.labels" -}}
helm.sh/chart: {{ include "tp-cp-o11y.chart" . }}
{{ include "tp-cp-o11y.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-o11y.team" .}}
platform.tibco.com/component: {{ include "tp-cp-o11y.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-o11y.cp-instance-id" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-o11y.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-o11y.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-o11y.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-o11y.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
