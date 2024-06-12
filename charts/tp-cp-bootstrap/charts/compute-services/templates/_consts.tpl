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

{{/* query node service node and port.  */}}
{{- define "compute-services.consts.queryNodeService" }}http://querynode.{{ .Release.Namespace }}.svc.cluster.local:9681{{ end -}}

{{- define "compute-services.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "compute-services.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "compute-services.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "compute-services.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "compute-services.consts.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "compute-services.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- .Values.global.tibco.containerRegistry.url }}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "compute-services.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "compute-services.image.registry" .) }} 
    {{- include "compute-services.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "compute-services.image.registry" .) }}
    {{- include "compute-services.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "compute-services.image.registry" .) }}
    {{- include "compute-services.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "compute-services.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}