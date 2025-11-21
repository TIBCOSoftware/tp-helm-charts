{{/* 

Copyright © 2023 - 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-infra.consts.appName" }}tp-cp-infra{{ end -}}
{{- define "tp-cp-infra.consts.deploymentName" }}tp-cp-infra{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-cp-infra.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-infra.consts.component" }}tp-cp-infra{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-infra.consts.team" }}cic-compute{{ end -}}


{{- define "tp-cp-infra.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "tp-cp-infra.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "tp-cp-infra.image.registry" }}
    {{- .Values.global.tibco.containerRegistry.url }}
{{- end -}}

{{/* set repository based on the registry url. Honor the image.repo if passed*/}}
{{- define "tp-cp-infra.image.repository" -}}
    {{- .Values.global.tibco.containerRegistry.repository -}}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-infra.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Name of alerts-service service. */}}
{{- define "alerts-service.consts.svcName" }}alerts-service{{ end -}}

{{/* Name of compute-service service. */}}
{{- define "compute-service.consts.svcName" }}compute-services{{ end -}}
