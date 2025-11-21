{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
   Copyright (c) 2019-2023 Cloud Software Group, Inc.
   All Rights Reserved.

   File       : _helpers.tpl
   Version    : 1.0.0
   Description: Template helpers that can be shared with other charts.

    NOTES:
      - Helpers below are making some assumptions regarding files Chart.yaml and values.yaml. Change carefully!
      - Any change in this file needs to be synchronized with all charts
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "bw-webserver.consts.appName" }}tp-cp-bw-webserver{{ end -}}

{{- define "tp-cp-bw-mcpserver.consts.appName" }}tp-cp-bw-mcpserver{{ end -}}

{{/* A fixed short name for the configmap */}}
{{- define "bw-webserver.consts.configMapName" }}bw-webserver-configmap{{ end -}}

{{/* Component we're a part of. */}}
{{- define "bw-webserver.consts.component" }}cp{{ end -}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml
    ===========================================================================
*/}}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}
{{- define "bw-webserver.cp-env-configmap" }}cp-env{{ end -}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "bw-webserver.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "bw-webserver.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "bw-webserver.consts.appName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "bw-webserver.cp-instance-id" . }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "bw-webserver.shared.labels.standard" -}}
{{ include  "bw-webserver.shared.labels.selector" . }}
helm.sh/chart: {{ include "bw-webserver.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/*
    ===========================================================================
    SECTION: general purpose functions
    ===========================================================================
*/}}


{{- define "bw-webserver.image.registry" }}
    {{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw-webserver.bwce.image.repository" -}}
  {{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw-webserver.integration.image.repository" -}}
  {{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "bw-webserver.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "bw-webserver.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "bw-webserver.cp-instance-id" }}
  {{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "bw-webserver.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- default "" .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{/* Control plane OTEL service. default value otel-services */}}
{{- define "bw-webserver.cp-otel-services" }}
  {{- "o11y-service."}}{{ .Release.Namespace }}{{".svc.cluster.local" }}
{{- end }}

