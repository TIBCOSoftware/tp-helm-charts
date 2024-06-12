{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-core.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-core.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-core.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-core.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-core.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}


{{- define "tp-cp-core.image.repository" -}}
  {{- if contains "jfrog.io" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-core.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}