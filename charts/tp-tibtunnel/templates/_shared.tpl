{{/* 

Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml 
    ===========================================================================
*/}}

{{/* Global variable: .Values.global.where. */}}
{{- define "tp-tibtunnel.shared.global.where.local" }}local{{ end -}}
{{- define "tp-tibtunnel.shared.global.where.aws" }}aws{{ end -}}
{{- define "tp-tibtunnel.shared.global.where.azure" }}azure{{ end -}}
{{- define "tp-tibtunnel.shared.global.where.hybrid" }}hybrid{{ end -}}

{{/* Global variable: .Values.global.who. */}}
{{- define "tp-tibtunnel.shared.global.who.local" }}local{{ end -}}

{{/* Global variable: .Values.global.scale. */}}
{{- define "tp-tibtunnel.shared.global.scale.minimal" }}minimal{{ end -}}
{{- define "tp-tibtunnel.shared.global.scale.production" }}production{{ end -}}

{{/* Global variable: .Values.global.security. */}}
{{- define "tp-tibtunnel.shared.global.security.defaulted" }}defaulted{{ end -}}
{{- define "tp-tibtunnel.shared.global.security.restricted" }}restricted{{ end -}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-tibtunnel.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-tibtunnel.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-tibtunnel.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-tibtunnel.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-tibtunnel.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-tibtunnel.shared.labels.standard" -}}
{{ include  "tp-tibtunnel.shared.labels.selector" . }}
{{ include "tp-tibtunnel.shared.labels.platform" . }}
app.cloud.tibco.com/created-by: {{ include "tp-tibtunnel.consts.team" . }}
app.cloud.tibco.com/tenant-name: {{ include "tp-tibtunnel.consts.tenantName" . }}
helm.sh/chart: {{ include "tp-tibtunnel.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/* Platform labels to be added in all the resources created by this chart.*/}}
{{- define "tp-tibtunnel.shared.labels.platform" -}}
platform.tibco.com/dataplane-id: {{ .Values.global.tibco.dataPlaneId }}
platform.tibco.com/workload-type: {{ include "tp-tibtunnel.consts.workloadType" .}}
{{- end }}