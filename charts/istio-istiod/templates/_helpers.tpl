# Copyright Â© 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
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

{{/* Prometheus is enabled if its enabled and there are no config overrides set */}}
{{ define "prometheus" }}
{{- and
  (not .Values.meshConfig.defaultProviders)
  .Values.telemetry.enabled .Values.telemetry.v2.enabled .Values.telemetry.v2.prometheus.enabled
  (not (or
    .Values.telemetry.v2.prometheus.configOverride.gateway
    .Values.telemetry.v2.prometheus.configOverride.inboundSidecar
    .Values.telemetry.v2.prometheus.configOverride.outboundSidecar
  )) }}
{{- end }}

{{/* SD has metrics and logging split. Metrics are enabled if SD is enabled and there are no config overrides set */}}
{{ define "sd-metrics" }}
{{- and
  (not .Values.meshConfig.defaultProviders)
  .Values.telemetry.enabled .Values.telemetry.v2.enabled .Values.telemetry.v2.stackdriver.enabled
  (not (or
    .Values.telemetry.v2.stackdriver.configOverride
    .Values.telemetry.v2.stackdriver.disableOutbound ))
}}
{{- end }}

{{/* SD has metrics and logging split. */}}
{{ define "sd-logs" }}
{{- and
  (not .Values.meshConfig.defaultProviders)
  .Values.telemetry.enabled .Values.telemetry.v2.enabled .Values.telemetry.v2.stackdriver.enabled
  (not (or
    .Values.telemetry.v2.stackdriver.configOverride
    (has .Values.telemetry.v2.stackdriver.outboundAccessLogging (list "" "ERRORS_ONLY"))
    (has .Values.telemetry.v2.stackdriver.inboundAccessLogging (list "" "ALL"))
    .Values.telemetry.v2.stackdriver.disableOutbound ))
}}
{{- end }}

{{- define "servicemesh.const.jfrogImageRepo" }}tibco-platform-local-docker/servicemesh{{end}}
{{- define "servicemesh.const.ecrImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.acrImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.gcrImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.harborImageRepo" }}servicemesh{{end}}
{{- define "servicemesh.const.dockerImageRepo" }}istio{{end}}
{{- define "servicemesh.const.defaultImageRepo" }}{{ .Values.pilot.hub | default .Values.global.hub }}{{end}}
 
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
