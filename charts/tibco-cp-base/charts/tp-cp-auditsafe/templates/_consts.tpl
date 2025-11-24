{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-auditsafe-web-server.consts.appName" }}tp-cp-auditsafe{{ end -}}

{{/* A fixed short name for the configmap */}}
{{- define "tp-cp-auditsafe-web-server.consts.configMapName" }}tp-cp-auditsafe-web-server-configmap{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-auditsafe-web-server.consts.component" }}tcta{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-auditsafe-web-server.consts.team" }}cic-tcta{{ end -}}

{{- define "tp-cp-auditsafe-web-server.cic-env-configmap" }}cic-env{{ end -}}

{{- define "tp-cp-auditsafe-env-configmap" }}tp-cp-auditsafe-env{{ end -}}

{{- define "tp-cp-auditsafe-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}


{{- define "tp-cp-auditsafe.consts.appName" }}tp-cp-auditsafe{{ end -}}

{{- define "tp-cp-auditsafe.consts.component" }}cp{{ end -}}

{{- define "tp-cp-auditsafe.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-auditsafe.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-cp-core.consts.cp.db.configuration" }}provider-cp-database-config{{ end -}}

{{- define "tp-cp-auditsafe-configuration.container-registry" }}
   {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-auditsafe-configuration.image-repository" -}}
  {{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "tp-cp-auditsafe-configuration.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- if empty .Values.global.tibco.serviceAccount -}}
    {{- "control-plane-sa" }}
  {{- else -}}
    {{- .Values.global.tibco.serviceAccount | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-cp-auditsafe-configuration.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-auditsafe-configuration.cp-instance-id" }}
  {{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Control plane OTEL service. default value otel-services */}}
{{- define "tp-cp-auditsafe-configuration.otel.services" -}}
   {{- "otel-services."}}{{ .Release.Namespace }}{{".svc.cluster.local" }}
{{- end }}

{{- define "tp-cp-auditsafe-configuration.cp-dp-url" -}}
  {{- if (include "tp-cp-auditsafe-configuration.isSingleNamespace" .) }}
    {{- "dp-%s."}}{{ .Release.Namespace }}{{".svc.cluster.local" -}}
  {{- else }}
    {{- "dp-%s."}}{{include "tp-cp-auditsafe-configuration.cp-instance-id" .}}{{"-tibco-sub-%s.svc.cluster.local" -}}
  {{- end -}}
{{ end -}}

{{- define "tp-cp-auditsafe-configuration.isSingleNamespace" }}
  {{- $isSubscriptionSingleNamespace := "" -}}
    {{- if .Values.global.tibco.useSingleNamespace -}}
        {{- $isSubscriptionSingleNamespace = "1" -}}
    {{- end -}}
  {{ $isSubscriptionSingleNamespace }}
{{- end }}

{{- define "tp-cp-auditsafe-configuration.CPCustomerEnv" }}
  {{- $isCPCustomerEnv := "false" -}}
    {{- if .Values.global.tibco.useSingleNamespace  -}}
        {{- $isCPCustomerEnv = "true" -}}
    {{- end -}}
  {{ $isCPCustomerEnv }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-auditsafe-configuration.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-cp-auditsafe-configuration.enableResourceConstraints" -}}
{{- default "false" .Values.global.tibco.enableResourceConstraints | quote }}
{{- end }}

