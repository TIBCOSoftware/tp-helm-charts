{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-cronjobs.consts.appName" }}tp-cp-cronjobs{{ end -}}

{{- define "tp-cp-cronjobs.consts.component" }}cp{{ end -}}

{{- define "tp-cp-cronjobs.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-cronjobs.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

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

{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{- define "cp-core-configuration.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}

{{- define "cp-core-configuration.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.provider-name" }}
{{- if .Values.providerName }}
  {{- .Values.providerName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.cp-dns-domain" }}
  {{- include "cp-env.get" (dict "key" "CP_DNS_DOMAIN" "default" "cp1" "required" "false"  "Release" .Release )}}
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

{{- define "tp-cp-cronjobs.consts.tscSchedulerPort" }}9601{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscSchedulerMonitorPort" }}9602{{ end -}}

{{- define "tp-cp-cronjobs.consts.tscSchedulerTroposphereLogLevel" }}debug{{ end -}}
{{- define "tp-cp-cronjobs.consts.maxRetryCountForResetClient" }}3{{ end -}}
{{- define "tp-cp-cronjobs.consts.timeToScheduleJobsAt" }}0 00 04 * * *{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscConfigurationLocationScheduler" }}file:///private/tsc/config/tp-cp-cronjobs/cpcronjobsapi.json{{ end -}}
{{- define "tp-cp-cronjobs.consts.disableConfigurationRefresh" }}false{{ end -}}

{{- define "tp-cp-cronjobs.consts.psqlMaxOpenConnections" }}100{{ end -}}
{{- define "tp-cp-cronjobs.consts.psqlMaxIdleConnections" }}100{{ end -}}

{{- define "tp-cp-cronjobs.consts.tscConfigLocation" }}/private/tsc{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscConfigLocationCommon" }}file:///private/tsc/config/common/tsc-config.json{{ end -}}

{{- define "tp-cp-cronjobs.consts.cpDbConfiguration"}}provider-cp-database-config{{ end -}}
