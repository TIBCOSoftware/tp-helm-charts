{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-tibtunnel.consts.appName" }}tp-tibtunnel{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-tibtunnel.consts.tenantName" }}infrastructure{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-tibtunnel.consts.component" }}tibco-platform-data-plane{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-tibtunnel.consts.team" }}cic-compute{{ end -}}

{{/* Data plane workload type */}}
{{- define "tp-tibtunnel.consts.workloadType" }}infra{{ end -}}

{{- define "tp-tibtunnel.consts.fluentbit.buildNumber" }}1.9.4{{end -}}

{{- define "tp-tibtunnel.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-tibtunnel.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository}}
{{- end -}}