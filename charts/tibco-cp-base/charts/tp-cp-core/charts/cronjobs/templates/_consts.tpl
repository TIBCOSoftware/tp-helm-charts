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

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" -}}
{{- "tibco-container-registry-credentials" }}
{{- end }}

{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository }}
{{- end -}}


{{- define "cp-core-configuration.cp-is-single-namespace" }}
{{- if .Values.global.tibco.controlPlaneIsSingleNamespace }}
  {{- .Values.global.tibco.controlPlaneIsSingleNamespace | quote }}
{{- else }}
  false
{{- end }}
{{- end }}

{{- define "cp-core-configuration.cp-dns-domain" }}
  {{- .Values.global.external.dnsDomain }}
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

{{- define "tp-cp-cronjobs.consts.tscSchedulerPort" }}9601{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscSchedulerMonitorPort" }}9602{{ end -}}

{{- define "tp-cp-cronjobs.consts.tscSchedulerTroposphereLogLevel" }}debug{{ end -}}
{{- define "tp-cp-cronjobs.consts.maxRetryCountForResetClient" }}3{{ end -}}
{{- define "tp-cp-cronjobs.consts.timeToScheduleJobsAt" }}0 00 04 * * *{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscConfigurationLocationScheduler" }}file:///tmp/private/tsc/config/tp-cp-cronjobs/cpcronjobsapi.json{{ end -}}
{{- define "tp-cp-cronjobs.consts.disableConfigurationRefresh" }}false{{ end -}}

{{- define "tp-cp-cronjobs.consts.psqlMaxOpenConnections" }}100{{ end -}}
{{- define "tp-cp-cronjobs.consts.psqlMaxIdleConnections" }}100{{ end -}}

{{- define "tp-cp-cronjobs.consts.tscConfigLocation" }}/tmp/private/tsc{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscConfigLocationCommon" }}file:///tmp/private/tsc/config/common/tsc-config.json{{ end -}}

{{- define "tp-cp-cronjobs.consts.cpDbConfiguration"}}provider-cp-database-config{{ end -}}
