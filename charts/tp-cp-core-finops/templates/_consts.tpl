{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-core-finops.consts.appName" }}tp-cp-finops{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-core-finops.consts.component" }}cp{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-core-finops.consts.team" }}tp-finops{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-cp-core-finops.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}
{{- define "tp-cp-core-finops.tp-env-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/* k8s service names of control-plane related microservice */}}
{{/* ... to be plugged into URLs for pod-to-pod requests */}}
{{- define "tp-cp-core-finops.consts.finopsMonitoringServiceName" }}tp-cp-monitoring-service.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.finopsServiceName" }}tp-cp-finops-service.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.finopsWebServiceName" }}tp-cp-finops-web-server.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.cpUserSubscriptionsServiceName" }}tp-cp-user-subscriptions.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.cpOrchestratorServiceName" }}tp-cp-orchestrator.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.monitorAgentHost" -}}
    {{- if (include "cp-core-configuration.isSingleNamespace" .) }}
        {{- "dp-%[1]s."}}{{ .Release.Namespace }}{{".svc.cluster.local" -}}
    {{- else }}
        {{- "dp-%s."}}{{include "cp-core-configuration.cp-instance-id" .}}{{"-tibco-sub-%s.svc.cluster.local" -}}
    {{- end -}}
{{ end -}}
{{- define "tp-cp-core-finops.consts.hawkQueryNodeHost" }}querynode.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.finopsPrometheusHost" }}tp-cp-finops-prometheus.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.provisonerAgentHost" }}dp-%s.{{ .Release.Namespace }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.finopsOTelHost" }}otel-finops-cp-collector.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.beWebServer" }}tp-cp-be-webserver.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.bw5WebServer" }}tp-cp-bw5-webserver.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.bw6WebServer" }}tp-cp-bw6-webserver.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}



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
{{/* Container registry for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.isSingleNamespace" }}
  {{- $isSubscriptionSingleNamespace := "" -}}
    {{- if eq "true" (include "cp-env.get" (dict "key" "CP_SUBSCRIPTION_SINGLE_NAMESPACE" "default" "true" "required" "false"  "Release" .Release )) -}}
        {{- $isSubscriptionSingleNamespace = "1" -}}
    {{- end -}}
  {{ $isSubscriptionSingleNamespace }}
{{- end }}

{{- define "tp-cp-core-finops.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}