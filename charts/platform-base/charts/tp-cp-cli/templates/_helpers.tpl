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
{{- define "tpcli-utilities.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "tpcli-utilities.fullname" }}tp-cp-cli{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tpcli-utilities.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tpcli-utilities.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tpcli-utilities.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
networking.platform.tibco.com/internet-egress: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/containerRegistry-egress: enable
{{- end }}

{{/*
Common labels
*/}}
{{- define "tpcli-utilities.labels" -}}
helm.sh/chart: {{ include "tpcli-utilities.chart" . }}
{{ include "tpcli-utilities.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{- define "tpcli-utilities.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tpcli-utilities.infra.image.repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tpcli-utilities.tpcli.image.repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tpcli-utilities.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tpcli-utilities.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{/* Image pull custom certificate secret configured for control plane. default value empty */}}
{{- define "tpcli-utilities.container-registry.custom-cert-secret" }}
  {{- .Values.global.tibco.containerRegistry.certificateSecret }}
{{- end }}