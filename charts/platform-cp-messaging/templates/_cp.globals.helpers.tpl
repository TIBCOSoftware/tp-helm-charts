
{{/*
MSG CP Common Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{/* Map CP globals (per PCP-11815)
    spec doc: https://docs.google.com/document/d/18PG9WQXMxO6wJ40Xpa4Xe7K4eosRE0RatwlAV9isTXM/edit?usp=sharing
    call as: include "cp.values.global" (toJson . | fromJson) 
    caution: dig not working for boolean SUBSCRIPTION_SINGLE_NAMESPACE
*/}}
{{- define "cp.values.global" -}}
{{- if .Values.useCpEnv -}}
  {{/* use cp-env lookup functions to get CP values */}}
{{- include "cp.values.lookup" . | nindent 0 -}}
{{- else -}}
  {{/* use dig + .Values.global  lookup functions to get CP values */}}
cp:
  # OTEL_SERVICE:
  serviceAccount: {{ dig "Values" "global" "tibco" "serviceAccount" "" . }}
  pullSecret: {{ dig "Values" "global" "tibco" "containerRegistry" "imagePullSecretName" "" . }}
  registry: {{ dig "Values" "global" "tibco" "containerRegistry" "url" "" . }}
  repository: {{ dig "Values" "global" "tibco" "containerRegistry" "repository" "" . }}
  CP_VOLUME_CLAIM: {{ dig "Values" "global" "external" "storage" "pvcName" "" . }}
  SYSTEM_WHO: {{ dig "Values" "global" "tibco" "controlPlaneInstanceId" "" . }}
  DNS_DOMAIN: {{ dig "Values" "global" "external" "dnsDomain" "" . }}
  LOGGING_FLUENTBIT_ENABLED: {{ dig "Values" "global" "tibco" "logging" "fluentbit" "enabled" "" . }}
  SUBSCRIPTION_SINGLE_NAMESPACE: {{ .Values.global.tibco.useSingleNamespace | quote}}
{{- end -}}

{{- end  -}}

{{- define "cp.values.lookup" -}}
  {{/* use cp-env lookup functions to get CP values */}}
  {{- $envbase := printf "%s" "{\"data\":{\"xxbase\": \"xxx\"}}" | fromYaml -}}
  {{- $cpenv := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") -}}
  {{- $cicprivate := (lookup "v1" "ConfigMap" .Release.Namespace "cic-private-env") -}}
  {{- $cicenv := (lookup "v1" "ConfigMap" .Release.Namespace "cic-env") -}}
  {{- $cpmerge := merge $cpenv $cicprivate $cicenv $envbase -}}
cp:
  lookup: "now"
  serviceAccount: {{ $cpmerge.data.CP_SERVICE_ACCOUNT_NAME | default $cpmerge.data.CP_DEFAULT_SA | default "no-cic-sa" }}
  pullSecret: {{ $cpmerge.data.CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME | default "no-pullsecret" }}
  registry: {{ $cpmerge.data.CP_CONTAINER_REGISTRY | default $cpmerge.data.SYSTEM_DOCKER_REGISTRY | default "csgprdusw2reposaas.jfrog.io" }}
  repository: {{ $cpmerge.data.CP_CONTAINER_REGISTRY_REPO | default "" }}
  CP_VOLUME_CLAIM: {{ $cpmerge.data.CP_PVC_NAME | default $cpmerge.data.CP_VOLUME_CLAIM | default "control-plane-pvc" }}
  SYSTEM_WHO: {{ $cpmerge.data.CP_INSTANCE_ID | default $cpmerge.data.SYSTEM_WHO | default "who" }}
  DNS_DOMAIN: {{ $cpmerge.data.CP_DNS_DOMAIN | default "" }}
  LOGGING_FLUENTBIT_ENABLED: {{ $cpmerge.data.CP_LOGGING_FLUENTBIT_ENABLED | default false | quote }}
  SUBSCRIPTION_SINGLE_NAMESPACE: {{ $cpmerge.data.CP_SUBSCRIPTION_SINGLE_NAMESPACE | default true | quote }}
{{- end -}}
