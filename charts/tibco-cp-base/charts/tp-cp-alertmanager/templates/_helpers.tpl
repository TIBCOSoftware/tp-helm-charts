{{/*
Copyright 2025 Alert Manager Community Charts

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "alertmanager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "alertmanager.fullname" -}}
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
{{- define "alertmanager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "alertmanager.labels" -}}
helm.sh/chart: {{ include "alertmanager.chart" . }}
{{ include "alertmanager.selectorLabels" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "alertmanager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "alertmanager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "alertmanager.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "alertmanager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Define Ingress apiVersion
*/}}
{{- define "alertmanager.ingress.apiVersion" -}}
{{- printf "networking.k8s.io/v1" }}
{{- end }}

{{/*
Define Pdb apiVersion
*/}}
{{- define "alertmanager.pdb.apiVersion" -}}
{{- if $.Capabilities.APIVersions.Has "policy/v1/PodDisruptionBudget" }}
{{- printf "policy/v1" }}
{{- else }}
{{- printf "policy/v1beta1" }}
{{- end }}
{{- end }}

{{/*
Allow overriding alertmanager namespace
*/}}
{{- define "alertmanager.namespace" -}}
{{- if .Values.namespaceOverride -}}
{{- .Values.namespaceOverride -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}


{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-alertmanager.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}


{{- define "tp-cp-alertmanager.image.registry" }}
  {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-alertmanager.image.repository" -}}
  {{- default "tibco-platform-docker-prod" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Control plane dns domain. default value local */}}
{{- define "tp-alertmanager.dns-domain" -}}
  {{- default "local" .Values.global.external.dnsDomain }}
{{- end }}
