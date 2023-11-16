{{/* 
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-dp-secret-controller.consts.appName" }}dp-secret-controller{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-dp-secret-controller.consts.tenantName" }}infrastructure{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-dp-secret-controller.consts.component" }}tibco-platform-data-plane{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-dp-secret-controller.consts.team" }}cic-compute{{ end -}}

{{/* Data plane workload type */}}
{{- define "tp-dp-secret-controller.consts.workloadType" }}infra{{ end -}}

{{- define "tp-dp-secret-controller.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "tp-dp-secret-controller.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "tp-dp-secret-controller.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "tp-dp-secret-controller.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "tp-dp-secret-controller.consts.defaultImageRepo" }}stratosphere{{end}}
 
{{- define "tp-dp-secret-controller.image.registry" }}
  {{- .Values.global.cp.containerRegistry.url }}
{{- end -}}
 
{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-dp-secret-controller.image.repository" -}}
  {{- if contains "jfrog.io" (include "tp-dp-secret-controller.image.registry" .) }}
    {{- include "tp-dp-secret-controller.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-dp-secret-controller.image.registry" .) }}
    {{- include "tp-dp-secret-controller.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-dp-secret-controller.image.registry" .) }}
    {{- include "tp-dp-secret-controller.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-dp-secret-controller.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}