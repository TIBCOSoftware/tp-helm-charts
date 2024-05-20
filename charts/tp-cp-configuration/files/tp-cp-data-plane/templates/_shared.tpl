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
{{- define "tp-cp-data-plane.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-data-plane.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-data-plane.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-data-plane.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-data-plane.consts.team" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/content: control-plane-dp
platform.tibco.com/subscriptionId: {{ .Values.subscriptionId }} 
platform.tibco.com/dataplaneId: {{ .Values.dataPlaneId }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-data-plane.shared.labels.standard" -}}
{{ include  "tp-cp-data-plane.shared.labels.selector" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-data-plane.consts.team" . }}
app.cloud.tibco.com/tenant-name: {{ include "tp-cp-data-plane.consts.tenantName" . }}
helm.sh/chart: {{ include "tp-cp-data-plane.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
platform.tibco.com/controlplane-instance-id: {{ .Values.controlPlaneInstanceId }}
{{- end -}}

