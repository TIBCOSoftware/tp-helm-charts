{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-identity-management.consts.appName" }}tp-identity-management{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-identity-management.consts.component" }}cp{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-identity-management.consts.team" }}tp-cp{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-identity-management.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-identity-management.cic-env-configmap" }}cp-env{{ end -}}
{{- define "tp-identity-management.consts.cp-db-configuration" }}provider-cp-database-config{{ end -}}

{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/* Container registry for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* Control plane DNS domain. default value cp1 */}}
{{- define "cp-core-configuration.cp-dns-domain" }}
  {{- .Values.global.external.dnsDomain }}
{{- end }}

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

{{- define "identity-management.client-id-secret-key" }}
{{- if eq .Values.global.tibco.self_hosted_deployment true }}
    {{- "identity-management-client-id-secret-key" }}
{{- else }}
    {{- "tp-identity-management-idps-conf-override" }}
{{- end }}
{{- end }}

{{- define "identity-management-jwt-key-store-password" }}
{{- if eq .Values.global.tibco.self_hosted_deployment true }}
    {{- "identity-management-jwt-key-store-password" }}
{{- else }}
    {{- "tp-identity-management-idps-conf-override" }}
{{- end }}
{{- end }}

{{- define "identity-management-sp-key-store-password" }}
{{- if eq .Values.global.tibco.self_hosted_deployment true }}
    {{- "identity-management-sp-key-store-password" }}
{{- else }}
    {{- "tp-identity-management-idps-conf-override" }}
{{- end }}
{{- end }}

{{- define "identity-management-jwt-keystore-url" }}
{{- if eq .Values.global.tibco.self_hosted_deployment true }}
    {{- "identity-management-jwt-keystore-url" }}
{{- else }}
    {{- "tp-identity-management-idps-conf-override" }}
{{- end }}
{{- end }}
