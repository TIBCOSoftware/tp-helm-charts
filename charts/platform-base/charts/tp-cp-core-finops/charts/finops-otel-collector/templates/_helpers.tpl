{{/*
Expand the name of the chart.
*/}}
{{- define "finops-otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "finops-otel-collector.lowercase_chartname" -}}
{{- default .Chart.Name | lower }}
{{- end }}

{{/*
Get component name
*/}}
{{- define "finops-otel-collector.component" -}}
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
Get ConfigMap name if existingName is defined, otherwise use default name for generated config.
*/}}
{{- define "otel-collector.configName" -}}
  {{- if .Values.configMap.existingName -}}
    {{- tpl (.Values.configMap.existingName | toYaml) . }}
  {{- else }}
    {{- printf "%s%s" (include "otel-collector.fullname" .) (.configmapSuffix) }}
  {{- end -}}
{{- end }}

{{/*
Create ConfigMap checksum annotation if configMap.existingPath is defined, otherwise use default templates
*/}}
{{- define "otel-collector.configTemplateChecksumAnnotation" -}}
  {{- if .Values.configMap.existingPath -}}
  checksum/config: {{ include (print $.Template.BasePath "/" .Values.configMap.existingPath) . | sha256sum }}
  {{- else -}}
    {{- if eq .Values.mode "daemonset" -}}
    checksum/config: {{ include (print $.Template.BasePath "/configmap-agent.yaml") . | sha256sum }}
    {{- else if eq .Values.mode "deployment" -}}
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    {{- else if eq .Values.mode "statefulset" -}}
    checksum/config: {{ include (print $.Template.BasePath "/configmap-statefulset.yaml") . | sha256sum }}
    {{- end -}}
  {{- end }}
{{- end }}


{{- define "otel-collector.gomemlimit" }}
{{- $memlimitBytes := include "otel-collector.convertMemToBytes" . | mulf 0.8 -}}
{{- printf "%dMiB" (divf $memlimitBytes 0x1p20 | floor | int64) -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "finops-otel-collector.fullname" -}}
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
{{- define "finops-otel-collector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "finops-otel-collector.labels" -}}
helm.sh/chart: {{ include "finops-otel-collector.chart" . }}
{{ include "finops-otel-collector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if eq .Values.mode "deployment" }}
app.kubernetes.io/component: standalone-collector
{{- end -}}
{{- if eq .Values.mode "daemonset" }}
app.kubernetes.io/component: agent-collector
{{- end -}}
{{- if eq .Values.mode "statefulset" }}
app.kubernetes.io/component: statefulset-collector
{{- end -}}
{{- if .Values.additionalLabels }}
{{ tpl (.Values.additionalLabels | toYaml) . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "finops-otel-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "finops-otel-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "finops-otel-collector.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url | default "csgprdusw2reposaas.jfrog.io" }}
{{- end -}}

{{- define "finops-otel-collector.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{- define "finops-otel-collector.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "finops-otel-collector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "finops-otel-collector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Create the name of the clusterRole to use
*/}}
{{- define "finops-otel-collector.clusterRoleName" -}}
{{- default (include "finops-otel-collector.fullname" .) .Values.clusterRole.name }}
{{- end }}

{{/*
Create the name of the clusterRoleBinding to use
*/}}
{{- define "finops-otel-collector.clusterRoleBindingName" -}}
{{- default (include "finops-otel-collector.fullname" .) .Values.clusterRole.clusterRoleBinding.name }}
{{- end }}

{{- define "finops-otel-collector.podAnnotations" -}}
{{- if .Values.podAnnotations }}
{{- tpl (.Values.podAnnotations | toYaml) . }}
{{- end }}
{{- end }}

{{- define "finops-otel-collector.podLabels" -}}
{{- if .Values.podLabels }}
{{- tpl (.Values.podLabels | toYaml) . }}
{{- end }}
{{- end }}

{{- define "finops-otel-collector.additionalLabels" -}}
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
{{- define "finops-otel-collector.serviceEnabled" }}
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
{{- define "finops-otel-collector.serviceInternalTrafficPolicy" }}
  {{- if and (eq .Values.mode "daemonset") (.Values.service.enabled) }}
    {{- print (.Values.service.internalTrafficPolicy | default "Local") -}}
  {{- else }}
    {{- print (.Values.service.internalTrafficPolicy | default "Cluster") -}}
  {{- end }}
{{- end -}}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "finops-otel-collector.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Convert memory value to numeric value in MiB to be used by otel memory_limiter processor.
*/}}
{{- define "finops-otel-collector.convertMemToMib" -}}
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

{{/*
Convert memory value to numeric value in Bytes to be used by otel memory_limiter processor.
*/}}
{{- define "otel-collector.convertMemToBytes" -}}
{{- $mem := lower . -}}
{{- if hasSuffix "gi" $mem -}}
{{- trimSuffix "gi" $mem | atoi | mul 1073741824 -}}
{{- else if hasSuffix "mi" $mem -}}
{{- trimSuffix "mi" $mem | atoi | mul 1048576 -}}
{{- else if hasSuffix "ki" $mem -}}
{{- trimSuffix "ki" $mem | atoi | mul 1024 -}}
{{- else if hasSuffix "g" $mem -}}
{{- trimSuffix "g" $mem | atoi | mul 1000000000 -}}
{{- else if hasSuffix "m" $mem -}}
{{- trimSuffix "m" $mem | atoi | mul 1000000 -}}
{{- else if hasSuffix "k" $mem -}}
{{- trimSuffix "k" $mem | atoi | mul 1000 -}}
{{- else -}}
{{- $mem | atoi -}}
{{- end -}}
{{- end -}}