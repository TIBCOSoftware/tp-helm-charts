{{/*
   Copyright © 2024. Cloud Software Group, Inc.
   This file is subject to the license terms contained
   in the license file that is distributed with this file.
*/}}

{{- define "tp-cp-web-server.consts.appName" }}tp-cp-web-server{{ end -}}

{{- define "tp-cp-web-server.consts.component" }}cp{{ end -}}

{{- define "tp-cp-web-server.consts.team" }}tp-cp{{ end -}}

{{- define "tp-cp-web-server.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-control-plane-env-configmap" }}tp-cp-core-env{{ end -}}
{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}

{{- define "cp-core-configuration.container-registry" }}
  {{- .Values.global.tibco.containerRegistry.url }}
{{- end }}

{{- define "cp-core-configuration.container-registry.secret" }}tibco-container-registry-credentials{{- end }}

{{- define "cp-core-configuration.pvc-name" }}
{{- if .Values.global.external.storage.pvcName }}
  {{- .Values.global.external.storage.pvcName }}
{{- else }}
{{- "control-plane-pvc" }}
{{- end }}
{{- end }}

{{- define "cp-core-bootstrap.otel.services" -}}
{{- "otel-services" }}
{{- end }}

{{- define "cp-core-configuration.enableLogging" }}
  {{- $isEnableLogging := "" -}}
    {{- if ( .Values.global.tibco.logging.fluentbit.enabled )  -}}
        {{- $isEnableLogging = "1" -}}
    {{- end -}}
  {{ $isEnableLogging }}
{{- end }}

{{- define "tp-cp-web-server.consts.http.request.timeout" }}120000{{ end -}}
{{- define "tp-cp-web-server.consts.idle.time.seconds" }}14400{{ end -}}
{{- define "tp-cp-web-server.consts.custom.scheme.urls" }}'["vscode://tibco.flogo"]'{{ end -}}
{{- define "tp-cp-web-server.consts.web.server.log.enabled" }}true{{ end -}}
{{- define "tp-cp-web-server.consts.external.idp.ui" }}enable{{ end -}}
{{- define "tp-cp-web-server.consts.disable.configuration.refresh" }}false{{ end -}}
{{- define "tp-cp-web-server.consts.cloudops.port" }}98{{ end -}}
{{- define "tp-cp-web-server.consts.redirection.time" }}5{{ end -}}
{{- define "tp-cp-web-server.consts.config.files.to.notify.idm.on.upload" }}'["idm/reloadable.conf"]'{{ end -}}
{{- define "tp-cp-web-server.consts.admin.ui.logs.services" }}'[{"serviceType":"bwprovisioner","serviceContainer":"bwprovisioner"},{"serviceType":"flogoprovisioner","serviceContainer":"flogoprovisioner"},{"serviceType":"o11y-service","serviceContainer":"tp-o11y-service"},{"serviceType":"tp-tibtunnel","serviceContainer":"tibtunnel"},{"serviceType":"oauth2-proxy","serviceContainer":"oauth2-proxy"},{"serviceType":"provisioner-agent","serviceContainer":"provisioner-agent"},{"serviceType":"artifactmanager","serviceContainer":"artifactmanager"}]'{{ end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "cp-core-configuration.image-repository" -}}
  {{- .Values.global.tibco.containerRegistry.repository -}}
{{- end -}}

{{- define "cp-core-configuration.container-registry-image-pull-secret-name" }}tibco-container-registry-credentials{{ end }}

{{- define "cp-core-configuration.cp-container-registry-username" }}
  {{- .Values.global.tibco.containerRegistry.username | b64enc -}}
{{- end }}

{{- define "cp-core-configuration.cp-container-registry-password" }}
  {{- .Values.global.tibco.containerRegistry.password | b64enc -}}
{{- end }}
