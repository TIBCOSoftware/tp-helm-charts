{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-web-server.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-web-server.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-web-server.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-web-server.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-web-server.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{/* Container registry for control plane. default value empty */}}
{{- define "tp-cp-web-server.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-web-server.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-web-server.image.registry" .) }}
    {{- include "tp-cp-web-server.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-web-server.image.registry" .) }}
    {{- include "tp-cp-web-server.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-cp-web-server.image.registry" .) }}
    {{- include "tp-cp-web-server.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-web-server.image.registry" .) }}
    {{- include "tp-cp-web-server.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-web-server.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-cp-web-server.consts.jfrogImageName" }}web-server{{end}}
{{- define "tp-cp-web-server.consts.defaultImageName" }}cp-web-server-on-prem{{end}}

{{- define "tp-cp-web-server.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-cp-web-server.image.registry" .) }}
    {{- include "tp-cp-web-server.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-cp-web-server.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}