{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "fileserver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fileserver.fullname" }}tp-cp-tenant-integration-fileserver{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fileserver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fileserver.labels" -}}
helm.sh/chart: {{ include "fileserver.chart" . }}
{{ include "fileserver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "integration-fileserver-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/*
Selector labels
*/}}
{{- define "fileserver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fileserver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{- define "fileserver.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "fileserver.integration.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "fileserver.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "fileserver.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "fileserver.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- if empty .Values.global.tibco.serviceAccount -}}
    {{- "control-plane-sa" }}
  {{- else -}}
    {{- .Values.global.tibco.serviceAccount | quote }}
  {{- end }}
{{- end }}
{{- end }}
