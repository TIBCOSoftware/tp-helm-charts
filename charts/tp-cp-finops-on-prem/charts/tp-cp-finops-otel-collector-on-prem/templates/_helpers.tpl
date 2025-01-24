{{/*
Expand the name of the chart.
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-finops-otel-collector-on-prem.lowercase_chartname" -}}
{{- default .Chart.Name | lower }}
{{- end }}

{{/*
Get component name
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.component" -}}
{{- if eq .Values.mode "deployment" -}}
component: standalone-collector
{{- end -}}
{{- if eq .Values.mode "daemonset" -}}
component: agent-collector
{{- end -}}
{{- if eq .Values.mode "statefulset" -}}
component: statefulset-collector
{{- end -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.labels" -}}
helm.sh/chart: {{ include "tp-cp-finops-otel-collector-on-prem.chart" . }}
{{ include "tp-cp-finops-otel-collector-on-prem.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "tp-cp-finops-otel-collector-on-prem.additionalLabels" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-finops-otel-collector-on-prem.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "tp-cp-finops-otel-collector-on-prem.const.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "tp-cp-finops-otel-collector-on-prem.const.ecrImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-finops-otel-collector-on-prem.const.acrImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-finops-otel-collector-on-prem.const.harborImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-finops-otel-collector-on-prem.const.defaultImageRepo" }}stratosphere{{end}}

{{- define "tp-cp-finops-otel-collector-on-prem.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-finops-otel-collector-on-prem.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-finops-otel-collector-on-prem.image.registry" .) }}
    {{- include "tp-cp-finops-otel-collector-on-prem.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-finops-otel-collector-on-prem.image.registry" .) }}
    {{- include "tp-cp-finops-otel-collector-on-prem.const.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-finops-otel-collector-on-prem.image.registry" .) }}
    {{- include "tp-cp-finops-otel-collector-on-prem.const.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-finops-otel-collector-on-prem.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{/*
Create the name of the service account to use
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tp-cp-finops-otel-collector-on-prem.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Create the name of the clusterRole to use
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.clusterRoleName" -}}
{{- default (include "tp-cp-finops-otel-collector-on-prem.fullname" .) .Values.clusterRole.name }}
{{- end }}

{{/*
Create the name of the clusterRoleBinding to use
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.clusterRoleBindingName" -}}
{{- default (include "tp-cp-finops-otel-collector-on-prem.fullname" .) .Values.clusterRole.clusterRoleBinding.name }}
{{- end }}

{{- define "tp-cp-finops-otel-collector-on-prem.podAnnotations" -}}
{{- if .Values.podAnnotations }}
{{- tpl (.Values.podAnnotations | toYaml) . }}
{{- end }}
{{- end }}

{{- define "tp-cp-finops-otel-collector-on-prem.podLabels" -}}
{{- if .Values.podLabels }}
{{- tpl (.Values.podLabels | toYaml) . }}
{{- end }}
{{- end }}

{{- define "tp-cp-finops-otel-collector-on-prem.additionalLabels" -}}
{{- if .Values.additionalLabels }}
{{- tpl (.Values.additionalLabels | toYaml) . }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for podDisruptionBudget.
*/}}
{{- define "podDisruptionBudget.apiVersion" -}}
  {{- if and (.Capabilities.APIVersions.Has "policy/v1") (semverCompare ">= 1.21-0" .Capabilities.KubeVersion.Version) -}}
    {{- print "policy/v1" -}}
  {{- else -}}
    {{- print "policy/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{/*
Compute Service creation on mode
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.serviceEnabled" }}
  {{- $serviceEnabled := true }}
  {{- if not (eq (toString .Values.service.enabled) "<nil>") }}
    {{- $serviceEnabled = .Values.service.enabled -}}
  {{- end }}
  {{- if and (eq .Values.mode "daemonset") (not .Values.service.enabled) }}
    {{- $serviceEnabled = false -}}
  {{- end }}

  {{- print $serviceEnabled }}
{{- end -}}


{{/*
Compute InternalTrafficPolicy on Service creation
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.serviceInternalTrafficPolicy" }}
  {{- if and (eq .Values.mode "daemonset") (.Values.service.enabled) }}
    {{- print (.Values.service.internalTrafficPolicy | default "Local") -}}
  {{- else }}
    {{- print (.Values.service.internalTrafficPolicy | default "Cluster") -}}
  {{- end }}
{{- end -}}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Convert memory value to numeric value in MiB to be used by otel memory_limiter processor.
*/}}
{{- define "tp-cp-finops-otel-collector-on-prem.convertMemToMib" -}}
{{- $mem := lower . -}}
{{- if hasSuffix "e" $mem -}}
{{- trimSuffix "e" $mem | atoi | mul 1000 | mul 1000 | mul 1000 | mul 1000 -}}
{{- else if hasSuffix "ei" $mem -}}
{{- trimSuffix "ei" $mem | atoi | mul 1024 | mul 1024 | mul 1024 | mul 1024 -}}
{{- else if hasSuffix "p" $mem -}}
{{- trimSuffix "p" $mem | atoi | mul 1000 | mul 1000 | mul 1000 -}}
{{- else if hasSuffix "pi" $mem -}}
{{- trimSuffix "pi" $mem | atoi | mul 1024 | mul 1024 | mul 1024 -}}
{{- else if hasSuffix "t" $mem -}}
{{- trimSuffix "t" $mem | atoi | mul 1000 | mul 1000 -}}
{{- else if hasSuffix "ti" $mem -}}
{{- trimSuffix "ti" $mem | atoi | mul 1024 | mul 1024 -}}
{{- else if hasSuffix "g" $mem -}}
{{- trimSuffix "g" $mem | atoi | mul 1000 -}}
{{- else if hasSuffix "gi" $mem -}}
{{- trimSuffix "gi" $mem | atoi | mul 1024 -}}
{{- else if hasSuffix "m" $mem -}}
{{- div (trimSuffix "m" $mem | atoi | mul 1000) 1024 -}}
{{- else if hasSuffix "mi" $mem -}}
{{- trimSuffix "mi" $mem | atoi -}}
{{- else if hasSuffix "k" $mem -}}
{{- div (trimSuffix "k" $mem | atoi) 1000 -}}
{{- else if hasSuffix "ki" $mem -}}
{{- div (trimSuffix "ki" $mem | atoi) 1024 -}}
{{- else -}}
{{- div (div ($mem | atoi) 1024) 1024 -}}
{{- end -}}
{{- end -}}
