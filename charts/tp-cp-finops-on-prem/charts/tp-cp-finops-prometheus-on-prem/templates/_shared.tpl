{{/* 
   Copyright (c) 2024. Cloud Software Group, Inc. All Rights Reserved.

   File       : _shared.tpl
   Version    : 1.0.0
   Description: Template helpers that can be shared with other charts. 
   
    NOTES: 
      - Helpers below are making some assumptions regarding files Chart.yaml and values.yaml. Change carefully!
      - Any change in this file needs to be synchronized with all charts
*/}}
{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-cp-finops-prometheus.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-finops-prometheus.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-finops-prometheus.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-finops-prometheus.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-finops-prometheus.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "cp-core-configuration.cp-instance-id" . }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-finops-prometheus.shared.labels.standard" -}}
{{ include  "tp-cp-finops-prometheus.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-finops-prometheus.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-finops-prometheus.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}