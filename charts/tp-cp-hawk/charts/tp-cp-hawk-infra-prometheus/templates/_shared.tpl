{{/* 
   Copyright (c) 2024 Cloud Software Group, Inc.
   All Rights Reserved.

   File       : _shared.tpl
   Version    : 1.0.0
   Description: Template helpers that can be shared with other charts. 
   
    NOTES: 
      - Helpers below are making some assumptions regarding files Chart.yaml and values.yaml. Change carefully!
      - Any change in this file needs to be synchronized with all charts
*/}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml 
    ===========================================================================
*/}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-hawk-infra-prometheus.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-hawk-infra-prometheus.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-hawk-infra-prometheus.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-hawk-infra-prometheus.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-hawk-infra-prometheus.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "tp-hawk-infra-prometheus.cp-instance-id" . }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-hawk-infra-prometheus.shared.labels.standard" -}}
{{ include  "tp-hawk-infra-prometheus.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-hawk-infra-prometheus.consts.team" . }}
helm.sh/chart: {{ include "tp-hawk-infra-prometheus.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}


