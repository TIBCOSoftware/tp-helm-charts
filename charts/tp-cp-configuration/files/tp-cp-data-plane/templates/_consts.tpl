{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}


{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-data-plane.consts.appName" }}data-plane-{{ .Values.dataPlaneId }}{{ end -}}

{{- define "tp-cp-data-plane.consts.subscriptionAppName" }}
  {{- if .Values.global.tibco.useSingleNamespace }}
    {{- "hybrid-server" -}}-{{- .Values.subscriptionId -}}
  {{- else }}
    {{- "hybrid-server" -}}
  {{- end -}}
{{- end -}}

{{- define "tp-cp-data-plane.consts.tenantName" }}tp-control-plane{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-data-plane.consts.component" }}resource-set{{ end -}}


{{/* Team we're a part of. */}}
{{- define "tp-cp-data-plane.consts.team" }}cic-compute{{ end -}}

{{- define "tp-cp-data-plane.consts.namespace" -}}
  {{- if .Values.global.tibco.useSingleNamespace }}
    {{- .Release.Namespace }}
  {{- else }}
    {{- .Values.global.tibco.controlPlaneInstanceId }}-tibco-sub-{{- .Values.subscriptionId -}}
  {{- end -}}
{{- end -}}