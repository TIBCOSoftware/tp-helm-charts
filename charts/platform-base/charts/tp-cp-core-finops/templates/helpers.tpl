#
# Copyright © 2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
{{/* Container registry for control plane. default value csgprdusw2reposaas.jfrog.io */}}
{{- define "tp-cp-core-finops-job.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url | default "csgprdusw2reposaas.jfrog.io" }}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* set repository based on the global value. */}}
{{- define "tp-cp-core-finops-job.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-monitor-agent.appName" }}tp-cp-monitor-agent{{ end -}}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-cp-monitor-agent.enableResourceConstraints" -}}
  {{- .Values.global.tibco.enableResourceConstraints | default "false" }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-monitor-agent.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
  {{- .Values.global.external.storage.pvcName | default "control-plane-pvc" }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-cp-monitor-agent.container-registry.secret" }}tibco-container-registry-credentials{{ end }}

{{- define "tp-cp-monitor-agent.component" -}}tp-cp-monitor-agent{{- end }}

{{- define "tp-cp-monitor-agent.labels" -}}
helm.sh/chart: {{ include "tp-cp-monitor-agent.chart" . }}
{{ include "tp-cp-monitor-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-monitor-agent.team" .}}
platform.tibco.com/component: {{ include "tp-cp-monitor-agent.component" . }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-monitor-agent.cp-instance-id" . }}
{{- end }}
{{- end }}


{{- define "tp-cp-monitor-agent.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "tp-cp-monitor-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-monitor-agent.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-monitor-agent.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-monitor-agent.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tp-cp-monitor-agent.name" -}}
tp-cp-monitor-agent
{{- end }}

{{- define "tp-cp-monitor-agent.part-of" -}}
tibco-platform
{{- end }}


{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-monitor-agent.consts.appName" }}tp-dp-monitor-agent{{ end -}}

{{- define "tp-cp-monitor-agent.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository to the global value. */}}
{{- define "tp-cp-monitor-agent.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-monitor-agent.cp-instance-id" }}
  {{- .Values.global.tibco.controlPlaneInstanceId | default "cp1" }}
{{- end }}

{{- define "tp-cp-monitor-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
