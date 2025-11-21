{{/*
   Copyright (c) 2025 Cloud Software Group, Inc.
   All Rights Reserved.

   File       : _consts.tpl
   Version    : 1.0.0
   Description: Template helpers defining constants for this chart.

    NOTES:
      - this file contains values that are specific only to this chart. Edit accordingly.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-prometheus.consts.appName" }}tp-cp-prometheus{{ end -}}

{{/* A fixed short name for the application to be used in TibcoRoute.  */}}
{{- define "tp-cp-prometheus.consts.appNameTibcoRoute" }}prometheus{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-prometheus.consts.component" }}hawk{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-prometheus.consts.team" }}tp-hawk{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-cp-prometheus.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-prometheus.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-prometheus-ds.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}
