{{/* 
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "finops-web-server.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "finops-web-server.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "finops-web-server.consts.appName" . }}
app.kubernetes.io/component: {{ include "finops-web-server.consts.component" . }}
app.kubernetes.io/part-of: {{ include "finops-web-server.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "cp-core-configuration.cp-instance-id" . }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "finops-web-server.shared.labels.standard" -}}
{{ include  "finops-web-server.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "finops-web-server.consts.team" . }}
helm.sh/chart: {{ include "finops-web-server.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}