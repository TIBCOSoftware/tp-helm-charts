{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-admin-webserver.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-admin-webserver.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-admin-webserver.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-admin-webserver.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-admin-webserver.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}

{{/* Container registry for control plane. default value empty */}}
{{- define "tp-cp-admin-webserver.image.registry" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-admin-webserver.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-cp-admin-webserver.image.registry" .) }}
    {{- include "tp-cp-admin-webserver.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-admin-webserver.image.registry" .) }}
    {{- include "tp-cp-admin-webserver.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "tp-cp-admin-webserver.image.registry" .) }}
    {{- include "tp-cp-admin-webserver.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-admin-webserver.image.registry" .) }}
    {{- include "tp-cp-admin-webserver.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-admin-webserver.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set image name based on the registry url. We will have different name for each one. */}}
{{- define "tp-cp-admin-webserver.consts.jfrogImageName" }}admin-webserver{{end}}
{{- define "tp-cp-admin-webserver.consts.defaultImageName" }}cp-admin-webserver-on-prem{{end}}

{{- define "tp-cp-admin-webserver.image.name" -}}
  {{- if contains "jfrog.io" (include "tp-cp-admin-webserver.image.registry" .) }}
    {{- include "tp-cp-admin-webserver.consts.jfrogImageName" .}}
  {{- else }}
    {{- include "tp-cp-admin-webserver.consts.defaultImageName" .}}
  {{- end }}
{{- end -}}