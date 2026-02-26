{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-orchestrator.consts.appName" }}tp-cp-orchestrator{{ end -}}

{{- define "tp-cp-orchestrator.consts.component" }}cp{{ end -}}

{{- define "tp-cp-orchestrator.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-orchestrator.consts.namespace" }}{{ .Release.Namespace}}{{ end -}}

{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}


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

{{- define "tp-cp-orchestrator.consts.http.port" }}7833{{ end -}}
{{- define "tp-cp-orchestrator.consts.management.http.port" }}8833{{ end -}}
{{- define "tp-cp-orchestrator.consts.monitor.http.port" }}9833{{ end -}}
{{- define "tp-cp-orchestrator.consts.published.http.port" }}10833{{ end -}}

{{- define "tp-cp-orchestrator.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}

{{- define "tp-cp-orchestrator.consts.enableHybridConnectivity" }}
  {{- .Values.global.tibco.hybridConnectivity.enabled -}}
{{- end }}

{{- define "cp-core-configuration.isSingleNamespace" }}
  {{- .Values.global.tibco.useSingleNamespace | quote -}}
{{- end }}

{{- define "cp-core-configuration.container-registry-image-pull-secret-name" }}tibco-container-registry-credentials{{ end }}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-email-service.consts.appName" }}tp-cp-email-service{{ end -}}
{{/* Namespace we're going into. */}}
{{- define "tp-cp-email-service.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-email-service.consts.component" }}cp{{ end -}}
{{/* Team we're a part of. */}}
{{- define "tp-cp-email-service.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-email-service.consts.emailServerConfig" -}}
  {{- $emailServerConfig := "" }}
  {{- $emailServerType := .Values.global.external.emailServerType -}}
  {{- if $emailServerType }}
    {{- $emailServerConfig = get .Values.global.external.emailServer $emailServerType | toJson }}
  {{- end }}
  {{ $emailServerConfig }}
{{- end -}}

{{- define "cp-core-configuration.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
   {{- "control-plane-sa" }}
{{- else -}}
   {{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}
