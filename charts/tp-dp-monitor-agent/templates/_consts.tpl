{{/*
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-dp-monitor-agent.consts.appName" }}tp-dp-monitor-agent{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-dp-monitor-agent.consts.tenantName" }}finops{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-dp-monitor-agent.consts.component" }}finops{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-dp-monitor-agent.consts.team" }}tp-finops{{ end -}}
{{- define "tp-dp-monitor-agent.consts.fluentbit.buildNumber" }}2.2.2{{ end -}}

{{- define "tp-dp-monitor-agent.const.jfrogImageRepo" }}tibco-platform-local-docker/finops{{end}}
{{- define "tp-dp-monitor-agent.const.ecrImageRepo" }}pdp{{end}}
{{- define "tp-dp-monitor-agent.const.acrImageRepo" }}pdp{{end}}
{{- define "tp-dp-monitor-agent.const.harborImageRepo" }}pdp{{end}}
{{- define "tp-dp-monitor-agent.const.defaultImageRepo" }}tibco-platform-local-docker/finops{{end}}
 
{{- define "tp-dp-monitor-agent.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-dp-monitor-agent.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-dp-monitor-agent.image.registry" .) }}
    {{- include "tp-dp-monitor-agent.const.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-dp-monitor-agent.image.registry" .) }}
    {{- include "tp-dp-monitor-agent.const.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-dp-monitor-agent.image.registry" .) }}
    {{- include "tp-dp-monitor-agent.const.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-dp-monitor-agent.image.registry" .) }}
    {{- include "tp-dp-monitor-agent.const.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-dp-monitor-agent.const.defaultImageRepo" .}}
  {{- end }}
{{- end -}}