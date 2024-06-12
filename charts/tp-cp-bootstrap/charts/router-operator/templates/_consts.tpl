{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "router-operator.consts.appName" }}router{{ end -}}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "router-operator.consts.globalResourceName" }}{{ include "router-operator.consts.appName" . }}-{{ .Values.global.tibco.controlPlaneInstanceId }}{{ end -}}

{{/* Tenant name. */}}
{{- define "router-operator.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "router-operator.consts.component" }}tp-cp-bootstrap{{ end -}}

{{/* Team we're a part of. */}}
{{- define "router-operator.consts.team" }}cic-compute{{ end -}}

{{- define "router-operator.consts.webhook" }}router-operator-webhook{{ end -}}

{{- define "router-operator.consts.webhook.validating" }}{{ include "router-operator.consts.globalResourceName" .}}{{ end -}}

{{/* Name of the default service account */}}
{{- define "router-operator.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "router-operator.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "router-operator.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "router-operator.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "router-operator.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "router-operator.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "router-operator.consts.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "router-operator.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- .Values.global.tibco.containerRegistry.url }}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "router-operator.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "router-operator.image.registry" .) }} 
    {{- include "router-operator.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "router-operator.image.registry" .) }}
    {{- include "router-operator.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "router-operator.image.registry" .) }}
    {{- include "router-operator.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "router-operator.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set annotations for application load balancer ingress in AWS */}}
{{- define "router-operator.ingress.annotations" -}}
{{- if .Values.global.external.ingress }}
{{- if .Values.global.external.ingress.ingressClassName }}
{{- if eq .Values.global.external.ingress.ingressClassName "alb" }}
external-dns.alpha.kubernetes.io/hostname: "*.{{ .Values.global.external.dnsDomain }}"
alb.ingress.kubernetes.io/group.name: "{{ .Values.global.external.dnsDomain }}"
alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
alb.ingress.kubernetes.io/backend-protocol: HTTP
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/success-codes: 200-399
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/healthcheck-port: '88'
alb.ingress.kubernetes.io/healthcheck-path: "/health"
{{- if .Values.global.external.ingress.certificateArn }}
alb.ingress.kubernetes.io/certificate-arn: "{{ .Values.global.external.ingress.certificateArn }}"
{{- end }}
{{- else if eq .Values.global.external.ingress.ingressClassName "nginx" }}
nginx.ingress.kubernetes.io/proxy-buffer-size: 16k
{{- end }}
{{- end }}
{{- end }}
{{- end -}}