{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
  This file is subject to the license terms contained
  in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. */}}
{{- define "mft-webserver.consts.appName" }}tp-cp-mft-webserver{{ end -}}

{{/* Component we're a part of. */}}
{{- define "mft-webserver.consts.component" }}cp{{ end -}}

{{/* CP core DNS-domains configmap (CP host endpoints injected by the platform). */}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "mft-webserver.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels used by the resources in this chart. Kept to stable identity
     labels only — Deployment/Service selectors are immutable, so value-injected
     labels (e.g. the CP owner) belong in the standard labels instead. */}}
{{- define "mft-webserver.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "mft-webserver.consts.appName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Standard labels added to all resources (includes selector labels). */}}
{{- define "mft-webserver.shared.labels.standard" -}}
{{ include "mft-webserver.shared.labels.selector" . }}
app.cloud.tibco.com/owner: {{ include "mft-webserver.cp-instance-id" . }}
helm.sh/chart: {{ include "mft-webserver.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "mft-webserver.image.registry" -}}
{{- default "" .Values.global.tibco.containerRegistry.url -}}
{{- end -}}

{{- define "mft-webserver.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository -}}
{{- end -}}

{{/* fluentbit image lives in the same repository as the app image. */}}
{{- define "mft-webserver.integration.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository -}}
{{- end -}}

{{/* Control plane OTEL collector service the fluentbit sidecar ships logs to. */}}
{{- define "mft-webserver.cp-otel-services" -}}
{{- "otel-services." }}{{ .Release.Namespace }}{{ ".svc.cluster.local" -}}
{{- end -}}

{{/* Image pull secret configured for the control plane. Default empty.
     PCP-9150: prefer an explicit override, then the platform-injected pre-existing secret
     name (global.tibco.containerRegistry.secret), else the conventional creds-derived secret. */}}
{{- define "mft-webserver.container-registry.secret" -}}
{{- if .Values.imagePullSecret -}}
{{- .Values.imagePullSecret -}}
{{- else -}}
{{- if .Values.global.tibco.containerRegistry.secret -}}
{{- .Values.global.tibco.containerRegistry.secret -}}
{{- else if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password -}}
{{- "tibco-container-registry-credentials" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Control plane instance id. */}}
{{- define "mft-webserver.cp-instance-id" -}}
{{- default "" .Values.global.tibco.controlPlaneInstanceId -}}
{{- end -}}

{{/* Service account configured for the control plane. */}}
{{- define "mft-webserver.service-account-name" -}}
{{- if .Values.serviceAccount -}}
{{- .Values.serviceAccount -}}
{{- else -}}
{{- default "" .Values.global.tibco.serviceAccount -}}
{{- end -}}
{{- end -}}

