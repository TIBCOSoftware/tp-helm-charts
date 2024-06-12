{{/*
   Copyright (c) 2024 Cloud Software Group, Inc.
   All Rights Reserved.

   File       : _consts.tpl
   Version    : 1.0.0
   Description: Template helpers defining constants for this chart.

    NOTES:
      - this file contains values that are specific only to this chart. Edit accordingly.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-hawk-infra.consts.appName" }}tp-hawk-infra{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-hawk-infra.consts.component" }}hawk{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-hawk-infra.consts.team" }}tp-hawk{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-hawk-infra.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{/* Hawk DB prefix. use _ as last char */}}
{{- define "tp-hawk-infra.consts.hawkDbPrefix" }}{{ include "tp-hawk-infra.cp-instance-id" . | replace "-" "_" }}_{{ end -}}

{{- define "tp-hawk-infra.consts.jfrogImageRepo" }}tibco-platform-local-docker/hawk{{end}}
{{- define "tp-hawk-infra.consts.ecrImageRepo" }}infra-hawk/control-tower{{end}}
{{- define "tp-hawk-infra.consts.acrImageRepo" }}infra-hawk/control-tower{{end}}
{{- define "tp-hawk-infra.consts.harborImageRepo" }}infra-hawk/control-tower{{end}}
{{- define "tp-hawk-infra.consts.defaultImageRepo" }}tibco-platform-local-docker/hawk{{end}}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-hawk-infra.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-hawk-infra.image.registry" .) }}
    {{- include "tp-hawk-infra.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-hawk-infra.image.registry" .) }}
    {{- include "tp-hawk-infra.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-hawk-infra.image.registry" .) }}
    {{- include "tp-hawk-infra.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-hawk-infra.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}