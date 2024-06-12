{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}


{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "hybrid-proxy.consts.appName" }}hybrid-proxy{{ end -}}

{{/* Tenant name. */}}
{{- define "hybrid-proxy.consts.tenantName" }}cp-core{{ end -}}

{{/* Component we're a part of. */}}
{{- define "hybrid-proxy.consts.component" }}tp-cp-bootstrap{{ end -}}

{{/* Team we're a part of. */}}
{{- define "hybrid-proxy.consts.team" }}cic-compute{{ end -}}

{{/* Use to distinguish cluster level resources and shared resources across multiple control plane instances in a cluster */}}
{{- define "hybrid-proxy.consts.globalResourceName" }}{{ include "hybrid-proxy.consts.appName" . }}-{{ .Values.global.tibco.controlPlaneInstanceId }}{{ end -}}

{{/* Name of the webhook */}}
{{- define "hybrid-proxy.consts.webhook" }}{{ include "hybrid-proxy.consts.globalResourceName" . }}{{ end -}}

{{/* Name of the default service account */}}
{{- define "hybrid-proxy.consts.serviceAccount" }}control-plane-sa{{end -}}

{{- define "hybrid-proxy.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{- define "hybrid-proxy.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "hybrid-proxy.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "hybrid-proxy.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "hybrid-proxy.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "hybrid-proxy.consts.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "hybrid-proxy.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- .Values.global.tibco.containerRegistry.url }}
  {{- end }}
{{- end -}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "hybrid-proxy.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "hybrid-proxy.image.registry" .) }} 
    {{- include "hybrid-proxy.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "hybrid-proxy.image.registry" .) }}
    {{- include "hybrid-proxy.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "hybrid-proxy.image.registry" .) }}
    {{- include "hybrid-proxy.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "hybrid-proxy.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}

{{/* set annotations for load balancer creating network load balancer in AWS */}}
{{- define "hybrid-proxy.aws.tunnelService.annotations" -}}
external-dns.alpha.kubernetes.io/hostname: "*.{{ .Values.global.external.dnsTunnelDomain }}"
service.beta.kubernetes.io/aws-load-balancer-attributes: load_balancing.cross_zone.enabled=false
service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: preserve_client_ip.enabled=true
service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
service.beta.kubernetes.io/aws-load-balancer-type: external
service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
{{- if .Values.global.external.aws }}
{{- if .Values.global.external.aws.loadBalancer }}
{{- if .Values.global.external.aws.tunnelService.certificateArn }}
service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "{{ .Values.global.external.aws.tunnelService.certificateArn }}"
{{- end }}
{{- end }}
{{- end }}
{{- end -}}