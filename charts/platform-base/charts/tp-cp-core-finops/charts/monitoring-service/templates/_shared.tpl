{{/* 
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "monitoring-service.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "monitoring-service.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "monitoring-service.consts.appName" . }}
app.kubernetes.io/component: {{ include "monitoring-service.consts.component" . }}
app.kubernetes.io/part-of: {{ include "monitoring-service.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "cp-core-configuration.cp-instance-id" . }}
{{- end -}}

{{- define "monitoring-service.shared.labels.standard" -}}
{{ include  "monitoring-service.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "monitoring-service.consts.team" . }}
helm.sh/chart: {{ include "monitoring-service.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}
