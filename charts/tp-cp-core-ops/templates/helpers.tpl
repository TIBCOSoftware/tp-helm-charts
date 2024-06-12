{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-core-ops.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-core-ops.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-core-ops.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-core-ops.consts.harborImageRepo" }}pcp{{end}}
{{- define "tp-cp-core-ops.consts.defaultImageRepo" }}tibco-platform-local-docker/core{{end}}


{{- define "tp-cp-core-ops.image.repository" -}}
  {{- if contains "jfrog.io" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core-ops.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core-ops.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core-ops.consts.acrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core-ops.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-core-ops.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}