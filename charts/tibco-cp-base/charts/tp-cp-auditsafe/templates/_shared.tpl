{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml
    ===========================================================================
*/}}

{{/* Global variable: .Values.global.cic.data.SYSTEM_WHERE. */}}
{{- define "tp-cp-auditsafe-web-server.shared.global.where.local" }}local{{ end -}}
{{- define "tp-cp-auditsafe-web-server.shared.global.where.aws" }}aws{{ end -}}
{{- define "tp-cp-auditsafe-web-server.shared.global.where.azure" }}azure{{ end -}}
{{- define "tp-cp-auditsafe-web-server.shared.global.where.hybrid" }}hybrid{{ end -}}

{{/* Global variable: .Values.global.cic.data.SYSTEM_SCALE. */}}
{{- define "tp-cp-auditsafe-web-server.shared.global.scale.minimal" }}minimal{{ end -}}
{{- define "tp-cp-auditsafe-web-server.shared.global.scale.production" }}production{{ end -}}

{{/* Global variable: .Values.global.security. */}}
{{- define "tp-cp-auditsafe-web-server.shared.global.security.defaulted" }}defaulted{{ end -}}
{{- define "tp-cp-auditsafe-web-server.shared.global.security.restricted" }}restricted{{ end -}}

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
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-auditsafe-web-server.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-auditsafe-web-server.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-auditsafe-web-server.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-auditsafe-web-server.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ .Values.global.cic.data.SYSTEM_WHO }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-auditsafe-web-server.shared.labels.standard" -}}
{{ include  "tp-cp-auditsafe-web-server.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-auditsafe-web-server.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-auditsafe-web-server.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/*
    ===========================================================================
    SECTION: general purpose functions
    ===========================================================================
*/}}

{{/* Global resource prefix. */}}
{{- define "tp-cp-auditsafe-web-server.shared.func.globalResourcePrefix" -}}
{{ .Values.global.cic.data.SYSTEM_WHO }}-{{ include "tp-cp-auditsafe-web-server.consts.appName" . }}-
{{- end -}}

{{/* Number of replicas computed depending on current value of .Values.global.cic.data.SYSTEM_SCALE */}}
{{- define "tp-cp-auditsafe-web-server.shared.func.replicaCount" -}}
  {{- if eq .Values.global.cic.data.SYSTEM_SCALE (include "tp-cp-auditsafe-web-server.shared.global.scale.production" .) -}}
    {{- 3 -}}
  {{- else -}}
    {{- 1 -}}
  {{- end -}}
{{- end -}}

{{- define "tp-cp-auditsafe.shared.global.scale.production" }}production{{ end -}}

{{- define "tp-cp-auditsafe.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tp-cp-auditsafe.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-auditsafe.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-auditsafe.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-auditsafe.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "tp-cp-auditsafe-configuration.cp-instance-id" . }}
{{- end -}}

{{- define "tp-cp-auditsafe.shared.labels.standard" -}}
{{ include  "tp-cp-auditsafe.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-auditsafe.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-auditsafe.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "tp-cp-auditsafe.shared.func.replicaCount" -}}
    {{- 1 -}}
{{- end -}}

