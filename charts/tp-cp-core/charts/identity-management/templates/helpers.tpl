{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{- define "tp-identity-management.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-identity-management.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-identity-management.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-identity-management.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-identity-management.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{/* Container registry for control plane. default value empty */}}
{{- define "tp-identity-management.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-identity-management.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-identity-management.image.registry" .) }}
    {{- include "tp-identity-management.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-identity-management.image.registry" .) }}
    {{- include "tp-identity-management.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-identity-management.image.registry" .) }}
    {{- include "tp-identity-management.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-identity-management.image.registry" .) }}
    {{- include "tp-identity-management.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-identity-management.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-identity-management.consts.jfrogImageName" }}identity-management{{end}}
{{- define "tp-identity-management.consts.defaultImageName" }}identity-management-on-prem{{end}}

{{- define "tp-identity-management.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-identity-management.image.registry" .) }}
    {{- include "tp-identity-management.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-identity-management.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}