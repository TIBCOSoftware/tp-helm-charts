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
{{- define "tp-hawk-infra-prometheus.consts.appName" }}prometheus{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-hawk-infra-prometheus.consts.component" }}hawk{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-hawk-infra-prometheus.consts.team" }}tp-hawk{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-hawk-infra-prometheus.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-hawk-infra-prometheus.consts.buildNumber" }}v2.45.5{{ end -}}

{{- define "tp-hawk-infra-prometheus.consts.jfrogImageRepo" }}tibco-platform-local-docker/hawk{{end}}
{{- define "tp-hawk-infra-prometheus.consts.ecrImageRepo" }}infra-hawk/infra-control-tower{{end}}
{{- define "tp-hawk-infra-prometheus.consts.acrImageRepo" }}infra-hawk/infra-control-tower{{end}}
{{- define "tp-hawk-infra-prometheus.consts.harborImageRepo" }}infra-hawk/infra-control-tower{{end}}
{{- define "tp-hawk-infra-prometheus.consts.defaultImageRepo" }}tibco-platform-local-docker/hawk{{end}}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-hawk-infra-prometheus.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-hawk-infra-prometheus.image.registry" .) }}
    {{- include "tp-hawk-infra-prometheus.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-hawk-infra-prometheus.image.registry" .) }}
    {{- include "tp-hawk-infra-prometheus.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-hawk-infra-prometheus.image.registry" .) }}
    {{- include "tp-hawk-infra-prometheus.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-hawk-infra-prometheus.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{- define "tp-hawk-infra-prometheusds.consts.jfrogImageRepo" }}tibco-platform-local-docker/hawk{{end}}
{{- define "tp-hawk-infra-prometheusds.consts.ecrImageRepo" }}infra-hawk/control-tower{{end}}
{{- define "tp-hawk-infra-prometheusds.consts.acrImageRepo" }}infra-hawk/control-tower{{end}}
{{- define "tp-hawk-infra-prometheusds.consts.harborImageRepo" }}infra-hawk/control-tower{{end}}
{{- define "tp-hawk-infra-prometheusds.consts.defaultImageRepo" }}tibco-platform-local-docker/hawk{{end}}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-hawk-infra-prometheusds.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-hawk-infra-prometheus.image.registry" .) }}
    {{- include "tp-hawk-infra-prometheusds.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-hawk-infra-prometheus.image.registry" .) }}
    {{- include "tp-hawk-infra-prometheusds.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-hawk-infra-prometheus.image.registry" .) }}
    {{- include "tp-hawk-infra-prometheusds.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-hawk-infra-prometheusds.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}
