{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-subscription.consts.appName" }}hybrid-server-{{ .Values.subscriptionId }}{{ end -}}


{{- define "tp-cp-subscription.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-subscription.consts.component" }}resource-set{{ end -}}


{{/* Team we're a part of. */}}
{{- define "tp-cp-subscription.consts.team" }}cic-compute{{ end -}}

{{- define "tp-cp-subscription.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-cp-subscription.container-registry.secret" }}{{ .Values.global.tibco.containerRegistry.secret }}{{end}}

{{- define "tp-cp-subscription.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "tp-cp-subscription.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-subscription.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-subscription.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-subscription.consts.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "tp-cp-subscription.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- .Values.global.tibco.containerRegistry.url }}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-subscription.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "tp-cp-subscription.image.registry" .) }} 
    {{- include "tp-cp-subscription.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-subscription.image.registry" .) }}
    {{- include "tp-cp-subscription.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-subscription.image.registry" .) }}
    {{- include "tp-cp-subscription.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-subscription.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* control plane deployment target */}}
{{- define "tp-cp-subscription.cp-provider" }}
{{- .Values.global.external.provider -}}
{{- end }}

{{/* Node CIDR for the cluster */}}
{{- define "tp-cp-subscription.nodeCIDR" }}
{{- .Values.global.external.clusterInfo.nodeCIDR -}}
{{- end }}

{{/* Pod CIDR for the cluster */}}
{{- define "tp-cp-subscription.podCIDR" }}
{{- if .Values.global.tibco.createNetworkPolicy }}
{{- if empty .Values.global.external.clusterInfo.podCIDR }}
{{- .Values.global.external.clusterInfo.nodeCIDR }}
{{- else }}
{{- .Values.global.external.clusterInfo.podCIDR }}
{{- end }}
{{- end }}
{{- end }}
