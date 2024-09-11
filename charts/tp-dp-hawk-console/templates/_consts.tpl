{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-dp-hawk-console.consts.appName" }}tp-dp-hawk-console{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-dp-hawk-console.consts.tenantName" }}hawk{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-dp-hawk-console.consts.component" }}tibco-platform-data-plane{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-dp-hawk-console.consts.team" }}tp-hawk{{ end -}}

{{/* Data plane workload type */}}
{{- define "tp-dp-hawk-console.consts.workloadType" }}infra{{ end -}}

{{- define "tp-dp-hawk-console.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-dp-hawk-console.image.repository" -}}
    {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}