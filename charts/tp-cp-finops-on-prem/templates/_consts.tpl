{{/*
   Copyright (c) 2024. Cloud Software Group, Inc. All Rights Reserved. Confidential & Proprietary.

   File       : _consts.tpl
   Version    : 1.0.0
   Description: Template helpers defining constants for this chart.

    NOTES: 
      - this file contains values that are specific only to this chart. Edit accordingly.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-finops.consts.appName" }}tp-cp-finops{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-finops.consts.component" }}cp{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-finops.consts.team" }}tp-finops{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-cp-finops.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{/* k8s service names of control-plane related microservice */}}
{{/* ... to be plugged into URLs for pod-to-pod requests */}}
{{- define "tp-cp-finops.consts.finopsMonitoringServiceName" }}tp-cp-monitoring-service.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.finopsServiceName" }}tp-cp-finops-service.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.finopsWebServiceName" }}tp-cp-finops-web-server.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.cpUserSubscriptionsServiceName" }}tp-cp-user-subscriptions.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.cpOrchestratorServiceName" }}tp-cp-orchestrator.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.monitorAgentHost" }}dp-%[1]s.{{ .Release.Namespace }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.hawkQueryNodeHost" }}querynode.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.finopsPrometheusHost" }}tp-cp-finops-prometheus.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.provisonerAgentHost" }}dp-%s.{{ .Release.Namespace }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-finops.consts.finopsOTelHost" }}otel-finops-cp-collector.{{ include "tp-cp-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}

{{- define "tp-cp-finops.tp-finops-env-configmap" }}tp-finops-env{{ end -}}

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
{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "cp-core-configuration.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
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
