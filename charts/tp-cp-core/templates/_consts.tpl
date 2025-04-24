{{/*
 Copyright © 2024. Cloud Software Group, Inc.
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
{{- define "tpcontrol-plane.consts.tpCpO11yServiceName" }}o11y-service.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.provisionerAgentURLFramework" -}}
    {{- if (include "cp-core-configuration.isSingleNamespace" .) }}
        {{- "dp-%s." }}{{ .Release.Namespace }}{{ ".svc.cluster.local" -}}
    {{- else }}
        {{- "dp-%s." }}{{include "cp-core-configuration.cp-instance-id" .}}{{ "-tibco-sub-%s.svc.cluster.local" -}}
    {{- end -}}
{{ end -}}
{{- define "tpcontrol-plane.consts.computeServiceName" }}compute-services.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.cpQueryNodeServiceName" -}}
    {{- if (include "cp-core-configuration.isSingleNamespace" .) }}
        {{- "querynode."}}{{ include "tp-control-plane.consts.namespace" . }}{{ ".svc.cluster.local" -}}
    {{- else }}
        {{- "querynode."}}{{include "cp-core-configuration.cp-instance-id" .}}{{ "-tibco-cp.svc.cluster.local" -}}
    {{- end -}}
{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBWServiceName" }}tp-cp-bw-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBW5ServiceName" }}tp-cp-bw5-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBW6ServiceName" }}tp-cp-bw6-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpFLOGOServiceName" }}tp-cp-flogo-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.tpCpBEServiceName" }}tp-cp-be-webserver.{{ include "tp-control-plane.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tpcontrol-plane.consts.docBaseUrl" }}https://docs.tibco.com/go/platform-cp/1.6.0/doc/html{{ end -}}

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

{{- define "cp-core-configuration.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.cp-dns-domain" }}
  {{- include "cp-env.get" (dict "key" "CP_DNS_DOMAIN" "default" "cp1" "required" "false"  "Release" .Release )}}
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
    {{- if eq "true" (include "cp-env.get" (dict "key" "CP_LOGGING_FLUENTBIT_ENABLED" "default" "true" "required" "false"  "Release" .Release )) -}}
        {{- $isEnableLogging = "1" -}}
    {{- end -}}
  {{ $isEnableLogging }}
{{- end }}


{{- define "cp-core-configuration.isSingleNamespace" }}
  {{- $isSubscriptionSingleNamespace := "" -}}
    {{- if eq "true" (include "cp-env.get" (dict "key" "CP_SUBSCRIPTION_SINGLE_NAMESPACE" "default" "true" "required" "false"  "Release" .Release )) -}}
        {{- $isSubscriptionSingleNamespace = "1" -}}
    {{- end -}}
  {{ $isSubscriptionSingleNamespace }}
{{- end }}

{{- define "tp-cp-core.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_REPO" "default" "tibco-platform-docker-prod" "required" "false" "Release" .Release )}}
{{- end -}}
