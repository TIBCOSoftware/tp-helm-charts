
{{/*
MSG CP Common Helpers
#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}
{{- define "msgdp.ghcrImageRepo" -}}"tibco/msg-platform-cicd"{{ end }}
{{- define "msgdp.devImageRepo" -}}"tibco-platform-docker-dev"{{ end }}
{{- define "msgdp.prodImageRepo" -}}"tibco-platform-docker-prod"{{ end }}
{{- define "msgdp.reldockerImageRepo" -}}"tibco-platform"{{ end }}
{{- define "msgdp.defaultImageRepo" -}}"tibco-platform-docker-prod"{{ end }}
# Old Repos
{{- define "msgdp.jfrogImageRepoOld" -}}"tibco-platform-local-docker/msg"{{ end }}
{{- define "msgdp.ecrImageRepoOld" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.acrImageRepoOld" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.reldockerImageRepoOld" -}}"messaging"{{ end }}
{{- define "msgdp.defaultImageRepoOld" -}}"messaging"{{ end }}

{{- define "const.onprem.dnsdomains" -}}"tp-cp-core-dnsdomains"{{ end }}
{{- define "const.saas.dnsdomains" -}}"tp-control-plane-dnsdomains"{{ end }}

{{/* Does key exist in given cm? */}}
{{- define "env.check" }}
{{- $cm := ((include "cp-env" .)| fromYaml) }}
{{- if $cm }} {{- /* configmap exists */ -}}
  {{- if (hasKey $cm "data") }}
    {{- if (hasKey $cm.data .key) }}
      true
    {{- else -}}
      false
    {{- end -}}
  {{- else -}}
    false
  {{- end }}
{{- else }}
  false
{{- end }}
{{- end }}

{{/* cp-env taken from - https://confluence.tibco.com/x/NZ8IEw modified to take a cm argument as well */}}
{{/* Get control plane environment configuration value from a key. key = key name in configmap, default = If key not found or configmap does not exist then the return default  */}}
{{/* required = if this key is mandatory or not, Release = get cm namespace from inbuilt .Release object */}}
{{/* usage =  include "env.get" (dict cm "<whatever cm>" "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "true"  "Release" .Release )  */}}
{{- define "env.get" }}
{{- $cm := ((include "cp-env" .)| fromYaml) }}
{{- if $cm }} {{- /* configmap exists */ -}}
  {{- if (hasKey $cm "data") }}
    {{- if (hasKey $cm.data .key) }}
      {{- $val := (get $cm.data .key) }}
      {{- $val }}
    {{- else -}} {{- /* key does not exist */ -}}
       {{- if eq .required "true" }}{{ fail (printf "%s missing key in configmap %s" .key .cm)}}{{ else }}{{ .default }}{{ end }}
    {{- end -}}
  {{- else -}}{{- /* data key does not exist */ -}}
    {{- if eq .required "true" }}{{ fail (printf "data key missing in configmap %s" .cm)}}{{ else }}{{ .default }}{{ end }}
  {{- end }}
{{- else }} {{- /* configmap does not exist */ -}}
    {{- if eq .required "true" }}{{ fail (printf "missing configmap %s" .cm)}}{{ else }}{{ .default }}{{ end }}
{{- end }}
{{- end }}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace .cm) }}
{{- $data | toYaml }}
{{- end }}

