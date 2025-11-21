{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "router-operator.consts.appName" }}router{{ end -}}
{{- define "router-operator.consts.deploymentName" }}cp-router{{ end -}}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "router-operator.consts.globalResourceName" }}{{ include "router-operator.consts.appName" . }}-{{ .Values.global.tibco.controlPlaneInstanceId }}{{ end -}}

{{/* Tenant name. */}}
{{- define "router-operator.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "router-operator.consts.component" }}tibco-cp-base{{ end -}}

{{/* Team we're a part of. */}}
{{- define "router-operator.consts.team" }}cic-compute{{ end -}}

{{- define "router-operator.consts.webhook" }}router-operator-webhook{{ end -}}

{{- define "router-operator.consts.webhook.validating" }}{{ include "router-operator.consts.globalResourceName" .}}{{ end -}}

{{/* Name of the default service account */}}
{{- define "router-operator.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "router-operator.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "router-operator.image.registry" }}
    {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "router-operator.image.repository" -}}
    {{- .Values.global.tibco.containerRegistry.repository }}
{{- end -}}
