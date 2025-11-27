{{/* 

Copyright © 2023 - 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml 
    ===========================================================================
*/}}



{{/* Create chart name and version as used by the chart label. */}}
{{- define "tp-cp-infra.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "tp-cp-infra.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "tp-cp-infra.consts.appName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "tp-cp-infra.shared.labels.standard" -}}
{{ include  "tp-cp-infra.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-infra.consts.team" . }}
platform.tibco.com/controlplane-instance-id: {{ .Values.global.tibco.controlPlaneInstanceId }}
helm.sh/chart: {{ include "tp-cp-infra.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "tp-cp-infra.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
  {{- "control-plane-sa" }}
{{- else -}}
  {{- .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{- define "tp-cp-infra.otel.services" -}}
{{- "otel-services" }}
{{- end }}