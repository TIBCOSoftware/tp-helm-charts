{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{- define "tp-control-plane.shared.global.scale.production" }}production{{ end -}}

{{- define "tp-control-plane.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tp-control-plane.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-control-plane.consts.appName" . }}
app.kubernetes.io/component: {{ include "tp-control-plane.consts.component" . }}
app.kubernetes.io/part-of: {{ include "tp-control-plane.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ .Values.global.tibco.controlPlaneInstanceId }}
{{- end -}}

{{- define "tp-control-plane.shared.labels.standard" -}}
{{ include  "tp-control-plane.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-control-plane.consts.team" . }}
helm.sh/chart: {{ include "tp-control-plane.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "tp-control-plane.shared.func.replicaCount" -}}
    {{- 1 -}}
{{- end -}}

