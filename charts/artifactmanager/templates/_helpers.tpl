{{/*
   Copyright (c) 2023 - 2024 Cloud Software Group Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.

   Expand the name of the chart.
*/}}
{{- define "artifactmanager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "artifactmanager.fullname" }}artifactmanager{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "artifactmanager.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "artifactmanager.labels" -}}
helm.sh/chart: {{ include "artifactmanager.chart" . }}
{{ include "artifactmanager.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "artifactmanager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "artifactmanager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "core"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "artifactmanager.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "artifactmanager.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.artifactmanager.serviceAccount . }}
{{- end }}
{{- end }}

{{/*
Get PVC name for persistent volume
*/}}
{{- define "artifactmanager.persistentVolumeClaim.claimName" -}}
{{- .existingClaim | default (printf "%s-%s" .releaseName .volumeName) -}}
{{- end -}}

{{/*
Integration storage folder pvc name
*/}}
{{- define "artifactmanager.storage.pvc.name" -}}
{{- include "artifactmanager.persistentVolumeClaim.claimName" (dict "existingClaim" .Values.volumes.artifactmanager.existingClaim "releaseName" ( include "artifactmanager.fullname" . ) "volumeName" "integration" ) -}}
{{- end -}}

{{- define "artifactmanager.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{- define "artifactmanager.const.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "artifactmanager.const.ecrImageRepo" }}stratosphere{{end}}
{{- define "artifactmanager.const.acrImageRepo" }}stratosphere{{end}}
{{- define "artifactmanager.const.harborImageRepo" }}stratosphere{{end}}
{{- define "artifactmanager.const.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "artifactmanager.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "artifactmanager.image.repository" -}}
  {{- if contains "jfrog.io" (include "artifactmanager.image.registry" .) }}
    {{- include "artifactmanager.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "artifactmanager.image.registry" .) }}
    {{- include "artifactmanager.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "artifactmanager.image.registry" .) }}
    {{- include "artifactmanager.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "artifactmanager.image.registry" .) }}
    {{- include "artifactmanager.const.harborImageRepo" .}}
  {{- else }}
    {{- include "artifactmanager.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}