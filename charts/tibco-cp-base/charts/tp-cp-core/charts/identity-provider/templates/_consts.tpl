{{/* 
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-identity-provider.consts.appName" }}tp-cp-identity-provider{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-identity-provider.consts.component" }}cp{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-identity-provider.consts.team" }}tp-cp{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-cp-identity-provider.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-cp-identity-provider.consts.cp-db-configuration" }}provider-cp-database-config{{ end -}}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}
{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}

{{/* Container registry for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

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