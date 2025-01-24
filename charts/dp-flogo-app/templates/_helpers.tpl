{{/*
Copyright © 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "dp-flogo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dp-flogo-app.fullname" -}}
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
{{- define "dp-flogo-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dp-flogo-app.labels" -}}
helm.sh/chart: {{ include "dp-flogo-app.chart" . }}
{{ include "dp-flogo-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform.tibco.com/app-id: {{ .Values.appConfig.appId | quote }}
platform.tibco.com/app-type: flogo
platform.tibco.com/dataplane-id: {{ .Values.dpConfig.dataplaneId | quote }}
platform.tibco.com/workload-type: {{ .Values.appConfig.workloadType | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dp-flogo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dp-flogo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
platform.tibco.com/name: {{ include "dp-flogo-app.fullname" . }}
{{- end }}

{{/*
Flogo app deployment labels
*/}}
{{- define "dp-flogo-app.flogoapp.deployment.labels" -}}
platform.tibco.com/app-name: {{ include "dp-flogo-app.fullname" . }}
platform.tibco.com/app-version: {{ .Values.appConfig.appVersion | quote }}
platform.tibco.com/app.resources.limits.cpu: {{ (.Values.flogoapp.resources.limits).cpu | default "" | quote }}
platform.tibco.com/app.resources.limits.memory: {{ (.Values.flogoapp.resources.limits).memory | default "" | quote }}
platform.tibco.com/app.resources.requests.cpu: {{ (.Values.flogoapp.resources.requests).cpu | default "" | quote }}
platform.tibco.com/app.resources.requests.memory: {{ (.Values.flogoapp.resources.requests).memory | default "" | quote }}
platform.tibco.com/build-id: {{ .Values.appConfig.buildId | quote }}
platform.tibco.com/buildtype-base-image: {{ .Values.appConfig.flogoBaseImageTag | quote }}
platform.tibco.com/buildtype-version: {{ .Values.appConfig.flogoBuildTypeTag | quote }}
platform.tibco.com/capability-instance-id: {{ .Values.dpConfig.capabilityInstanceId | quote }}
platform.tibco.com/capability-version: {{ .Values.dpConfig.capabilityVersion | quote }}
platform.tibco.com/original-app-name: {{ .Values.appConfig.originalAppName | quote }}
platform.tibco.com/tags: {{ .Values.appConfig.tags | quote }}
platform.tibco.com/helm-repo-alias: {{ .Values.dpConfig.helmRepoAlias | quote }}
{{- end }}

{{/*
Flogo app deployment annotations
*/}}
{{- define "dp-flogo-app.flogoapp.deployment.annotations" -}}
platform.tibco.com/connectors: {{ .Values.appConfig.connectors | quote }}
{{- end }}

{{/*
Flogo app pod labels
*/}}
{{- define "dp-flogo-app.flogoapp.pod.labels" -}}
app: flogo-app
app.kubernetes.io/instance: {{ include "dp-flogo-app.fullname" . }}
platform.tibco.com/app-name: {{ include "dp-flogo-app.fullname" . }}
platform.tibco.com/app-version: {{ .Values.appConfig.appVersion | quote }}
platform.tibco.com/capability-instance-id: {{ .Values.dpConfig.capabilityInstanceId | quote }}
platform.tibco.com/name: {{ include "dp-flogo-app.fullname" . }}
platform.tibco.com/original-app-name: {{ .Values.appConfig.originalAppName | quote }}
platform.tibco.com/tags: {{ .Values.appConfig.tags | quote }}
{{- end }}

{{/*
Flogo app pod annotations
*/}}
{{- define "dp-flogo-app.flogoapp.pod.annotations" -}}
platform.tibco.com/app-logs-regex: "(?P<timestamp>[^ ]*)[ \t](?P<level>DEBUG|INFO|WARN|ERROR|FATAL)[ \t](?P<msg>.*)"
platform.tibco.com/app-logs-ts-layout: "2006-01-02T15:04:05.000Z"
platform.tibco.com/last-updated: {{ .Values.appConfig.lastUpdated | quote}}
{{- end }}

{{/*
Nullable secret value
*/}}
{{- define "secretValue" -}}
    {{- $value := . }}
    {{- if $value }}
        {{- printf "%s" $value | b64enc }}
    {{- else }}
         {{- printf "%q" "" }}
    {{- end }}
{{- end }}
