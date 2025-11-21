{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "flogo-webserver.consts.appName" }}tp-cp-flogo-webserver{{ end -}}

{{- define "tp-control-plane-dnsdomain-configmap" }}tp-cp-core-dnsdomains{{ end -}}
{{- define "flogo-webserver.cp-env-configmap" }}cp-env{{ end -}}


{{/* Create chart name and version as used by the chart label. */}}
{{- define "flogo-webserver.shared.labels.chartLabelValue" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels used by the resources in this chart
*/}}
{{- define "flogo-webserver.shared.labels.selector" -}}
app.kubernetes.io/name: {{ include "flogo-webserver.consts.appName" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.cloud.tibco.com/owner: {{ include "flogo-webserver.cp-instance-id" . }}
{{- end -}}

{{/*
Standard labels added to all resources created by this chart.
Includes labels used as selectors (i.e. template "labels.selector")
*/}}
{{- define "flogo-webserver.shared.labels.standard" -}}
{{ include  "flogo-webserver.shared.labels.selector" . }}
helm.sh/chart: {{ include "flogo-webserver.shared.labels.chartLabelValue" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}


{{- define "flogo-webserver.image.registry" }}
{{- default "" .Values.global.tibco.containerRegistry.url }}
{{- end }}


{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogo-webserver.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "flogo-webserver.integration.image.repository" -}}
{{- default "" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "flogo-webserver.pvc-name" }}
{{- if empty .Values.global.external.storage.pvcName -}}
{{- "control-plane-pvc" }}
{{- else -}}
{{- .Values.global.external.storage.pvcName }}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "flogo-webserver.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- if and .Values.global.tibco.containerRegistry.username .Values.global.tibco.containerRegistry.password }}
     {{- "tibco-container-registry-credentials" }}
  {{- end }}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "flogo-webserver.cp-instance-id" }}
{{- default "" .Values.global.tibco.controlPlaneInstanceId }}
{{- end }}

{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "flogo-webserver.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- default "" .Values.global.tibco.serviceAccount }}
{{- end }}
{{- end }}

{{/* Control plane OTEL service. default value otel-services */}}
{{- define "flogo-webserver.o11y-service-host" }}
{{- "o11y-service."}}{{ .Release.Namespace }}{{".svc.cluster.local" }}
{{- end }}

{{- define "flogo-webserver.use-single-namespace" -}}
{{- .Values.global.tibco.useSingleNamespace | quote }}
{{- end }}

{{- define "tp-cp-flogo-mcpserver.consts.appName" }}tp-cp-flogo-mcpserver{{- end }}

{{- define "flogo-webserver.service.host-port" }}{{ include "flogo-webserver.consts.appName" . }}.{{ .Release.Namespace }}.svc.cluster.local:3002{{- end }}

{{- define "cp-webserver.service.host-port" }}tp-cp-web-server.{{ .Release.Namespace }}.svc.cluster.local:3000{{- end }}
