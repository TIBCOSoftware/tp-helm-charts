{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-identity-provider.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-identity-provider.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-identity-provider.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-identity-provider.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-identity-provider.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{/* Container registry for control plane. default value empty */}}
{{- define "tp-cp-identity-provider.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-identity-provider.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-identity-provider.image.registry" .) }}
    {{- include "tp-cp-identity-provider.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-identity-provider.image.registry" .) }}
    {{- include "tp-cp-identity-provider.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-cp-identity-provider.image.registry" .) }}
    {{- include "tp-cp-identity-provider.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-identity-provider.image.registry" .) }}
    {{- include "tp-cp-identity-provider.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-identity-provider.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-cp-identity-provider.consts.jfrogImageName" }}identity-provider{{end}}
{{- define "tp-cp-identity-provider.consts.defaultImageName" }}tp-cp-identity-provider-on-prem{{end}}

{{- define "tp-cp-identity-provider.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-cp-identity-provider.image.registry" .) }}
    {{- include "tp-cp-identity-provider.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-cp-identity-provider.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}