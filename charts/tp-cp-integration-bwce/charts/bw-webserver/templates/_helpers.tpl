{{/*
Copyright © 2023. Cloud Software Group, Inc.
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


{{- define "bw-webserver.consts.bwce.jfrogImageRepo" }}tibco-platform-local-docker/bwce{{end}}
{{- define "bw-webserver.consts.bwce.ecrImageRepo" }}piap{{end}}
{{- define "bw-webserver.consts.bwce.acrImageRepo" }}piap{{end}}
{{- define "bw-webserver.consts.bwce.harborImageRepo" }}piap{{end}}
{{- define "bw-webserver.consts.bwce.defaultImageRepo" }}tibco-platform-local-docker/bwce{{end}}

{{- define "bw-webserver.consts.integration.jfrogImageRepo" }}tibco-platform-local-docker/integration{{end}}
{{- define "bw-webserver.consts.integration.ecrImageRepo" }}piap{{end}}
{{- define "bw-webserver.consts.integration.acrImageRepo" }}piap{{end}}
{{- define "bw-webserver.consts.integration.harborImageRepo" }}piap{{end}}
{{- define "bw-webserver.consts.integration.defaultImageRepo" }}tibco-platform-local-docker/integration{{end}}


{{- define "bw-webserver.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "reldocker.tibco.com" "required" "false" "Release" .Release )}}
  {{- end }}
{{- end }}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw-webserver.bwce.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "bw-webserver.image.registry" .) }} 
    {{- include "bw-webserver.consts.bwce.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bw-webserver.image.registry" .) }}
    {{- include "bw-webserver.consts.bwce.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bw-webserver.image.registry" .) }}
    {{- include "bw-webserver.consts.bwce.harborImageRepo" .}}
  {{- else }}
    {{- include "bw-webserver.consts.bwce.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "bw-webserver.integration.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "bw-webserver.image.registry" .) }} 
    {{- include "bw-webserver.consts.integration.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "bw-webserver.image.registry" .) }}
    {{- include "bw-webserver.consts.integration.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "bw-webserver.image.registry" .) }}
    {{- include "bw-webserver.consts.integration.harborImageRepo" .}}
  {{- else }}
    {{- include "bw-webserver.consts.integration.defaultImageRepo" .}}
  {{- end }}
{{- end -}}



{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "bw-webserver.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "true"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "bw-webserver.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "bw-webserver.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane provider */}}
{{- define "bw-webserver.cp-provider" -}}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "aws" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "bw-webserver.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane logging fluentbit. default value true */}}
{{- define "bw-webserver.cp-logging-fluentbit-enabled" }}
  {{- include "cp-env.get" (dict "key" "CP_LOGGING_FLUENTBIT_ENABLED" "default" "true" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane OTEL service. default value otel-services */}}
{{- define "bw-webserver.cp-otel-services" }}
  {{- include "cp-env.get" (dict "key" "CP_OTEL_SERVICE" "default" "otel-services" "required" "false"  "Release" .Release )}}
{{- end }}


