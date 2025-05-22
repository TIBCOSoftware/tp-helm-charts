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

{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{- define "cp-env.get" }}
{{- $cm := ((include "cp-env" .)| fromYaml) }}
{{- if $cm }} {{- /* configmap exists */ -}}
  {{- if (hasKey $cm "data") }}
    {{- if (hasKey $cm.data .key) }}
      {{- $val := (get $cm.data .key) }}
      {{- $val }}
    {{- else -}} {{- /* key does not exists */ -}}
       {{- if eq .required "true" }}{{ fail (printf "%s missing key in configmap cp-env" .key)}}{{ else }}{{ .default }}{{ end }}
    {{- end -}}
  {{- else -}}{{- /* data key does not exists */ -}}
    {{- if eq .required "true" }}{{ fail (printf "data key missing in configmap cp-env")}}{{ else }}{{ .default }}{{ end }}
  {{- end }}
{{- else }} {{- /* configmap does not exists */ -}}
    {{- if eq .required "true" }}{{ fail (printf "missing configmap cp-env")}}{{ else }}{{ .default }}{{ end }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "local" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-bootstrap.otel.services" -}}
{{- "otel-services" }}
{{- end }}

{{- define "cp-core-configuration.enableLogging" }}
  {{- $isEnableLogging := "" -}}
    {{- if eq "true" (include "cp-env.get" (dict "key" "CP_LOGGING_FLUENTBIT_ENABLED" "default" "true" "required" "false"  "Release" .Release )) -}}
        {{- $isEnableLogging = "1" -}}
    {{- end -}}
  {{ $isEnableLogging }}
{{- end }}

{{- define "tp-cp-orchestrator.consts.http.port" }}7833{{ end -}}
{{- define "tp-cp-orchestrator.consts.management.http.port" }}8833{{ end -}}
{{- define "tp-cp-orchestrator.consts.monitor.http.port" }}9833{{ end -}}
{{- define "tp-cp-orchestrator.consts.published.http.port" }}10833{{ end -}}

{{- define "tp-cp-orchestrator.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}

{{- define "cp-core-configuration.isSingleNamespace" }}
  {{- include "cp-env.get" (dict "key" "CP_SUBSCRIPTION_SINGLE_NAMESPACE" "default" "true" "required" "false"  "Release" .Release ) -}}
{{- end }}

{{- define "cp-core-configuration.container-registry-image-pull-secret-name" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release ) -}}
{{- end }}

{{- define "cp-core-configuration.cp-container-registry-username" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_USERNAME" "default" "" "required" "false"  "Release" .Release ) -}}
{{- end }}

{{- define "cp-core-configuration.cp-container-registry-password" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_PASSWORD" "default" "" "required" "false"  "Release" .Release ) -}}
{{- end }}

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
  {{- if eq $emailServerType "graph" }}
    {{- $secret := lookup "v1" "Secret" .Release.Namespace .Values.global.external.emailServer.graph.clientDetailsSecretName -}}
    {{- if not (and $secret (hasKey $secret.data .Values.global.external.emailServer.graph.clientDetailsSecretKey)) }}
      {{- fail (printf "Secret or key missing, required for email server 'graph' configuration: Secret Name: %s, Key: %s" .Values.global.external.emailServer.graph.clientDetailsSecretName .Values.global.external.emailServer.graph.clientDetailsSecretKey) -}}
    {{- else }}
      {{- printf "Secret found: Secret Name: %s, Key: %s" .Values.global.external.emailServer.graph.clientDetailsSecretName .Values.global.external.emailServer.graph.clientDetailsSecretKey -}}
    {{- end }}
  {{- else if $emailServerType }}
    {{- $emailServerConfig = get .Values.global.external.emailServer $emailServerType | toJson }}
  {{- else }}
    {{- $emailServerConfig = get .Values.global.external.emailServer "smtp" | toJson }}
  {{- end }}
  {{ $emailServerConfig }}
{{- end -}}

{{- define "cp-core-configuration.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}
