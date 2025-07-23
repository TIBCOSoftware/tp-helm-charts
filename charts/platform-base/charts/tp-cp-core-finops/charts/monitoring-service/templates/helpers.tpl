#
# Copyright © 2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

{{- define "monitoring-service.image.registry" }}
  {{- .Values.global.tibco.containerRegistry.url | default "csgprdusw2reposaas.jfrog.io" }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{- define "monitoring-service.image.repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository | default "tibco-platform-docker-prod" }}
{{- end -}}

{{- define "tp-cp-core-finops.enableResourceConstraints" -}}
  {{- .Values.global.tibco.enableResourceConstraints | default "false" }}
{{- end }}
