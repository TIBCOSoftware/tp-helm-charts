{{/*
 Copyright © 2025. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-core.consts.jfrogImageRepo" }}tibco-platform-local-docker/core{{end}}
{{- define "tp-cp-core.consts.ecrImageRepo" }}pcp{{end}}
{{- define "tp-cp-core.consts.acrImageRepo" }}pcp{{end}}
{{- define "tp-cp-core.consts.defaultImageRepo" }}pcp{{end}}


{{- define "tp-cp-core.image.repository" -}}
  {{- if contains "jfrog.io" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.ecrImageRepo" .}}
  {{- else if contains "azurecr.io" (include "cp-core-configuration.container-registry" .) }}
    {{- include "tp-cp-core.consts.acrImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-core.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/*
Returns the ServiceAccount name for the cleanup job.
Uses user-provided serviceAccount if available, otherwise dedicated cleanup-sa.
*/}}
{{- define "tp-cp-core.cleanup.serviceAccountName" -}}
  {{- if empty .Values.global.tibco.serviceAccount }}
    {{- include "tp-control-plane.consts.appName" . }}-cleanup-sa
  {{- else }}
    {{- .Values.global.tibco.serviceAccount }}
  {{- end }}
{{- end -}}

{{/*
Returns the container registry secret name for cleanup jobs.
Returns empty string if credentials are not provided.
*/}}
{{- define "tp-cp-core.cleanup.containerRegistrySecret" -}}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
    {{- "tibco-container-registry-credentials-cleanup" }}
  {{- end }}
{{- end -}}

{{/*
Generates the docker config JSON for container registry credentials.
*/}}
{{- define "tp-cp-core.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}