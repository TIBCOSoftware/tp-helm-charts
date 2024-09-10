{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "compute-services.consts.appName" }}compute-services{{ end -}}

{{/* Tenant name. */}}
{{- define "compute-services.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "compute-services.consts.component" }}tp-cp-bootstrap{{ end -}}

{{/* Team we're a part of. */}}
{{- define "compute-services.consts.team" }}cic-compute{{ end -}}


{{- define "compute-services.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "compute-services.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "compute-services.image.registry" }}
    {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. Honor the image.repo if passed*/}}
{{- define "compute-services.image.repository" -}}
    {{- .Values.global.tibco.containerRegistry.repository -}}
{{- end -}}