
{{/*
MSG CP Common Helpers
#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{- define "msgdp.ghcrImageRepo" -}}"tibco/msg-platform-cicd"{{ end }}
{{- define "msgdp.jfrogImageRepo" -}}"tibco-platform-local-docker/msg"{{ end }}
{{- define "msgdp.ecrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.acrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.reldockerImageRepo" -}}"messaging"{{ end }}
{{- define "msgdp.defaultImageRepo" -}}"messaging"{{ end }}

{{/*
need.msg.cp.params
*/}}
{{ define "need.msg.cp.params" }}
  # DEFAULT SETTINGS
  {{- $CP_VOLUME_CLAIM := "provider-cp-fs-store" -}}
  {{- $registry := "664529841144.dkr.ecr.us-west-2.amazonaws.com" -}}
  {{- $repo := include "msgdp.ecrImageRepo" . -}}
  {{- $imageName := "msg-cp-ui-contrib" -}}
  {{- $imageTag := "1.1.0-12" -}}
  {{- $TARGET_PATH := "/private/tsc/config/capabilities/platform" -}}
  {{- $pullSecret := "" -}}
  {{- $pullPolicy := "Always" -}}
  # LEGACY SETTINGS
  {{- if .Values.data.SYSTEM_DOCKER_REGISTRY -}}
    {{- $registry = .Values.data.SYSTEM_DOCKER_REGISTRY -}}
  {{- end -}}
  # RECOMMENDED CP SUPPLIED SETTINGS
  {{- if .Values.global.cic.data.CP_VOLUME_CLAIM -}}
    {{- $CP_VOLUME_CLAIM = .Values.global.cic.data.CP_VOLUME_CLAIM -}}
  {{- end -}}
  {{- if .Values.global.cic.data.SYSTEM_DOCKER_REGISTRY -}}
    {{- $registry = .Values.global.cic.data.SYSTEM_DOCKER_REGISTRY -}}
  {{- end -}}
  # RECOMMENDED SETTINGS
  {{- if .Values.global -}}
    {{- if .Values.global.cic.data -}}
        {{- if .Values.global.cic.data.SYSTEM_DOCKER_REGISTRY -}}
          {{- $registry = .Values.global.cic.data.SYSTEM_DOCKER_REGISTRY -}}
          {{- if .Values.global.cic.data.SYSTEM_REPO -}}
            {{- $repo = .Values.global.cic.data.SYSTEM_REPO -}}
          {{- else if contains "ghcr.io" $registry -}}
            {{- $repo = "tibco/msg-platform-cicd" -}}
            {{- $pullSecret = "cic2-tcm-ghcr-secret" -}}
          {{- else if contains "jfrog.io" $registry -}}
            {{- $repo = include "msgdp.jfrogImageRepo" . -}}
          {{- else if contains "amazonaws.com" $registry -}}
            {{- $repo = include "msgdp.ecrImageRepo" . -}}
          {{- else if contains "azurecr.io" $registry -}}
            {{- $repo = include "msgdp.acrImageRepo" . -}}
          {{- else if contains "reldocker.tibco.com" $registry -}}
            {{- $repo = include "msgdp.reldockerImageRepo" . -}}
          {{- else -}}
            {{- $repo = include "msgdp.defaultImageRepo" . -}}
          {{- end -}}
          {{- $pullSecret = ternary  $pullSecret  .Values.global.cic.data.PULL_SECRET ( not  .Values.global.cic.data.PULL_SECRET ) -}}
        {{- end -}}
    {{- end -}}
  {{- end -}}
  # OVERRIDE SETTINGS
  {{- if .Values.cp -}}
    {{- $CP_VOLUME_CLAIM = ternary  $CP_VOLUME_CLAIM  .Values.cp.CP_VOLUME_CLAIM ( not  .Values.cp.CP_VOLUME_CLAIM ) -}}
    {{- $registry = ternary  $registry  .Values.cp.registry ( not  .Values.cp.registry ) -}}
    {{- $repo = ternary  $repo  .Values.cp.repo ( not  .Values.cp.repo ) -}}
    {{- $imageName = ternary  $imageName  .Values.cp.imageName ( not  .Values.cp.imageName ) -}}
    {{- $imageTag = ternary  $imageTag  .Values.cp.imageTag ( not  .Values.cp.imageTag ) -}}
    {{- $TARGET_PATH = ternary  $TARGET_PATH  .Values.cp.TARGET_PATH ( not  .Values.cp.TARGET_PATH ) -}}
    {{- $pullSecret = ternary  $pullSecret  .Values.cp.pullSecret ( not  .Values.cp.pullSecret ) -}}
    {{- $pullPolicy = ternary  $pullPolicy  .Values.cp.pullPolicy ( not  .Values.cp.pullPolicy ) -}}
  {{- end -}}
  {{- $imageDefaultName := printf "%s/%s/%s:%s" $registry $repo $imageName $imageTag | replace "\"" "" -}}
#
cp:
  CP_VOLUME_CLAIM: {{ $CP_VOLUME_CLAIM }}
  registry: {{ $registry }}
  repo: {{ $repo }}
  imageFullName: {{ .Values.cp.imageFullName | default $imageDefaultName }}
  TARGET_PATH: {{ $TARGET_PATH }}
  pullSecret: {{ $pullSecret }}
  pullPolicy: {{ $pullPolicy }}
{{- end }}
