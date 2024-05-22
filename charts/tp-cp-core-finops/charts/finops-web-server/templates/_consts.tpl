{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "finops-web-server.consts.appName" }}tp-cp-finops-web-server{{ end -}}

{{/* A fixed short name for the configmap */}}
{{- define "finops-web-server.consts.configMapName" }}finops-web-server-configmap{{ end -}}

{{/* Component we're a part of. */}}
{{- define "finops-web-server.consts.component" }}finops{{ end -}}

{{/* Team we're a part of. */}}
{{- define "finops-web-server.consts.team" }}tp-finops{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "finops-web-server.consts.namespace" }}{{ .Release.Namespace}}{{ end -}}

{{- define "finops-web-server.tp-control-plane-dnsdomains" }}tp-cp-core-dnsdomains{{ end -}}
{{- define "finops-web-server.tp-finops-dnsdomains-configmap" }}tp-cp-finops-dnsdomains{{ end -}}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}
{{/* Get control plane environment configuration value from a key. key = key name in configmap, default = If key not found or configmap does not exist then the return default  */}}
{{/* required = if this key is mandatory or not, Release = get cm namespace from inbuilt .Release object */}}
{{/* usage =  include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "true"  "Release" .Release )  */}}
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
{{/* Control plane instance Id. default value local */}}
{{- define "cp-core-configuration.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}
{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}
{{/* Provider name for control plane. Fail if the pvc not exist */}}
{{- define "cp-core-configuration.provider-name" }}
{{- if .Values.providerName }}
  {{- .Values.providerName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}
{{/* Container registry for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.enableLogging" }}
  {{- $isEnableLogging := "" -}}
    {{- if eq "true" (include "cp-env.get" (dict "key" "CP_LOGGING_FLUENTBIT_ENABLED" "default" "true" "required" "false"  "Release" .Release )) -}}
        {{- $isEnableLogging = "1" -}}
    {{- end -}}
  {{ $isEnableLogging }}
{{- end }}