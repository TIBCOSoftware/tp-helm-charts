{{/*
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "bwprovisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bwprovisioner.fullname" }}bwprovisioner{{ end -}}

{{- define "bwprovisioner.o11yservice.configmap" }}o11y-service{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bwprovisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bwprovisioner.labels" -}}
helm.sh/chart: {{ include "bwprovisioner.chart" . }}
{{ include "bwprovisioner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bwprovisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bwprovisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "bwce"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bwprovisioner.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "bwprovisioner.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.cp.resources.serviceaccount.serviceAccountName . }}
{{- end }}
{{- end }}

{{/*
Get PVC name for persistent volume
*/}}
{{- define "bwprovisioner.persistentVolumeClaim.claimName" -}}
{{- .existingClaim | default (printf "%s-%s" .releaseName .volumeName) -}}
{{- end -}}

{{/*
Integration storage folder pvc name
*/}}
{{- define "bwprovisioner.storage.pvc.name" -}}
{{- include "bwprovisioner.persistentVolumeClaim.claimName" (dict "existingClaim" .Values.volumes.bwprovisioner.existingClaim "releaseName" ( include "bwprovisioner.fullname" . ) "volumeName" "integration" ) -}}
{{- end -}}

{{- define "bwprovisioner.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{- define "bwprovisioner.sa" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-sa{{ end -}}
{{- define "bwprovisioner.role" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-role{{ end -}}
{{- define "bwprovisioner.role-bind" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-role-bind{{ end -}}


{{- define "bwprovisioner.const.jfrogImageRepo" }}tibco-platform-local-docker/bwce{{end}}
{{- define "bwprovisioner.const.ecrImageRepo" }}piap{{end}}
{{- define "bwprovisioner.const.acrImageRepo" }}piap{{end}}
{{- define "bwprovisioner.const.harborImageRepo" }}piap{{end}}
{{- define "bwprovisioner.const.defaultImageRepo" }}pea-coreintegration/tibco-control-plane/tibco-platform-local-docker/bwce{{end}}

{{- define "bwprovisioner.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bwprovisioner.image.repository" -}}
  {{- if contains "jfrog.io" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.const.harborImageRepo" .}}
  {{- else }}
    {{- include "bwprovisioner.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{- define "bwprovisioner.appinit.const.jfrogImageRepo" }}tibco-platform-local-docker/integration{{end}}
{{- define "bwprovisioner.appinit.const.ecrImageRepo" }}piap{{end}}
{{- define "bwprovisioner.appinit.const.acrImageRepo" }}piap{{end}}
{{- define "bwprovisioner.appinit.const.harborImageRepo" }}piap{{end}}
{{- define "bwprovisioner.appinit.const.defaultImageRepo" }}pea-coreintegration/tibco-control-plane/tibco-platform-local-docker/integration{{end}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bwprovisioner.appinit.image.repository" -}}
  {{- if contains "jfrog.io" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.appinit.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.appinit.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.appinit.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bwprovisioner.image.registry" .) }}
    {{- include "bwprovisioner.appinit.const.harborImageRepo" .}}
  {{- else }}
    {{- include "bwprovisioner.appinit.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}