{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "dp-configure-namespace-config.consts.appName" }}dp-configure-namespace-config{{ end -}}

{{/* Tenant name. */}}
{{- define "dp-configure-namespace-config.consts.tenantName" }}infrastructure{{ end -}}

{{/* Component we're a part of. */}}
{{- define "dp-configure-namespace-config.consts.component" }}tibco-platform-data-plane{{ end -}}

{{/* Team we're a part of. */}}
{{- define "dp-configure-namespace-config.consts.team" }}cic-compute{{ end -}}

{{/* Data plane workload type */}}
{{- define "dp-configure-namespace-config.consts.workloadType" }}infra{{ end -}}

{{- define "dp-configure-namespace-config.consts.imageCredential" }}
{{- with .Values.global.tibco.containerRegistry }}
{{- if .username  }}
{{- if .password }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .url .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}