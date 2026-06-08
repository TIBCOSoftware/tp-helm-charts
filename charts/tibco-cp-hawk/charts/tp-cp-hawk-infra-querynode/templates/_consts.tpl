f{{/*
   Copyright (c) 2024 Cloud Software Group, Inc.
   All Rights Reserved.

   File       : _consts.tpl
   Version    : 1.0.0
   Description: Template helpers defining constants for this chart.

    NOTES:
      - this file contains values that are specific only to this chart. Edit accordingly.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-hawk-infra-querynode.consts.appName" }}querynode{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-hawk-infra-querynode.consts.component" }}hawk{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-hawk-infra-querynode.consts.team" }}tp-hawk{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-hawk-infra-querynode.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-hawk-infra-querynode.consts.hawkDbPrefix" }}{{ include "tp-hawk-infra-querynode.cp-instance-id" . | replace "-" "_" }}_{{ end -}}

{{/* CP Core scripts build number */}}
{{- define "cp-core-scripts.buildNumber" }}9474{{ end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-hawk-infra-querynode.image.repository" -}}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
  {{- printf "%s" $hawkCP.CP_CONTAINER_REGISTRY_REPO -}}
{{- end -}}

{{/*Confingmap name from CP Namespace*/}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/* Address of Monitoring service in CP */}}
{{- define "tp-hawk-infra-querynode.consts.monitoringService" }}tp-cp-monitoring-service.{{ include "tp-hawk-infra-querynode.consts.namespace" . }}.svc.cluster.local:7831{{ end -}}
