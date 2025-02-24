{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "dp-bwce-mon.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "dp-bwce-mon.fullname" }}dp-bwce-mon{{ end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dp-bwce-mon.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dp-bwce-mon.labels" -}}
helm.sh/chart: {{ include "dp-bwce-mon.chart" . }}
{{ include "dp-bwce-mon.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dp-bwce-mon.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dp-bwce-mon.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "bwce"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{- define "dp-bwce-mon.bwcemonConfig" -}}
PERSISTENCE_TYPE: {{ .Values.global.cp.resources.dbconfig.persistenceType | quote }}
DB_HOST: {{ .Values.global.cp.resources.dbconfig.dbHost | quote }}
DB_PORT: {{ .Values.global.cp.resources.dbconfig.dbPort | quote }}
DB_NAME: {{ .Values.global.cp.resources.dbconfig.dbName | quote }}
DB_USER: {{ .Values.global.cp.resources.dbconfig.dbUser | quote }}
{{- end }}

{{- define "dp-bwce-mon.bwcemonConfigSecret" -}}
DB_PWD: {{ .Values.global.cp.resources.dbconfig.secretDbPassword | quote }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dp-bwce-mon.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dp-bwce-mon.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- tpl .Values.global.cp.resources.serviceaccount.serviceAccountName . }}
{{- end }}
{{- end }}

{{- define "dp-bwce-mon.sa" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-sa{{ end -}}
{{- define "dp-bwce-mon.role" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-role{{ end -}}
{{- define "dp-bwce-mon.role-bind" }}tp-dp-{{ .Values.global.cp.dataplaneId }}-role-bind{{ end -}}


{{- define "dp-bwce-mon.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "dp-bwce-mon.image.repository" -}}
  {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "dp-bwce-mon.integration.image.repository" -}}
  {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}
