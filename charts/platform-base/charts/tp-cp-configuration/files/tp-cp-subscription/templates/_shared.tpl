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
{{- define "tp-cp-subscription.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-subscription.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-subscription.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-subscription.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-subscription.consts.team" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
platform.tibco.com/subscriptionId: {{ .Values.subscriptionId | quote }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-subscription.shared.labels.standard" -}}
{{ include  "tp-cp-subscription.shared.labels.selector" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-subscription.consts.team" . }}
app.cloud.tibco.com/tenant-name: {{ include "tp-cp-subscription.consts.tenantName" . }}
helm.sh/chart: {{ include "tp-cp-subscription.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
platform.tibco.com/controlplane-instance-id: {{ .Values.global.tibco.controlPlaneInstanceId | quote }}
{{- end -}}

