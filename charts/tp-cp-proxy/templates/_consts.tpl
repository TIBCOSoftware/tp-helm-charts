{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-proxy.consts.appName" }}cp-proxy{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-cp-proxy.consts.tenantName" }}infrastructure{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-proxy.consts.component" }}tibco-platform-data-plane{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-proxy.consts.team" }}cic-compute{{ end -}}

{{/* Data plane workload type */}}
{{- define "tp-cp-proxy.consts.workloadType" }}infra{{ end -}}

{{/* Secret name created as part of client credentials generation */}}
{{- define "tp-cp-proxy.consts.outputSecretName"}}cp-proxy-client-credentials{{ end -}}
 
{{- define "tp-cp-proxy.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-proxy.image.repository" -}}
  {{- .Values.global.cp.containerRegistry.repository }}
{{- end -}}