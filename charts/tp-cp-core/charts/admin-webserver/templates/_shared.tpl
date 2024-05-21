{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-admin-webserver.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tp-cp-admin-webserver.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-admin-webserver.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-cp-admin-webserver.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-cp-admin-webserver.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "cp-core-configuration.cp-instance-id" . }}
{{- end -}}

{{- define "tp-cp-admin-webserver.shared.labels.standard" -}}
{{ include  "tp-cp-admin-webserver.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-admin-webserver.consts.team" . }}
helm.sh/chart: {{ include "tp-cp-admin-webserver.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}
