{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "bw5ce-utilities.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bw5ce-utilities.fullname" }}tp-cp-bw5ce-utilities{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bw5ce-utilities.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bw5ce-utilities.labels" -}}
helm.sh/chart: {{ include "bw5ce-utilities.chart" . }}
{{ include "bw5ce-utilities.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bw5ce-utilities.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bw5ce-utilities.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Network Policy labels
*/}}
{{- define "bw5ce-utilities.networkPolicyLabels" -}}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
networking.platform.tibco.com/proxy-egress: enable
{{- end }}

{{- define "bw5ce-utilities.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.infra.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.bw5ce.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.integration.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw5ce-utilities.plugins.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "bw5ce-utilities.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- default "" .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "bw5ce-utilities.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "bw5ce-utilities.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "bw5ce-utilities.container-registry.custom-cert-secret" }}
{{- default "" .Values.global.tibco.containerRegistry.certificateSecret }}
{{- end }}

{{- define "bw5ce-utilities.cp-http-proxy" }}
{{- default "" .Values.global.tibco.proxy.httpProxy }}
{{- end }}

{{- define "bw5ce-utilities.cp-https-proxy" }}
{{- default "" .Values.global.tibco.proxy.httpsProxy }}
{{- end }}

{{- define "bw5ce-utilities.cp-no-proxy" }}
{{- default "" .Values.global.tibco.proxy.noProxy }}
{{- end }}
