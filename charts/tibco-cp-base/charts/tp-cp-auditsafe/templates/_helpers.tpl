{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-auditsafe-web-server.consts.appName" }}tp-cp-auditsafe-web-server{{ end -}}

{{- define "tp-cp-auditsafe-web-server.fullname" }}tp-cp-auditsafe-web-server{{ end -}}

{{- define "tp-cp-auditsafe-web-server-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-cp-auditsafe-web-server.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-auditsafe-web-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-auditsafe-web-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tp-cp-auditsafe-web-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.auditsafe.serviceAccount . }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tp-cp-auditsafe-web-server.labels" -}}
helm.sh/chart: {{ include "tp-cp-auditsafe-web-server.chart" . }}
{{ include "tp-cp-auditsafe-web-server.shared.labels.selector" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-auditsafe-web-server.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-auditsafe-web-server.consts.appName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "o11y"
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-auditsafe-web-server.shared.labels.standard" -}}
{{ include  "tp-cp-auditsafe-web-server.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-auditsafe-web-server.consts.appName" . }}
helm.sh/chart: {{ include "tp-cp-auditsafe-web-server.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "tp-cp-auditsafe-web-server.image.registry" }}
   {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-auditsafe-web-server.image.repository" -}}
  {{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "tp-cp-auditsafe-web-server.service-account-name" }}
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
{{- define "tp-cp-auditsafe-web-server.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-auditsafe-web-server.cp-instance-id" }}
  {{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Control plane OTEL service. default value otel-services */}}
{{- define "tp-cp-auditsafe-web-server.cp-otel-services" -}}
   {{- "otel-services."}}{{ .Release.Namespace }}{{".svc.cluster.local" }}
{{- end }}

{{- define "tp-cp-auditsafe-web-server.cp-dp-url" -}}
  {{- if (include "tp-cp-auditsafe-web-server.isSingleNamespace" .) }}
    {{- "dp-%s."}}{{ .Release.Namespace }}{{".svc.cluster.local" -}}
  {{- else }}
    {{- "dp-%s."}}{{include "tp-cp-auditsafe-web-server.cp-instance-id" .}}{{"-tibco-sub-%s.svc.cluster.local" -}}
  {{- end -}}
{{ end -}}

{{- define "tp-cp-auditsafe-web-server.isSingleNamespace" }}
  {{- $isSubscriptionSingleNamespace := "" -}}
    {{- if .Values.global.tibco.useSingleNamespace -}}
        {{- $isSubscriptionSingleNamespace = "1" -}}
    {{- end -}}
  {{ $isSubscriptionSingleNamespace }}
{{- end }}

{{- define "tp-cp-auditsafe-web-server.CPCustomerEnv" }}
  {{- $isCPCustomerEnv := "false" -}}
    {{- if .Values.global.tibco.useSingleNamespace  -}}
        {{- $isCPCustomerEnv = "true" -}}
    {{- end -}}
  {{ $isCPCustomerEnv }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-auditsafe-web-server.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-cp-auditsafe-web-server.enableResourceConstraints" -}}
{{- default "false" .Values.global.tibco.enableResourceConstraints | quote }}
{{- end }}

{{/*{{- define "tp-cp-auditsafe.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}*/}}
{{/*{{- define "tp-cp-auditsafe.consts.ecrImageRepo" }}pcp{{end}}*/}}
{{/*{{- define "tp-cp-auditsafe.consts.acrImageRepo" }}pcp{{end}}*/}}
{{/*{{- define "tp-cp-auditsafe.consts.harborImageRepo" }}pcp{{end}}*/}}
{{/*{{- define "tp-cp-auditsafe.consts.defaultImageRepo" }}pcp{{end}}*/}}


{{- define "tp-cp-auditsafe.image.repository" -}}
 {{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}