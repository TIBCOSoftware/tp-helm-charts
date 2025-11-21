{{/*
Copyright © 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "tp-hawk-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tp-hawk-infra.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-hawk-infra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tp-hawk-infra.labels" -}}
helm.sh/chart: {{ include "tp-hawk-infra.chart" . }}
{{ include "tp-hawk-infra.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-hawk-infra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-hawk-infra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "hawk.cp.global" -}}
CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME: {{ "tibco-container-registry-credentials" }}
CP_CONTAINER_REGISTRY_REPO: {{ dig "Values" "global" "tibco" "containerRegistry" "repository" "tibco-platform-docker-prod" . }}
CP_CONTAINER_REGISTRY: {{ dig "Values" "global" "tibco" "containerRegistry" "url" "csgprdusw2reposaas.jfrog.io" . }}
CP_DNS_DOMAIN: {{ dig "Values" "global" "external" "dnsDomain" "local" . }}
CP_INSTANCE_ID: {{ dig "Values" "global" "tibco" "controlPlaneInstanceId" "cp1" . }}
CP_OTEL_SERVICE: {{ printf "otel-services.%s.svc.cluster.local" .Release.Namespace | quote }}
CP_PROVIDER: {{ "local" }}
CP_PVC_NAME: {{ dig "Values" "global" "external" "storage" "pvcName" "control-plane-pvc" . | default "control-plane-pvc" }}
CP_SERVICE_ACCOUNT_NAME: {{ dig "Values" "global" "tibco" "serviceAccount" "control-plane-sa" . }}
CP_SUBSCRIPTION_SINGLE_NAMESPACE: {{ .Values.global.tibco.useSingleNamespace | default "true" |  quote }}
{{- end -}}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "tp-hawk-infra.service-account-name" }}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- printf "%s" $hawkCP.CP_SERVICE_ACCOUNT_NAME -}}
{{- end }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-hawk-infra.pvc-name" }}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
  {{- printf "%s" $hawkCP.CP_PVC_NAME -}}
{{- end }}
{{- end }}

{{- define "tp-hawk-infra.image.registry" }}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
  {{- printf "%s" $hawkCP.CP_CONTAINER_REGISTRY -}}
{{- end }}


{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-hawk-infra.container-registry.secret" }}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
  {{- printf "%s" $hawkCP.CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME -}}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-hawk-infra.cp-instance-id" }}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
    {{- printf "%s" $hawkCP.CP_INSTANCE_ID -}}
{{- end }}

{{/* Control plane dns domain. default value local */}}
{{- define "tp-hawk-infra.dns-domain" -}}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
  {{- printf "%s" $hawkCP.CP_DNS_DOMAIN -}}
{{- end }}

{{/* Control plane provider */}}
{{- define "tp-hawk-infra.cp-provider" -}}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
  {{- printf "%s" $hawkCP.CP_PROVIDER -}}
{{- end }}

{{/* Control plane OTEl service */}}
{{- define "tp-hawk-infra.otelServiceName" -}}
{{- $hawkCP := include "hawk.cp.global" ( toJson . | fromJson ) | fromYaml -}}
  {{- printf "%s" $hawkCP.CP_OTEL_SERVICE -}}
{{- end }}

{{- define "tp-hawk-infra.randomSuffix" -}}{{ .Values.randomSuffix | default (randAlphaNum 4 | lower ) }}{{- end }}
