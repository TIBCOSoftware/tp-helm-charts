{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "router-operator.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "router-operator.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "router-operator.consts.appName" . }}
app.kubernetes.io/component: {{ include "router-operator.consts.component" . }}
app.kubernetes.io/part-of: {{ include "router-operator.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "router-operator.shared.labels.standard" -}}
{{ include  "router-operator.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "router-operator.consts.team" . }}
app.cloud.tibco.com/tenant-name: {{ include "router-operator.consts.tenantName" . }}
platform.tibco.com/controlplane-instance-id: {{ .Values.global.tibco.controlPlaneInstanceId }}
helm.sh/chart: {{ include "router-operator.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}