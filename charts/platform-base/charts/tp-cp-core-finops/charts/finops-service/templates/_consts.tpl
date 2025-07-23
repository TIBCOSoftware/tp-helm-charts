{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "finops-service.consts.appName" }}tp-cp-finops-service{{ end -}}

{{/* Tenant name. */}}
{{- define "finops-service.consts.tenantName" }}finops{{ end -}}

{{/* Component we're a part of. */}}
{{- define "finops-service.consts.component" }}finops{{ end -}}

{{/* Team we're a part of. */}}
{{- define "finops-service.consts.team" }}tp-finops{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "finops-service.consts.namespace" }}{{ .Release.Namespace}}{{ end -}}
{{- define "finops-service.tp-env-configmap" }}tp-cp-core-dnsdomains{{ end -}}
{{- define "finops-service.tp-finops-dnsdomains-configmap" }}tp-cp-finops-dnsdomains{{ end -}}

{{- define "cp-core-configuration.cp-instance-id" }}
  {{- .Values.global.tibco.controlPlaneInstanceId | default "cp1" }}
{{- end }}

{{- define "cp-core-configuration.pvc-name" }}
  {{- .Values.global.external.storage.pvcName | default "control-plane-pvc" }}
{{- end }}

{{- define "cp-core-configuration.enableLogging" }}
  {{- $isEnableLogging := "" -}}
    {{- if ( .Values.global.tibco.logging.fluentbit.enabled )  -}}
        {{- $isEnableLogging = "1" -}}
    {{- end -}}
  {{ $isEnableLogging }}
{{- end }}

{{- define "finops-service.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}
{{- define "finops-service.consts.http.monitorserverport" }}9831{{ end -}}
{{- define "finops-service.consts.http.serverport" }}7831{{ end -}}