{{/*
need.msg.cp.params
*/}}
{{ define "need.msg.cp.params" }}
  # DEFAULT SETTINGS
  {{- $registry := "csgprdusw2reposaas.jfrog.io" -}}
  {{- $repo := include "msgdp.defaultImageRepo" . -}}
  {{- $imageName := "msg-cp-ui-contrib" -}}
  {{- $imageTag := "1.3.0-14" -}}
  {{- $TARGET_PATH := "/private/tsc/config/capabilities/platform" -}}
  {{- $pullSecret := "" -}}
  {{- $pullPolicy := "Always" -}}
  {{- $enableWebserverSecurityContext := "true" -}}
  {{- $enableJobSecurityContext := "false" -}}
  {{- $CP_OTEL_SERVICE := "" -}}
  {{- $CP_LOGGING_FLUENTBIT_ENABLED := "false" -}}
  {{- $CP_SERVICE_ACCOUNT_NAME := "" -}}
  {{- $CP_SUBSCRIPTION_SINGLE_NAMESPACE := "false" -}}
  {{- $SYSTEM_WHO := "" -}}
  {{- $DNS_DOMAIN := "" -}}
  {{- $ADMIN_DNS_DOMAIN := "" -}}
  {{- $CP_VOLUME_CLAIM := "control-plane-pvc" -}}
  {{- $ENV_TYPE := "onprem" -}}
  # LEGACY SETTINGS
  {{- if .Values.data.SYSTEM_DOCKER_REGISTRY -}}
    {{- $registry = .Values.data.SYSTEM_DOCKER_REGISTRY -}}
  {{- end -}}

  {{- if (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") -}}
    # On-Prem Env
    {{- $ENV_TYPE = "onprem" -}}
    {{- $CP_DNS_DOMAIN := include "env.get" (dict "cm" "cp-env" "key" "CP_DNS_DOMAIN" "default" "" "required" "false" "Release" .Release) -}}
    {{- if ne $CP_DNS_DOMAIN "" }}
      {{- $DNS_DOMAIN = printf "*.%s" $CP_DNS_DOMAIN }}
      {{- $ADMIN_DNS_DOMAIN = printf "admin.%s" $CP_DNS_DOMAIN }}
    {{- end }}
    {{- $SYSTEM_WHO = include "env.get" (dict "cm" "cp-env" "key" "CP_INSTANCE_ID" "default" $SYSTEM_WHO "required" "false" "Release" .Release) -}}
    {{- $CP_LOGGING_FLUENTBIT_ENABLED = include "env.get" (dict "cm" "cp-env" "key" "CP_LOGGING_FLUENTBIT_ENABLED" "default" $CP_LOGGING_FLUENTBIT_ENABLED "required" "false" "Release" .Release) -}}
    {{- $CP_OTEL_SERVICE = include "env.get" (dict "cm" "cp-env" "key" "CP_OTEL_SERVICE" "default" $CP_OTEL_SERVICE "required" "false" "Release" .Release) -}}
    {{- $CP_VOLUME_CLAIM = include "env.get" (dict "cm" "cp-env" "key" "CP_PVC_NAME" "default" $CP_VOLUME_CLAIM "required" "false" "Release" .Release) -}}
    {{- $CP_SERVICE_ACCOUNT_NAME = include "env.get" (dict "cm" "cp-env" "key" "CP_SERVICE_ACCOUNT_NAME" "default" $CP_SERVICE_ACCOUNT_NAME "required" "false" "Release" .Release) -}}
    {{- $CP_SUBSCRIPTION_SINGLE_NAMESPACE = include "env.get" (dict "cm" "cp-env" "key" "CP_SUBSCRIPTION_SINGLE_NAMESPACE" "default" $CP_SUBSCRIPTION_SINGLE_NAMESPACE "required" "false" "Release" .Release) -}}
  {{- else if (lookup "v1" "ConfigMap" .Release.Namespace "cic-env") -}}
    # SaaS Env
    {{- $ENV_TYPE = "saas" -}}
    {{- $DNS_DOMAIN = include "env.get" (dict "cm" "cic-env" "key" "CP_SUB_DNS_DOMAIN" "default" $DNS_DOMAIN "required" "false" "Release" .Release) -}}
    {{- $ADMIN_DNS_DOMAIN = include "env.get" (dict "cm" "cic-env" "key" "CP_ADMIN_DNS_DOMAIN" "default" $ADMIN_DNS_DOMAIN "required" "false" "Release" .Release) -}}
    {{- $SYSTEM_WHO = include "env.get" (dict "cm" "cic-env" "key" "SYSTEM_WHO" "default" $SYSTEM_WHO "required" "false" "Release" .Release) -}}
    {{- if (lookup "v1" "ConfigMap" .Release.Namespace "cic-private-env") -}}
      {{- $CP_VOLUME_CLAIM = include "env.get" (dict "cm" "cic-private-env" "key" "CP_VOLUME_CLAIM" "default" $CP_VOLUME_CLAIM "required" "false" "Release" .Release) -}}
      {{- $CP_SERVICE_ACCOUNT_NAME = include "env.get" (dict "cm" "cic-private-env" "key" "CP_DEFAULT_SA" "default" $CP_SERVICE_ACCOUNT_NAME "required" "false" "Release" .Release) -}}
    {{- end -}}
  {{- end -}}

  # RECOMMENDED CP SUPPLIED SETTINGS
  {{- if or (include "env.check" (dict "cm" "cp-env" "key" "CP_CONTAINER_REGISTRY" "Release" .Release)) (include "env.check" (dict "cm" "cic-env" "key" "SYSTEM_DOCKER_REGISTRY" "Release" .Release)) (.Values.global.cic.data.SYSTEM_DOCKER_REGISTRY) }}
    {{- $registry = include "env.get" (dict "cm" "cic-env" "key" "SYSTEM_DOCKER_REGISTRY" "default" $registry "required" "false" "Release" .Release) -}}
    {{- if .Values.global.cic.data.SYSTEM_DOCKER_REGISTRY -}}
      {{- $registry = .Values.global.cic.data.SYSTEM_DOCKER_REGISTRY -}}
    {{- end -}}
    # Cp-env (Will be preferred over cic-env, cic-private-env, cic-shared-env, or .Values.global.cic.data)
    {{- $registry = include "env.get" (dict "cm" "cp-env" "key" "CP_CONTAINER_REGISTRY" "default" $registry "required" "false" "Release" .Release) -}}
    {{- if .Values.global.cic.data.SYSTEM_REPO -}}
      {{- $repo = .Values.global.cic.data.SYSTEM_REPO -}}
    {{- else if contains "ghcr.io" $registry -}}
      {{- $repo = "tibco/msg-platform-cicd" -}}
      {{- $pullSecret = "cic2-tcm-ghcr-secret" -}}
    {{- else if .Values.cp.useNewRepos -}}
      {{- if contains "jfrog.io" $registry -}}
        {{- $repo = include "msgdp.prodImageRepo" . -}}
      {{- else if contains "amazonaws.com" $registry -}}
        {{- $repo = include "msgdp.devImageRepo" . -}}
      {{- else if contains "azurecr.io" $registry -}}
        {{- $repo = include "msgdp.devImageRepo" . -}}
      {{- else if contains "reldocker.tibco.com" $registry -}}
        {{- $repo = include "msgdp.reldockerImageRepo" . -}}
      {{- else -}}
        {{- $repo = include "msgdp.defaultImageRepo" . -}}
      {{- end -}}
    {{- else -}}
      {{- if contains "jfrog.io" $registry -}}
        {{- $repo = include "msgdp.jfrogImageRepoOld" . -}}
      {{- else if contains "amazonaws.com" $registry -}}
        {{- $repo = include "msgdp.ecrImageRepoOld" . -}}
      {{- else if contains "azurecr.io" $registry -}}
        {{- $repo = include "msgdp.acrImageRepoOld" . -}}
      {{- else if contains "reldocker.tibco.com" $registry -}}
        {{- $repo = include "msgdp.reldockerImageRepoOld" . -}}
      {{- else -}}
        {{- $repo = include "msgdp.defaultImageRepoOld" . -}}
      {{- end -}}
    {{- end -}}
    {{- $repo = include "env.get" (dict "cm" "cp-env" "key" "CP_CONTAINER_REGISTRY_REPO" "default" $repo "required" "false" "Release" .Release) -}}
    {{- $pullSecret = ternary  $pullSecret  .Values.global.cic.data.PULL_SECRET ( not  .Values.global.cic.data.PULL_SECRET ) -}}
    {{- $pullSecret = include "env.get" (dict "cm" "cp-env" "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" $pullSecret "required" "false" "Release" .Release) -}}
  {{- end -}}

  # OVERRIDE SETTINGS
  {{- if .Values.cp -}}
    {{- $CP_VOLUME_CLAIM = ternary  $CP_VOLUME_CLAIM  .Values.cp.CP_VOLUME_CLAIM ( not  .Values.cp.CP_VOLUME_CLAIM ) -}}
    {{- $registry = ternary  $registry  .Values.cp.registry ( not  .Values.cp.registry ) -}}
    {{- $repo = ternary  $repo  .Values.cp.repository ( not  .Values.cp.repository ) -}}
    {{- $imageName = ternary  $imageName  .Values.cp.imageName ( not  .Values.cp.imageName ) -}}
    {{- $imageTag = ternary  $imageTag  .Values.cp.imageTag ( not  .Values.cp.imageTag ) -}}
    {{- $TARGET_PATH = ternary  $TARGET_PATH  .Values.cp.TARGET_PATH ( not  .Values.cp.TARGET_PATH ) -}}
    {{- $pullSecret = ternary  $pullSecret  .Values.cp.pullSecret ( not  .Values.cp.pullSecret ) -}}
    {{- $pullPolicy = ternary  $pullPolicy  .Values.cp.pullPolicy ( not  .Values.cp.pullPolicy ) -}}
      {{- if hasKey .Values.cp "enableWebserverSecurityContext" -}}
        {{- $enableWebserverSecurityContext = .Values.cp.enableWebserverSecurityContext -}}
      {{- end -}}
      {{- if hasKey .Values.cp "enableJobSecurityContext" -}}
        {{- $enableJobSecurityContext = .Values.cp.enableJobSecurityContext -}}
      {{- end -}}
      {{- if hasKey .Values.cp "enableSecurityContext" -}}
        {{- $enableWebserverSecurityContext = .Values.cp.enableSecurityContext -}}
        {{- $enableJobSecurityContext = .Values.cp.enableSecurityContext -}}
      {{- end -}}
  {{- end -}}
  {{- $imageDefaultName := printf "%s/%s/%s:%s" $registry $repo $imageName $imageTag | replace "\"" "" -}}
#
cp:
  uid: 1000
  gid: 1000
  CP_VOLUME_CLAIM: {{ $CP_VOLUME_CLAIM }}
  registry: {{ $registry }}
  repo: {{ $repo }}
  imageFullName: {{ .Values.cp.imageFullName | default $imageDefaultName }}
  TARGET_PATH: {{ $TARGET_PATH }}
  pullSecret: {{ $pullSecret }}
  pullPolicy: {{ $pullPolicy }}
  LOGGING_FLUENTBIT_ENABLED: {{ $CP_LOGGING_FLUENTBIT_ENABLED }}
  OTEL_SERVICE: {{ $CP_OTEL_SERVICE }}
  DNS_DOMAIN: '{{ $DNS_DOMAIN }}'
  ADMIN_DNS_DOMAIN: '{{ $ADMIN_DNS_DOMAIN }}'
  serviceAccount: {{ $CP_SERVICE_ACCOUNT_NAME }}
  SUBSCRIPTION_SINGLE_NAMESPACE: {{ $CP_SUBSCRIPTION_SINGLE_NAMESPACE }}
  SYSTEM_WHO: {{ $SYSTEM_WHO }}
  ENV_TYPE: {{ $ENV_TYPE }}
  enableWebserverSecurityContext: {{ $enableWebserverSecurityContext }}
  enableJobSecurityContext: {{ $enableJobSecurityContext }}
  boot:
    volName: scripts-vol
    storageType: configMap
    storageName: tp-cp-msg-webserver-scripts
    readOnly: true
  cp_env:
    volName: cp-env-vol
    storageType: configMap
    storageName: cp-env
    readOnly: false
    optional: true
  cic_env:
    volName: cic-env-vol
    storageType: configMap
    storageName: cic-env
    readOnly: false
    optional: true
  cp_dns:
    volName: cp-dns-vol
    storageType: configMap
    storageName: {{ include "const.onprem.dnsdomains" . }}
    readOnly: false
    optional: true
  cic_dns:
    volName: cic-dns-vol
    storageType: configMap
    storageName: {{ include "const.saas.dnsdomains" . }}
    readOnly: false
    optional: true
  cp_extra:
    volName: cp-extra-vol
    storageType: configMap
    storageName: msg-cp-extra
    readOnly: false
    optional: true
{{- end }}

{{/*
msg.envPodRefs - expand a list of <name: field> for use in a env: section
*/}}
{{- define "msg.envPodRefs" }}
# START-OF- EXPANDED PodRef List
{{- range $key, $val := . }}
- name: {{ $key | quote }}
  valueFrom:
    fieldRef:
      fieldPath: {{ $val }}
{{- end }}
# END-OF-EXPANDED PodRef List
{{- end }}


{{/*
msg.envStdPodRefs - generate a list of standard <name: field> for use in a env: section
*/}}
{{- define "msg.envStdPodRefs" }}
- name: "MY_RELEASE"
  value: {{ .Release.Name }}
{{- $stdRefs := (dict "MY_POD_NAME" "metadata.name" "MY_NAMESPACE" "metadata.namespace" "MY_POD_IP" "status.podIP" "MY_NODE_NAME" "spec.nodeName" "MY_NODE_IP" "status.hostIP" "MY_SA_NAME" "spec.serviceAccountName"  ) -}}
{{ include "msg.envPodRefs" $stdRefs }}
{{- end }}

{{/*
msg.webserver.security.pod - Generate a pod securityContext section from $xxParams struct
.. works with msg.webserver.security.container to standardize non-root securityContext restrictions
*/}}
{{- define "msg.webserver.security.pod" }}
{{- if .cp.enableWebserverSecurityContext }}
securityContext:
  runAsUser: {{ int .cp.uid }}
  runAsGroup: {{ int .cp.gid }}
  fsGroup: {{ int .cp.gid }}
    {{- if eq (int 0) (int .cp.uid) }}
  runAsNonRoot: false
    {{- else }}
  runAsNonRoot: true
  fsGroupChangePolicy: Always
  seccompProfile:
    type: RuntimeDefault
    {{- end }}
{{- end }}
{{- end }}

{{- define "msg.job.security.pod" }}
{{- if .cp.enableJobSecurityContext }}
securityContext:
  runAsUser: {{ int .cp.uid }}
  runAsGroup: {{ int .cp.gid }}
  fsGroup: {{ int .cp.gid }}
    {{- if eq (int 0) (int .cp.uid) }}
  runAsNonRoot: false
    {{- else }}
  runAsNonRoot: true
  fsGroupChangePolicy: Always
  seccompProfile:
    type: RuntimeDefault
    {{- end }}
{{- end }}
{{- end }}

{{/*
msg.cp.security.container - Generate a container securityContext section from $xxParams struct
.. works with msg.cp.security.pod to standardize non-root securityContext restrictions
*/}}
{{- define "msg.webserver.security.container" }}
{{- if .cp.enableWebserverSecurityContext }}
securityContext:
  runAsUser: {{ int .cp.uid }}
  runAsGroup: {{ int .cp.gid }}
    {{- if ne (int 0) (int .cp.uid) }}
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
    {{- end }}
{{- end }}
{{- end }}

{{- define "msg.job.security.container" }}
{{- if .cp.enableJobSecurityContext }}
securityContext:
  runAsUser: {{ int .cp.uid }}
  runAsGroup: {{ int .cp.gid }}
    {{- if ne (int 0) (int .cp.uid) }}
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
    {{- end }}
{{- end }}
{{- end }}
