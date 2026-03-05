{{/* 

Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
================================================================
                  SECTION COMMON VARS
================================================================   
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "tp-dp-proxy.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-dp-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-dp-proxy.component" -}}tp-dp-proxy{{- end }}

{{- define "tp-dp-proxy.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tp-dp-proxy.team" -}}
{{- "cic-compute" }}
{{- end }}


{{- define "tp-dp-proxy.consts.appName" }}tp-dp-proxy{{ end -}}

{{- define "tp-dp-proxy.consts.svcName" }}dp-proxy{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/* Control plane instance Id. default value cp1 */}}
{{- define "tp-dp-proxy.cp-instance-id" }}
{{- default "cp1" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{- define "tp-dp-proxy.image.registry" }}
  {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-dp-proxy.image.repository" -}}
  {{- default "tibco-platform-docker-prod" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{- define "tp-dp-proxy.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* Control plane OTEl service */}}
{{- define "tp-dp-proxy.otelServiceName" -}}
{{- "otel-services" }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-dp-proxy.enableResourceConstraints" -}}
{{- hasKey .Values.global.tibco "enableResourceConstraints" | ternary .Values.global.tibco.enableResourceConstraints true }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tp-dp-proxy.labels" -}}
helm.sh/chart: {{ include "tp-dp-proxy.chart" . }}
{{ include "tp-dp-proxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-dp-proxy.team" . }}
platform.tibco.com/component: {{ include "tp-dp-proxy.component" . }}
{{- end }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-dp-proxy.cp-instance-id" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-dp-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-dp-proxy.name" . }}
app.kubernetes.io/component: {{ include "tp-dp-proxy.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-dp-proxy.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Control plane logging fluentbit. default value true */}}
{{- define "tp-dp-proxy.cp-logging-fluentbit-enabled" }}
  {{- .Values.global.tibco.logging.fluentbit.enabled  }}
{{- end }}
