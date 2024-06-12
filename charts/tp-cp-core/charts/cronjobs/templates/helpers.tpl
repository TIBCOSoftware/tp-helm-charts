{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-cronjobs.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-cronjobs.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-cronjobs.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-cronjobs.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-cronjobs.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{- define "tp-cp-cronjobs.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "tp-cp-cronjobs.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-cronjobs.image.registry" .) }}
    {{- include "tp-cp-cronjobs.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-cronjobs.image.registry" .) }}
    {{- include "tp-cp-cronjobs.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-cp-cronjobs.image.registry" .) }}
    {{- include "tp-cp-cronjobs.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-cronjobs.image.registry" .) }}
    {{- include "tp-cp-cronjobs.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-cronjobs.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-cp-cronjobs.consts.jfrogImageName" }}cronjobs{{end}}
{{- define "tp-cp-cronjobs.consts.defaultImageName" }}cp-cronjobs-on-prem{{end}}

{{- define "tp-cp-cronjobs.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-cp-cronjobs.image.registry" .) }}
    {{- include "tp-cp-cronjobs.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-cp-cronjobs.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}