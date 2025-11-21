{{/*
 Copyright © 2025. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{- define "tp-control-plane.consts.appName" }}tp-cp-core{{ end -}}

{{- define "tp-control-plane.consts.component" }}cp{{ end -}}

{{- define "tp-control-plane.consts.team" }}tp-cp{{ end -}}

{{- define "tp-control-plane.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tpcontrol-plane.consts.cpAdminWebServiceName" }}tp-cp-admin-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpWebServiceName" }}tp-cp-web-server.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpOrchServiceName" }}tp-cp-orchestrator.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpUserSubServiceName" }}tp-cp-user-subscriptions.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpEmailServiceName" }}tp-cp-email-service.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpCronJobServiceName" }}tp-cp-cronjobs.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpIdmServiceName" }}tp-identity-management.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpIdpJobServiceName" }}tp-cp-identity-provider.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpPermissionEngineServiceName" }}tp-cp-pengine.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpMonitoringServiceName" }}tp-cp-monitoring-service.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpAlertServiceName" }}alerts-service.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpO11yServiceName" }}o11y-service.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.provisionerAgentURLFramework" -}}
    {{- if (include "cp-core-configuration.isSingleNamespace" .) }}
        {{- "dp-%s." }}{{ .Release.Namespace }}{{ ".svc.cluster.local" -}}
    {{- else }}
        {{- "dp-%s." }}{{ .Values.global.tibco.controlPlaneInstanceId }}{{ "-tibco-sub-%s.svc.cluster.local" -}}
    {{- end -}}
{{ end -}}
{{- define "tpcontrol-plane.consts.computeServiceName" }}compute-services.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpQueryNodeServiceName" }}querynode.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBWServiceName" }}tp-cp-bw-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBW5ServiceName" }}tp-cp-bw5-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBW5CEServiceName" }}tp-cp-bw5ce-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBW6ServiceName" }}tp-cp-bw6-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpFLOGOServiceName" }}tp-cp-flogo-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBEServiceName" }}tp-cp-be-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpEMSServiceName" }}msg-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.docBaseUrl" }}https://docs.tibco.com/go/platform-cp/1.13.0/doc/html{{ end -}}

{{- define "cp-core-configuration.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
   {{- "control-plane-sa" }}
{{- else -}}
   {{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{ end }}

{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}


{{- define "cp-core-configuration.cp-dns-domain" }}
  {{- .Values.global.external.dnsDomain }}
{{- end }}

{{- define "tp-control-plane.consts.env.simplified" -}}
  {{- if hasPrefix "prod" ( (.Values.global.external.environment | lower) ) -}}
    {{- "prod" -}}
  {{- else if eq "staging" ( (.Values.global.external.environment | lower) ) -}}
    {{- "staging" -}}
  {{- else if hasSuffix "qa" ( (.Values.global.external.environment | lower) ) -}}
    {{- "qa" -}}
  {{- else if eq "vagrant" ( (.Values.global.external.environment | lower) ) -}}
    {{- "local" -}}
  {{- else -}}
    {{- "dev" -}}
  {{- end }}
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


{{- define "cp-core-configuration.isSingleNamespace" }}
  {{- $isSubscriptionSingleNamespace := "" -}}
    {{- if eq "true" ( .Values.global.tibco.useSingleNamespace | quote) -}}
        {{- $isSubscriptionSingleNamespace = "1" -}}
    {{- end -}}
  {{ $isSubscriptionSingleNamespace }}
{{- end }}

{{- define "tp-cp-core.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}


{{- define "tp-control-plane-ops.consts.appName" }}tp-control-plane-ops{{ end -}}

{{- define "tp-control-plane-ops.consts.component" }}cp-ops{{ end -}}

{{- define "tp-control-plane-ops.consts.team" }}tp-cp{{ end -}}

{{- define "tp-control-plane-ops.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}
{{- define "tp-control-plane-ops.consts.cp-env-configmap" }}cp-env{{ end -}}
