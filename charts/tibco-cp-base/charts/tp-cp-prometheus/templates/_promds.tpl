{{/* 
   Copyright (c) 2025 Cloud Software Group, Inc.
   All Rights Reserved.

   File       : _promds.tpl
   Version    : 1.0.0
   Description: Template helpers that can be shared with other charts. 
   
    NOTES: 
      - Helpers below are making some assumptions regarding files Chart.yaml and values.yaml. Change carefully!
      - Any change in this file needs to be synchronized with all charts
*/}}

{{/*
    ===========================================================================
    SECTION: possible values for enumeration types in the global variables defined in values.yaml 
    ===========================================================================
*/}}

{{/*
    ===========================================================================
    SECTION: labels
    ===========================================================================
*/}}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "prom-ds-template" -}}
{{- if .Values.global.containerSecurityContext.prometheusds }}
securityContext:
  {{- toYaml .Values.global.containerSecurityContext.prometheusds | nindent 12 }}
{{- end }}
image: {{ include "tp-cp-prometheus.image.registry" . }}{{"/"}}{{ include "tp-cp-prometheus-ds.image.repository" . }}{{"/"}}{{ .Values.server.sidecarTemplateValues.image.name }}:{{ .Values.server.sidecarTemplateValues.image.tag }}
imagePullPolicy: {{ .Values.server.sidecarTemplateValues.image.pullPolicy }}
#image: "{{ .Values.server.sidecarTemplateValues.repository }}"
#imagePullPolicy: IfNotPresent
{{- if .Values.global.cp.enableResourceConstraints }}
{{- with .Values.global.resources.prometheusds }}
resources:
  {{- toYaml . | nindent 12 }}
{{- end }}
{{- end }}
# Liveness and Readiness probe setting for Prometheus DS container
livenessProbe:
{{- toYaml .Values.server.sidecarTemplateValues.promDSLivenessProbe | nindent 12 }}
readinessProbe:
{{- toYaml .Values.server.sidecarTemplateValues.promDSReadinessProbe | nindent 12 }}
ports:
  - containerPort: 9000
    name: prometheus-ds
env:
  - name: hawkconsole_target_input_file
    value: /etc/prometheus-discovery/hawkconsoletargets.json
  - name: rest_api_server_port
    value: "9000"
  - name: target_output_file
    value: /etc/prometheus-discovery/metrictargets.json
  - name: be_target_output_file
    value: /etc/prometheus-discovery/be_metrictargets.json
  - name: bw5_target_output_file
    value: /etc/prometheus-discovery/bw5_metrictargets.json
  - name: sys_target_output_file
    value: /etc/prometheus-discovery/sys_metrictargets.json
  - name: ems_target_output_file
    value: /etc/prometheus-discovery/ems_metrictargets.json
  - name: log_level
    value: DEBUG
  - name: metric_auth_token
    valueFrom:
      secretKeyRef:
        name: metric-token-query-secret-1
        key: metric_auth_token
  - name: TP_DP_PROXY_HOST
    valueFrom:
      configMapKeyRef:
        name: {{ include "tp-control-plane-dnsdomain-configmap" . }}
        key: TP_DP_PROXY_HOST
volumeMounts:
  - name: server-ds-vol
    mountPath: /etc/prometheus-discovery
    readOnly: false
    subPath: hawk/discovery
{{- end -}}

