{{/* 

Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml 
    ===========================================================================
*/}}



{{/* Create chart name and version as used by the chart label. */}}
{{- define "alerts-service.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "alerts-service.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "alerts-service.consts.appName" . }}
app.kubernetes.io/component: {{ include "alerts-service.consts.component" . }}
app.kubernetes.io/part-of: {{ include "alerts-service.consts.team" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart. 
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "alerts-service.shared.labels.standard" -}}
{{ include  "alerts-service.shared.labels.selector" . }}
app.cloud.tibco.com/created-by: {{ include "alerts-service.consts.team" . }}
app.cloud.tibco.com/tenant-name: {{ include "alerts-service.consts.tenantName" . }}
platform.tibco.com/controlplane-instance-id: {{ .Values.global.tibco.controlPlaneInstanceId }}
helm.sh/chart: {{ include "alerts-service.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-alerts-service.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}


{{- define "alerts-service.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
  {{- "control-plane-sa" }}
{{- else -}}
  {{- .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{- define "alerts-service.enableLogging" }}
  {{- .Values.global.tibco.logging.fluentbit.enabled  }}
{{- end }}

{{- define "alerts-service.image.registry" }}
  {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "alerts-service.image.repository" -}}
  {{- default "tibco-platform-docker-prod" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

