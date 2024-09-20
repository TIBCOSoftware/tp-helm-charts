{{/* 
Copyright © 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}


{{/* jfrog repo hack to change the repo image path; this should be handled by the upper layer! */}}
{{- define "tibco.image.repository.oauth2proxy" -}}
  {{- if contains "jfrog.io" .Values.image.repository }}{{ .Values.image.repository | replace "stratosphere" "tibco-platform-local-docker/infra" }}
  {{- else }}
    {{- .Values.image.repository | replace "stratosphere" "pea-coreintegration/tibco-control-plane/tibco-platform-local-docker/infra" }}
  {{- end }}
{{- end -}}

{{/* init container image used for registering OAuth client and creating a kubernetes secret with it */}}
{{- define "tibco.image.repository.alpine" -}}
  {{- if contains "jfrog.io" .Values.global.cp.containerRegistry.url }}{{ .Values.global.cp.containerRegistry.url }}/tibco-platform-docker-prod/{{ .Values.tibco.initContainer.image }}:{{ .Values.tibco.initContainer.tag }}
  {{- else }}
    {{- .Values.global.cp.containerRegistry.url }}/pea-coreintegration/tibco-control-plane/tibco-platform-local-docker/infra/{{ .Values.tibco.initContainer.image }}:{{ .Values.tibco.initContainer.tag }}
  {{- end }}
{{- end -}}

{{/* fluentbit container image */}}
{{- define "tibco.image.repository.fluentbit" -}}
  {{- if contains "jfrog.io" .Values.global.cp.containerRegistry.url }}{{ .Values.global.cp.containerRegistry.url }}/tibco-platform-local-docker/infra/{{ .Values.tibco.loggerContainer.image }}:{{ .Values.tibco.loggerContainer.tag }}
  {{- else }}
    {{- .Values.global.cp.containerRegistry.url }}/pea-coreintegration/tibco-control-plane/tibco-platform-local-docker/infra/{{ .Values.tibco.loggerContainer.image }}:{{ .Values.tibco.loggerContainer.tag }}
  {{- end }}
{{- end -}}