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
{{- define "tp-provisioner-agent.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-provisioner-agent.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-provisioner-agent.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-provisioner-agent.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-provisioner-agent.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-provisioner-agent.shared.labels.standard" -}}
{{ include  "tp-provisioner-agent.shared.labels.selector" . }}
{{ include "tp-provisioner-agent.shared.labels.platform" . }}
app.cloud.tibco.com/created-by: {{ include "tp-provisioner-agent.consts.team" . }}
app.cloud.tibco.com/tenant-name: {{ include "tp-provisioner-agent.consts.tenantName" . }}
helm.sh/chart: {{ include "tp-provisioner-agent.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/* Platform labels to be added in all the resources created by this chart.*/}}
{{- define "tp-provisioner-agent.shared.labels.platform" -}}
platform.tibco.com/dataplane-id: {{ .Values.global.tibco.dataPlaneId }}
platform.tibco.com/workload-type: {{ include "tp-provisioner-agent.consts.workloadType" .}}
{{- end }}
