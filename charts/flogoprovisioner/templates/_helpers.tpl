{{/*
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "flogoprovisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flogoprovisioner.fullname" }}flogoprovisioner{{ end -}}

{{- define "flogoprovisioner.o11yservice.configmap" }}o11y-service{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flogoprovisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flogoprovisioner.labels" -}}
helm.sh/chart: {{ include "flogoprovisioner.chart" . }}
{{ include "flogoprovisioner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flogoprovisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flogoprovisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "flogo"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flogoprovisioner.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flogoprovisioner.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.cp.resources.serviceaccount.serviceAccountName . }}
{{- end }}
{{- end }}

{{/*
Get PVC name for persistent volume
*/}}
{{- define "flogoprovisioner.persistentVolumeClaim.claimName" -}}
{{- .existingClaim | default (printf "%s-%s" .releaseName .volumeName) -}}
{{- end -}}

{{/*
Integration storage folder pvc name
*/}}
{{- define "flogoprovisioner.storage.pvc.name" -}}
{{- include "flogoprovisioner.persistentVolumeClaim.claimName" (dict "existingClaim" .Values.volumes.flogoprovisioner.existingClaim "releaseName" ( include "flogoprovisioner.fullname" . ) "volumeName" "integration" ) -}}
{{- end -}}

{{- define "flogoprovisioner.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{- define "flogoprovisioner.sa" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-sa{{ end -}}
{{- define "flogoprovisioner.role" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-role{{ end -}}
{{- define "flogoprovisioner.role-bind" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-role-bind{{ end -}}


{{- define "flogoprovisioner.const.jfrogImageRepo" }}tibco-platform-local-docker/flogo{{end}}
{{- define "flogoprovisioner.const.ecrImageRepo" }}piap{{end}}
{{- define "flogoprovisioner.const.acrImageRepo" }}piap{{end}}
{{- define "flogoprovisioner.const.harborImageRepo" }}piap{{end}}
{{- define "flogoprovisioner.const.defaultImageRepo" }}tibco-platform-local-docker/flogo{{end}}

{{- define "flogoprovisioner.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogoprovisioner.image.repository" -}}
  {{- if contains "jfrog.io" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.const.harborImageRepo" .}}
  {{- else }}
    {{- include "flogoprovisioner.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{- define "flogoprovisioner.appinit.const.jfrogImageRepo" }}tibco-platform-local-docker/integration{{end}}
{{- define "flogoprovisioner.appinit.const.ecrImageRepo" }}piap{{end}}
{{- define "flogoprovisioner.appinit.const.acrImageRepo" }}piap{{end}}
{{- define "flogoprovisioner.appinit.const.harborImageRepo" }}piap{{end}}
{{- define "flogoprovisioner.appinit.const.defaultImageRepo" }}tibco-platform-local-docker/integration{{end}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogoprovisioner.appinit.image.repository" -}}
  {{- if contains "jfrog.io" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.appinit.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.appinit.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.appinit.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "flogoprovisioner.image.registry" .) }}
    {{- include "flogoprovisioner.appinit.const.harborImageRepo" .}}
  {{- else }}
    {{- include "flogoprovisioner.appinit.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}