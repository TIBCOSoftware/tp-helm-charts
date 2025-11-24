{{/*
   Copyright © 2024-2025. Cloud Software Group, Inc.
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
{{- define "tp-cp-core-finops.consts.finopsPrometheusHost" }}prometheus-service.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.provisonerAgentHost" }}dp-%s.{{ .Release.Namespace }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.finopsOTelHost" }}otel-finops-cp-collector.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.beWebServer" }}tp-cp-be-webserver.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.bw5WebServer" }}tp-cp-bw5-webserver.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}
{{- define "tp-cp-core-finops.consts.bw6WebServer" }}tp-cp-bw6-webserver.{{ include "tp-cp-core-finops.consts.namespace" . }}.svc.cluster.local{{ end -}}


{{/* Control plane instance Id. default value local */}}
{{- define "cp-core-configuration.cp-instance-id" }}
  {{- .Values.global.tibco.controlPlaneInstanceId | default "cp1" }}
{{- end }}
{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "cp-core-configuration.service-account-name" }}
{{- .Values.global.tibco.serviceAccount | default "control-plane-sa" }}
{{- end }}
{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "cp-core-configuration.pvc-name" }}
{{- .Values.global.external.storage.pvcName | default "control-plane-pvc" }}
{{- end }}
{{/* Container registry for control plane. default value empty */}}

{{- define "cp-core-configuration.container-registry" }}
{{- .Values.global.tibco.containerRegistry.url | default "csgprdusw2reposaas.jfrog.io" }}
{{- end }}

{{- define "cp-core-configuration.isSingleNamespace" }}
{{- if eq .Values.global.tibco.useSingleNamespace true -}}1{{- end }}
{{- end }}

{{- define "tp-cp-core-finops.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}