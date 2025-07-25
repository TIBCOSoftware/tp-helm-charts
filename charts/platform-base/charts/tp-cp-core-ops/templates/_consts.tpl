{{/*
 Copyright © 2024. Cloud Software Group, Inc.
 This file is subject to the license terms contained
 in the license file that is distributed with this file.
*/}}

{{- define "tp-control-plane-ops.consts.appName" }}tp-control-plane-ops{{ end -}}

{{- define "tp-control-plane-ops.consts.component" }}cp-ops{{ end -}}

{{- define "tp-control-plane-ops.consts.team" }}tp-cp{{ end -}}

{{- define "tp-control-plane-ops.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}
{{- define "tp-control-plane-ops.consts.cp-env-configmap" }}cp-env{{ end -}}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{ end }}

{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{ .Values.global.tibco.containerRegistry.repository }}
{{- end -}}
