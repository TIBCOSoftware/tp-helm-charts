{{/* 

Copyright © 2023 - 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}


{{/*
================================================================
                  SECTION COMMON VARS
================================================================   
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "tp-cp-configuration.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-configuration.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-configuration.component" -}}tp-cp-configuration{{- end }}

{{- define "tp-cp-configuration.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tp-cp-configuration.team" -}}
{{- "cic-compute" }}
{{- end }}


{{- define "tp-cp-configuration.compute-services.consts.appName" }}compute-services{{ end -}}

{{- define "tp-cp-configuration.hybrid-server.consts.appName" }}hybrid-server{{ end -}}

{{- define "tp-cp-configuration.control-tower.targetDir" }}/efs/control-tower{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{- define "tp-cp-configuration.image.registry" }}
  {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-configuration.image.repository" -}}
  {{- default "tibco-platform-docker-prod" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}


{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- end }}


{{/* Service account configured for control plane. */}}
{{- define "tp-cp-configuration.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
{{- "control-plane-sa" }}
{{- else -}}
{{- .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-configuration.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{- define "tp-cp-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* Control plane instance Id. default value cp1 */}}
{{- define "tp-cp-configuration.cp-instance-id" }}
{{- default "cp1" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Control plane dns domain. default value acme.example.com */}}
{{- define "tp-cp-configuration.dns-domain" -}}
{{- default "acme.example.com" .Values.global.external.dnsDomain }}
{{- end }}

{{/* Control plane dns top level domain */}}
{{- define "tp-cp-configuration.top-level-domain" -}}
{{- $domainTuples := (include "tp-cp-configuration.dns-domain" . | splitList ".") }}
{{- reverse $domainTuples | first -}}
{{- end }}

{{/* Control plane dns domain name */}}
{{- define "tp-cp-configuration.domain-name" -}}
{{- $domainTuples := (include "tp-cp-configuration.dns-domain" . | splitList "." | reverse) }}
{{- index $domainTuples 1 }}
{{- end }}

{{/* Control plane cookie domain */}}
{{- define "tp-cp-configuration.cookie-domain" -}}
{{- $domainTuples := (include "tp-cp-configuration.dns-domain" . | splitList ".") }}
{{- slice $domainTuples 2 | join "." }}
{{- end }}

{{/* Control plane create network policy */}}
{{- define "tp-cp-configuration.create-network-policy" -}}
{{- hasKey .Values.global.tibco "createNetworkPolicy" | ternary .Values.global.tibco.createNetworkPolicy false }}
{{- end }}

{{/* Control plane node CIDR */}}
{{- define "tp-cp-configuration.nodeCIDR" -}}
{{- default "" .Values.global.external.clusterInfo.nodeCIDR }}
{{- end }}

{{/* Control plane pod CIDR */}}
{{- define "tp-cp-configuration.podCIDR" -}}
{{- if .Values.global.tibco.createNetworkPolicy }}
  {{- if empty .Values.global.external.clusterInfo.podCIDR }}
    {{- default "" .Values.global.external.clusterInfo.nodeCIDR }}
  {{- else }}
    {{- .Values.global.external.clusterInfo.podCIDR }}
  {{- end }}
{{- else }}
  {{- "" }}
{{- end }}
{{- end }}

{{/* Control plane service CIDR */}}
{{- define "tp-cp-configuration.serviceCIDR" -}}
{{- default "" .Values.global.external.clusterInfo.serviceCIDR }}
{{- end }}

{{/* Control plane OTEl service */}}
{{- define "tp-cp-configuration.otelServiceName" -}}
{{- "otel-services" }}
{{- end }}

{{/* Control plane single namespace flag */}}
{{- define "tp-cp-configuration.useSingleNamespace" -}}
{{- hasKey .Values.global.tibco "useSingleNamespace" | ternary .Values.global.tibco.useSingleNamespace true }}
{{- end }}

{{/* Control plane enable or disable resource constraints */}}
{{- define "tp-cp-configuration.enableResourceConstraints" -}}
{{- hasKey .Values.global.tibco "enableResourceConstraints" | ternary .Values.global.tibco.enableResourceConstraints true }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tp-cp-configuration.labels" -}}
helm.sh/chart: {{ include "tp-cp-configuration.chart" . }}
{{ include "tp-cp-configuration.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-configuration.team" . }}
platform.tibco.com/component: {{ include "tp-cp-configuration.component" . }}
{{- end }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-configuration.cp-instance-id" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-configuration.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-configuration.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-configuration.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-configuration.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{- define "tp-cp-configuration.container-registry-username" -}}
{{- if .Values.global.tibco.containerRegistry.username }}
  {{- .Values.global.tibco.containerRegistry.username }}
{{- else }}
  {{- /* ignore as username not found*/}}
{{- end }}
{{- end }}
{{- define "tp-cp-configuration.container-registry-password" -}}
{{- if .Values.global.tibco.containerRegistry.password }}
  {{- .Values.global.tibco.containerRegistry.password }}
{{- else }}
  {{- /* ignore as password not found*/}}
{{- end }}
{{- end }}

{{/* Control plane logging fluentbit. default value true */}}
{{- define "tp-cp-configuration.cp-logging-fluentbit-enabled" }}
  {{- .Values.global.tibco.logging.fluentbit.enabled  }}
{{- end }}

