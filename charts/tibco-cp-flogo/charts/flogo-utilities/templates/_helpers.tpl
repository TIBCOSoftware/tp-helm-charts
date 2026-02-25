{{/*
Copyright © 2026. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "flogo-utilities.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flogo-utilities.fullname" }}flogo-utilities{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flogo-utilities.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flogo-utilities.labels" -}}
helm.sh/chart: {{ include "flogo-utilities.chart" . }}
{{ include "flogo-utilities.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flogo-utilities.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flogo-utilities.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Network Policy labels
*/}}
{{- define "flogo-utilities.networkPolicyLabels" -}}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
networking.platform.tibco.com/proxy-egress: enable
{{- end }}

{{- define "flogo-utilities.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogo-utilities.infra.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogo-utilities.flogo.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogo-utilities.integration.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogo-utilities.plugins.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "flogo-utilities.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "flogo-utilities.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "flogo-utilities.container-registry.custom-cert-secret" }}
{{- default "" .Values.global.tibco.containerRegistry.certificateSecret }}
{{- end }}

{{- define "flogo-utilities.cp-http-proxy" }}
{{- default "" .Values.global.tibco.proxy.httpProxy }}
{{- end }}

{{- define "flogo-utilities.cp-https-proxy" }}
{{- default "" .Values.global.tibco.proxy.httpsProxy }}
{{- end }}

{{- define "flogo-utilities.cp-no-proxy" }}
{{- default "" .Values.global.tibco.proxy.noProxy }}
{{- end }}
