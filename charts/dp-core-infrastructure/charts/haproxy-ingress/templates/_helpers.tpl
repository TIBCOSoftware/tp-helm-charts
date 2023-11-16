{{/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
  *
  *  Name (defaults to "haproxy-ingress") and a fully qualified name
  *  (defaults to "<release>-haproxy-ingress") of controller and a variant with `.Values.defaultBackend.name`
  *  for the default backend.
  *
  *  We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
  *  If release name contains the chart name, it will be used as a full name.
  *
  */}}
{{- define "haproxy-ingress.name" -}}
  {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "haproxy-ingress.fullname" -}}
  {{- if .Values.fullnameOverride }}
    {{- tpl .Values.fullnameOverride . | trunc 63 | trimSuffix "-" }}
  {{- else }}
    {{- $name := default .Chart.Name .Values.nameOverride }}
    {{- if contains $name .Release.Name }}
      {{- .Release.Name | trunc 63 | trimSuffix "-" }}
    {{- else }}
      {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "haproxy-ingress.defaultBackend.name" -}}
  {{- printf "%s-%s" .Chart.Name .Values.defaultBackend.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "haproxy-ingress.defaultBackend.fullname" -}}
  {{- $name := default .Chart.Name .Values.nameOverride }}
  {{- if contains $name .Release.Name }}
    {{- printf "%s-%s" .Release.Name .Values.defaultBackend.name | trunc 63 | trimSuffix "-" }}
  {{- else }}
    {{- printf "%s-%s-%s" .Release.Name $name .Values.defaultBackend.name | trunc 63 | trimSuffix "-" }}
  {{- end }}
{{- end }}


{{/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
  *
  *  Common and selector labels
  *
  *  We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
  *
  */}}
{{- define "haproxy-ingress.chart" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "haproxy-ingress.labels" -}}
helm.sh/chart: {{ include "haproxy-ingress.chart" . }}
{{ include "haproxy-ingress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/component: "tibco-platform-data-plane"
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "haproxy-ingress.selectorLabels" -}}
app.kubernetes.io/name: {{ include "haproxy-ingress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- /* platform specific labels. Copy paste these labels after upgrading the haproxy chart.*/}}
platform.tibco.com/dataplane-id: {{ .Values.global.tibco.dataPlaneId }}
platform.tibco.com/workload-type: infra
{{- end }}

{{- define "haproxy-ingress.defaultBackend.labels" -}}
helm.sh/chart: {{ include "haproxy-ingress.chart" . }}
{{ include "haproxy-ingress.defaultBackend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "haproxy-ingress.defaultBackend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "haproxy-ingress.defaultBackend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
  *
  *  Create the name of the service account to use
  *
  */}}
{{- define "haproxy-ingress.serviceAccountName" -}}
  {{- if .Values.serviceAccount.create }}
    {{- default (include "haproxy-ingress.fullname" .) .Values.serviceAccount.name }}
  {{- else }}
    {{- default "default" (tpl .Values.serviceAccount.name .) }}
  {{- end }}
{{- end }}


{{/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
  *
  * Construct the path for publish-service
  * 
  */}}
{{- define "haproxy-ingress.controller.publishServicePath" -}}
  {{- if .Values.controller.publishService.pathOverride }}
    {{- .Values.controller.publishService.pathOverride | trimSuffix "-" }}
  {{- else }}
    {{- printf "%s/%s" "$(POD_NAMESPACE)" (include "haproxy-ingress.fullname" .) | trimSuffix "-" }}
  {{- end }}
{{- end }}



{{- define "haproxy-ingress.const.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "haproxy-ingress.const.ecrImageRepo" }}stratosphere{{end}}
{{- define "haproxy-ingress.const.acrImageRepo" }}stratosphere{{end}}
{{- define "haproxy-ingress.const.harborImageRepo" }}stratosphere{{end}}
{{- define "haproxy-ingress.const.defaultImageRepo" }}stratosphere{{end}}

{{- define "haproxy-ingress.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "haproxy-ingress.image.repository" -}}
  {{- if contains "jfrog.io" (include "haproxy-ingress.image.registry" .) }} 
    {{- include "haproxy-ingress.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "haproxy-ingress.image.registry" .) }}
    {{- include "haproxy-ingress.const.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "haproxy-ingress.image.registry" .) }}
    {{- include "haproxy-ingress.const.harborImageRepo" .}}
  {{- else }}
    {{- include "haproxy-ingress.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}
