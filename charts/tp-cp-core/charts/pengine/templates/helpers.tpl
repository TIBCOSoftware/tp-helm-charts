{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-pengine.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-pengine.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-pengine.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-pengine.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-pengine.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{/* Container registry for control plane. default value empty */}}
{{- define "tp-cp-pengine.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-pengine.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-pengine.image.registry" .) }}
    {{- include "tp-cp-pengine.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-pengine.image.registry" .) }}
    {{- include "tp-cp-pengine.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-cp-pengine.image.registry" .) }}
    {{- include "tp-cp-pengine.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-pengine.image.registry" .) }}
    {{- include "tp-cp-pengine.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-pengine.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-cp-pengine.consts.jfrogImageName" }}pengine{{end}}
{{- define "tp-cp-pengine.consts.defaultImageName" }}tp-cp-pengine-on-prem{{end}}

{{- define "tp-cp-pengine.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-cp-pengine.image.registry" .) }}
    {{- include "tp-cp-pengine.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-cp-pengine.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}