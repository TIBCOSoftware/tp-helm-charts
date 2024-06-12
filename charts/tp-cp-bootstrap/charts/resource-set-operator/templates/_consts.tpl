{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application */}}
{{- define "resource-set-operator.consts.appName" }}resource-set-operator{{ end -}}

{{/* Tenant name. */}}
{{- define "resource-set-operator.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of */}}
{{- define "resource-set-operator.consts.component" }}tp-cp-bootstrap{{ end -}}

{{/* Team we're a part of. */}}
{{- define "resource-set-operator.consts.team" }}cic-compute{{ end -}}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "resource-set-operator.consts.globalResourceName" }}{{ include "resource-set-operator.consts.appName" . }}-{{ .Values.global.tibco.controlPlaneInstanceId }}{{ end -}}

{{/* Name of the webhook */}}
{{- define "resource-set-operator.consts.webhook" }}{{ include "resource-set-operator.consts.globalResourceName" . }}{{ end -}}

{{- define "resource-set-operator.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "resource-set-operator.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "resource-set-operator.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "resource-set-operator.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "resource-set-operator.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "resource-set-operator.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "resource-set-operator.consts.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "resource-set-operator.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- .Values.global.tibco.containerRegistry.url }}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "resource-set-operator.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "resource-set-operator.image.registry" .) }} 
    {{- include "resource-set-operator.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "resource-set-operator.image.registry" .) }}
    {{- include "resource-set-operator.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "resource-set-operator.image.registry" .) }}
    {{- include "resource-set-operator.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "resource-set-operator.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}