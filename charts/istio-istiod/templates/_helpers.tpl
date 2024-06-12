{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}


{{/* Default Prometheus is enabled if its enabled and there are no config overrides set */}}
{{ define "default-prometheus" }}
{{- and
  (not .Values.meshConfig.defaultProviders)
  .Values.telemetry.enabled .Values.telemetry.v2.enabled .Values.telemetry.v2.prometheus.enabled
}}
{{- end }}

{{/* SD has metrics and logging split. Default metrics are enabled if SD is enabled */}}
{{ define "default-sd-metrics" }}
{{- and
  (not .Values.meshConfig.defaultProviders)
  .Values.telemetry.enabled .Values.telemetry.v2.enabled .Values.telemetry.v2.stackdriver.enabled
}}
{{- end }}

{{/* SD has metrics and logging split. */}}
{{ define "default-sd-logs" }}
{{- and
  (not .Values.meshConfig.defaultProviders)
  .Values.telemetry.enabled .Values.telemetry.v2.enabled .Values.telemetry.v2.stackdriver.enabled
}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "istio.controller.serviceAccountName" -}}
{{- if not .Values.serviceAccount.create -}}
{{- if ((((.Values.global.cp).resources).serviceaccount).serviceAccountName) -}}
{{ .Values.global.cp.resources.serviceaccount.serviceAccountName }}
{{- else -}}
{{ .Values.serviceAccount.name }}
{{- end -}}
{{- else -}}
istio-{{ .Release.Namespace }}{{- if not (eq .Values.revision "") }}-{{ .Values.revision }}{{- end }}-controller
{{- end -}}
{{- end -}}
{{- define "istio.reader.serviceAccountName" -}}
{{- if not .Values.serviceAccount.create -}}
{{- if ((((.Values.global.cp).resources).serviceaccount).serviceAccountName) -}}
{{ .Values.global.cp.resources.serviceaccount.serviceAccountName }}
{{- else -}}
{{ .Values.serviceAccount.name }}
{{- end -}}
{{- else -}}
istio-{{ .Release.Namespace }}{{- if not (eq .Values.revision "") }}-{{ .Values.revision }}{{- end }}-reader
{{- end -}}
{{- end -}}

{{- define "servicemesh.const.jfrogImageRepo" }}tibco-platform-local-docker/servicemesh{{end}}
{{- define "servicemesh.const.ecrImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.acrImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.gcrImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.harborImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.dockerImageRepo" }}istio{{end}}
{{- define "servicemesh.const.defaultImageRepo" }}tibco-platform-local-docker/servicemesh{{end}}
 
{{- define "servicemesh.image.registry" }}
  {{- if not (eq .Values.global.cp.containerRegistry.url "") }}
  {{- .Values.global.cp.containerRegistry.url }}{{"/"}}
  {{- end -}}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "servicemesh.image.repository" -}}
  {{- if contains "jfrog.io" (include "servicemesh.image.registry" .) }}
    {{- include "servicemesh.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "servicemesh.image.registry" .) }}
    {{- include "servicemesh.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "servicemesh.image.registry" .) }}
    {{- include "servicemesh.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "servicemesh.image.registry" .) }}
    {{- include "servicemesh.const.harborImageRepo" .}}
  {{- else if contains "gcr.io" (include "servicemesh.image.registry" .) }}
    {{- include "servicemesh.const.gcrImageRepo" .}}        
  {{- else if contains "docker.io" (include "servicemesh.image.registry" .) }}
    {{- include "servicemesh.const.dockerImageRepo" .}}        
  {{- else }}
    {{- include "servicemesh.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}
