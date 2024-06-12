#
# Copyright © 2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

{{- define "finops-web-server.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "finops-web-server.consts.ecrImageRepo" }}pcp{{end}}
{{- define "finops-web-server.consts.acrImageRepo" }}pcp{{end}}
{{- define "finops-web-server.consts.harborImageRepo" }}pcp{{end}}
{{- define "finops-web-server.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{/* Container registry for control plane. default value empty */}}
{{- define "finops-web-server.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "finops-web-server.image.repository" -}}
  {{- if contains "jfrog.io" (include "finops-web-server.image.registry" .) }}
    {{- include "finops-web-server.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "finops-web-server.image.registry" .) }}
    {{- include "finops-web-server.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "finops-web-server.image.registry" .) }}
    {{- include "finops-web-server.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "finops-web-server.image.registry" .) }}
    {{- include "finops-web-server.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "finops-web-server.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}