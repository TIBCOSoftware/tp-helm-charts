{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}


{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "hybrid-proxy.consts.appName" }}hybrid-proxy{{ end -}}
{{- define "hybrid-proxy.consts.deploymentName" }}cp-hybrid-proxy{{ end -}}

{{/* Tenant name. */}}
{{- define "hybrid-proxy.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "hybrid-proxy.consts.component" }}tibco-cp-base{{ end -}}

{{/* Team we're a part of. */}}
{{- define "hybrid-proxy.consts.team" }}cic-compute{{ end -}}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "hybrid-proxy.consts.globalResourceName" }}{{ include "hybrid-proxy.consts.appName" . }}-{{ .Values.global.tibco.controlPlaneInstanceId }}{{ end -}}

{{/* Name of the webhook */}}
{{- define "hybrid-proxy.consts.webhook" }}{{ include "hybrid-proxy.consts.globalResourceName" . }}{{ end -}}

{{/* Name of the default service account */}}
{{- define "hybrid-proxy.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "hybrid-proxy.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "hybrid-proxy.image.registry" }}
    {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "hybrid-proxy.image.repository" -}}
    {{- .Values.global.tibco.containerRegistry.repository }}
{{- end -}}
