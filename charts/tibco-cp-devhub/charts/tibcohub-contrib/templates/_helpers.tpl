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
{{- define "tibcohub-contrib.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tibcohub-contrib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tibcohub-contrib.component" -}}tibcohub-contrib{{- end }}

{{- define "tibcohub-contrib.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tibcohub-contrib.team" -}}
{{- "cic-compute" }}
{{- end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tibcohub-contrib.appName" }}capability-contribution--tibcohub{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "tibcohub-contrib.labels" -}}
helm.sh/chart: {{ include "tibcohub-contrib.chart" . }}
{{ include "tibcohub-contrib.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tibcohub-contrib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tibcohub-contrib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Network Policy labels
*/}}
{{- define "tibcohub-contrib.networkPolicyLabels" -}}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
networking.platform.tibco.com/proxy-egress: enable
{{- end }}

{{- define "tibcohub-contrib.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tibcohub-contrib.infra.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tibcohub-contrib.tibcohub.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "tibcohub-contrib.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- default "" .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tibcohub-contrib.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tibcohub-contrib.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "tibcohub-contrib.container-registry.custom-cert-secret" }}
{{- default "" .Values.global.tibco.containerRegistry.certificateSecret }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tibcohub-contrib.enableResourceConstraints" -}}
{{- default "false" .Values.global.tibco.enableResourceConstraints | quote }}
{{- end }}

{{- define "tibcohub-contrib.cp-http-proxy" }}
{{- default "" .Values.global.tibco.proxy.httpProxy }}
{{- end }}

{{- define "tibcohub-contrib.cp-https-proxy" }}
{{- default "" .Values.global.tibco.proxy.httpsProxy }}
{{- end }}

{{- define "tibcohub-contrib.cp-no-proxy" }}
{{- default "" .Values.global.tibco.proxy.noProxy }}
{{- end }}
