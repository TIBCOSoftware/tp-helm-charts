{{- /*
# Copyright © 2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
*/}}

{{/*
Custom additions for our Jfrog repo usage
*/}}

{{- define "on-premises-third-party.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "on-premises-third-party.image.registry" }}
    {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. Honor the image.repo if passed*/}}
{{- define "on-premises-third-party.image.repository" -}}
    {{- .Values.global.tibco.containerRegistry.repository -}}
{{- end -}}

{{- define "on-premises-third-party.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}