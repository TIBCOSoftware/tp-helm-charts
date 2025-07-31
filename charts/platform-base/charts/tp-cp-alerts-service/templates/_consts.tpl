{{/* 

Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "alerts-service.consts.appName" }}alerts-service{{ end -}}

{{/* Tenant name. */}}
{{- define "alerts-service.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "alerts-service.consts.component" }}tp-cp-alerts{{ end -}}

{{/* Team we're a part of. */}}
{{- define "alerts-service.consts.team" }}alerts{{ end -}}

{{- define "alerts-service.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "alerts-service.otel.services" -}}
{{- "otel-services" }}
{{- end }}