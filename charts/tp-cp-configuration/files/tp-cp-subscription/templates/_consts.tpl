{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-subscription.consts.appName" }}
  {{- if (eq (.Values.global.tibco.useSingleNamespace | toString ) "true") }}
    {{- "hybrid-server" -}}-{{- .Values.subscriptionId -}}
  {{- else }}
    {{- "hybrid-server" -}}
  {{- end -}}
{{- end -}}


{{- define "tp-cp-subscription.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-subscription.consts.component" }}resource-set{{ end -}}


{{/* Team we're a part of. */}}
{{- define "tp-cp-subscription.consts.team" }}cic-compute{{ end -}}

{{- define "tp-cp-subscription.consts.serviceAccount" }}
  {{- if .Values.global.tibco.serviceAccount }}
    {{- .Values.global.tibco.serviceAccount -}}
  {{- else }}
    {{- include "tp-cp-subscription.consts.appName" . -}}
  {{- end -}}
{{- end -}}

{{- define "tp-cp-subscription.consts.namespace" }}
  {{- if .Values.global.tibco.useSingleNamespace }}
    {{ .Release.Namespace }}
  {{- else }}
    {{- .Values.global.tibco.controlPlaneInstanceId }}-tibco-sub-{{- .Values.subscriptionId -}}
  {{- end -}}
{{- end -}}

{{- define "tp-cp-subscription.container-registry.secret" }}{{ .Values.global.tibco.containerRegistry.secret }}{{end}}

{{- define "tp-cp-subscription.image.registry" }}
    {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-subscription.image.repository" -}}
    {{- .Values.global.tibco.containerRegistry.repository }}
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

{{/* Service CIDR for the cluster */}}
{{- define "tp-cp-subscription.serviceCIDR" }}
{{- .Values.global.external.clusterInfo.serviceCIDR }}
{{- end }}

{{- define "tp-cp-subscription.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}