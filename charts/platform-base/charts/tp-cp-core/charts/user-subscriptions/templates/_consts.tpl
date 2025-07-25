{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-user-subscriptions.consts.appName" }}tp-cp-user-subscriptions{{ end -}}

{{- define "tp-cp-user-subscriptions.consts.component" }}cp{{ end -}}

{{- define "tp-cp-user-subscriptions.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-user-subscriptions.consts.namespace" }}{{ .Release.Namespace}}{{ end -}}

{{- define "tp-cp-user-subscriptions.cic-env-configmap" }}cp-env{{ end -}}
{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{- define "cp-core-bootstrap.otel.services" -}}
{{- "otel-services" }}
{{- end }}

{{- define "cp-core-configuration.enableLogging" }}
  {{- $isEnableLogging := "" -}}
    {{- if ( .Values.global.tibco.logging.fluentbit.enabled )  -}}
        {{- $isEnableLogging = "1" -}}
    {{- end -}}
  {{ $isEnableLogging }}
{{- end }}

{{- define "tp-cp-user-subscriptions.consts.http.port" }}7832{{ end -}}
{{- define "tp-cp-user-subscriptions.consts.management.http.port" }}8832{{ end -}}
{{- define "tp-cp-user-subscriptions.consts.monitor.http.port" }}9832{{ end -}}
{{- define "tp-cp-user-subscriptions.consts.published.http.port" }}10833{{ end -}}
{{- define "tp-cp-user-subscriptions.consts.automation.http.port" }}6832{{ end -}}

{{- define "tp-cp-user-subscriptions.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}