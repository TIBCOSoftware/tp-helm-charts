{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "monitoring-service.consts.appName" }}tp-cp-monitoring-service{{ end -}}

{{- define "monitoring-service.consts.tenantName" }}finops{{ end -}}

{{- define "monitoring-service.consts.component" }}finops{{ end -}}

{{- define "monitoring-service.consts.team" }}tp-finops{{ end -}}

{{- define "monitoring-service.consts.namespace" }}{{ .Release.Namespace}}{{ end -}}
{{- define "monitoring-service.tp-env-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{- define "monitoring-service.tp-finops-dnsdomains-configmap" }}tp-cp-finops-dnsdomains{{ end -}}

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

{{- define "monitoring-service.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}
{{- define "monitoring-service.consts.http.monitorserverport" }}9831{{ end -}}
{{- define "monitoring-service.consts.http.serverport" }}7831{{ end -}}