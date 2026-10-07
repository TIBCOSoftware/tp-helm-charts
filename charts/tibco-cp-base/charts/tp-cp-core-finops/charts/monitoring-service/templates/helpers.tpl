{{/*
  Copyright (c) 2023-2026. Cloud Software Group, Inc.
  This file is subject to the license terms contained
  in the license file that is distributed with this file.
*/}}

{{- define "monitoring-service.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url | default "csgprdusw2reposaas.jfrog.io" }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" -}}
{{- if .Values.global.tibco.containerRegistry.secret -}}
{{- .Values.global.tibco.containerRegistry.secret -}}
{{- else if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password -}}
{{- "tibco-container-registry-credentials" -}}
{{- end -}}
{{- end }}

{{- define "monitoring-service.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}

{{- define "tp-cp-core-finops.enableResourceConstraints" -}}
  {{- .Values.global.tibco.enableResourceConstraints | default "false" }}
{{- end }}

{{- define "cp-core-configuration.service-account-name" }}
{{- if empty .Values.global.tibco.serviceAccount -}}
   {{- "control-plane-sa" }}
{{- else -}}
   {{- .Values.global.tibco.serviceAccount | quote }}
{{- end }}
{{- end }}