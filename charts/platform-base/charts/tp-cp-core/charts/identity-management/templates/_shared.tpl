{{/* 
   Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-identity-management.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels used by the resources in this chart */}}
{{- define "tp-identity-management.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-identity-management.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-identity-management.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-identity-management.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ .Values.global.tibco.controlPlaneInstanceId }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-identity-management.shared.labels.standard" -}}
{{ include  "tp-identity-management.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-identity-management.consts.team" . }}
helm.sh/chart: {{ include "tp-identity-management.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "cp-core-configuration.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
   {{- "control-plane-sa" }}
{{- else -}}
   {{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}


