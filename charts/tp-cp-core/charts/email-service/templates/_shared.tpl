{{/* 
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-email-service.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tp-cp-email-service.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-email-service.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-email-service.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-email-service.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "cp-core-configuration.cp-instance-id" . }}
{{- end -}}

{{- define "tp-cp-email-service.shared.labels.standard" -}}
{{ include  "tp-cp-email-service.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-email-service.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-email-service.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

