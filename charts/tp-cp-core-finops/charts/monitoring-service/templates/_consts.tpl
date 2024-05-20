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

{{- define "cp-core-configuration.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.provider-name" }}
{{- if .Values.providerName }}
  {{- .Values.providerName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

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

{{- define "monitoring-service.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}
{{- define "monitoring-service.consts.http.monitorserverport" }}9831{{ end -}}
{{- define "monitoring-service.consts.http.serverport" }}7831{{ end -}}