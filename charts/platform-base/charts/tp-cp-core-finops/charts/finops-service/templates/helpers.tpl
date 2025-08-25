#
# Copyright © 2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

{{/* Container registry for control plane. default value csgprdusw2reposaas.jfrog.io */}}
{{- define "finops-service.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url | default "csgprdusw2reposaas.jfrog.io" }}
{{- end }}

{{/* secret for control plane. default value empty */}}
{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{/* Repository for Platform images. default value tibco-platform-docker-prod */}}
{{- define "finops-service.image.repository" -}}
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