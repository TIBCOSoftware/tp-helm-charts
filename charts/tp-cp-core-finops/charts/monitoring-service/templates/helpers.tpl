#
# Copyright © 2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

{{- define "monitoring-service.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "monitoring-service.consts.ecrImageRepo" }}pcp{{end}}
{{- define "monitoring-service.consts.acrImageRepo" }}pcp{{end}}
{{- define "monitoring-service.consts.harborImageRepo" }}pcp{{end}}
{{- define "monitoring-service.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{- define "monitoring-service.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "monitoring-service.image.repository" -}}
  {{- if contains "jfrog.io" (include "monitoring-service.image.registry" .) }}
    {{- include "monitoring-service.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "monitoring-service.image.registry" .) }}
    {{- include "monitoring-service.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "monitoring-service.image.registry" .) }}
    {{- include "monitoring-service.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "monitoring-service.image.registry" .) }}
    {{- include "monitoring-service.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "monitoring-service.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}
