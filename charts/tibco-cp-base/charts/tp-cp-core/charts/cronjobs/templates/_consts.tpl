{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
  This file is subject to the license terms contained
  in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-cronjobs.consts.appName" }}tp-cp-cronjobs{{ end -}}

{{- define "tp-cp-cronjobs.consts.component" }}cp{{ end -}}

{{- define "tp-cp-cronjobs.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-cronjobs.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-cp-cronjobs.consts.enableHybridConnectivity" }}
  {{- .Values.global.tibco.hybridConnectivity.enabled -}}
{{- end }}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" -}}
{{- if .Values.global.tibco.containerRegistry.secret -}}
{{- .Values.global.tibco.containerRegistry.secret -}}
{{- else if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password -}}
{{- "tibco-container-registry-credentials" -}}
{{- end -}}
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

{{- define "tp-cp-cronjobs.consts.tscSchedulerTroposphereLogLevel" }}info{{ end -}}
{{- define "tp-cp-cronjobs.consts.maxRetryCountForResetClient" }}3{{ end -}}
{{- define "tp-cp-cronjobs.consts.timeToScheduleJobsAt" }}0 00 04 * * *{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscConfigurationLocationScheduler" }}file:///tmp/private/tsc/config/tp-cp-cronjobs/cpcronjobsapi.json{{ end -}}
{{- define "tp-cp-cronjobs.consts.disableConfigurationRefresh" }}false{{ end -}}

{{/*
  PCP-19871 (orch-mon merge): 30 -> 45 open, 7 -> 12 idle.

  cp-cronjobs took on two pieces of the decommissioned monitoring-service's work as DIRECT SQL,
  not through UTM: RefreshPrometheusHealth writes the capability and resource colours every
  minute, and RefreshResourceStatus grades the bare-metal domains and BW6 agents and writes both
  buckets in one transaction. Neither existed when 30/7 was set.

  The rest of monitoring's 150/35 went to user-subscriptions, which serves the orchestrator's
  monitoring traffic over UTM (see tp-cp-core/files/common.yaml). The orchestrator itself is
  unchanged at 30/7 — it gained HTTP clients, not database connections. 375 total after the merge
  against 410 before it.
*/}}
{{- define "tp-cp-cronjobs.consts.psqlMaxOpenConnections" }}45{{ end -}}
{{- define "tp-cp-cronjobs.consts.psqlMaxIdleConnections" }}12{{ end -}}

{{- define "tp-cp-cronjobs.consts.tscConfigLocation" }}/tmp/private/tsc{{ end -}}
{{- define "tp-cp-cronjobs.consts.tscConfigLocationCommon" }}file:///tmp/private/tsc/config/common/tsc-config.json{{ end -}}

{{- define "tp-cp-cronjobs.consts.cpDbConfiguration"}}provider-cp-database-config{{ end -}}
