{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-email-service.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-email-service.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-email-service.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-email-service.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-email-service.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{- define "tp-cp-email-service.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{- define "tp-cp-email-service.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-email-service.image.registry" .) }}
    {{- include "tp-cp-email-service.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-email-service.image.registry" .) }}
    {{- include "tp-cp-email-service.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-cp-email-service.image.registry" .) }}
    {{- include "tp-cp-email-service.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-email-service.image.registry" .) }}
    {{- include "tp-cp-email-service.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-email-service.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-cp-email-service.consts.jfrogImageName" }}email-service{{end}}
{{- define "tp-cp-email-service.consts.defaultImageName" }}cp-email-service-on-prem{{end}}

{{- define "tp-cp-email-service.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-cp-email-service.image.registry" .) }}
    {{- include "tp-cp-email-service.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-cp-email-service.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}