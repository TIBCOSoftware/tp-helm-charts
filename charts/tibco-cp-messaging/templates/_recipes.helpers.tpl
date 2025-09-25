{{/*
MSGDP Controlplane Recipes Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{/*
need.msg.recipes.params
*/}}
{{ define "need.msg.recipes.params" }}
{{-  $cpParams := include "need.msg.cp.params" . | fromYaml -}}
{{- $TARGET_PATH := "/private/tsc/config/capabilities" -}}
{{- $jobPostSleep := "180" -}}
{{- $TARGET_PATH = ternary  $TARGET_PATH  .Values.recipes.TARGET_PATH ( not  .Values.recipes.TARGET_PATH ) -}}
{{- $jobPostSleep = ternary  $jobPostSleep  .Values.recipes.jobPostSleep ( not  .Values.recipes.jobPostSleep ) -}}
# Fill in $recipesParams yaml
{{ include "need.msg.cp.params" . }}
recipes:
  TARGET_PATH: {{ $TARGET_PATH }}
  jobPostSleep: {{ $jobPostSleep }}
securityProfile: "{{ .Values.recipes.securityProfile | default $cpParams.securityProfile | default "pss-restricted" }}"
{{ end }}
