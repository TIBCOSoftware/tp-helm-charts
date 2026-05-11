{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
  This file is subject to the license terms contained
  in the license file that is distributed with this file.
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

