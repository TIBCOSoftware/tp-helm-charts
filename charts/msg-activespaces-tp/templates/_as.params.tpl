
{{/*
MSGDP Activespaces Helpers
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
*/}}

{{/* msg.as.basename */}}
{{ define "msg.as.basename" }}
{{- default "tp-as" .Values.as.basename -}}
{{- end -}}

{{/* usage: msg.as.labels $params */}}
{{ define "msg.as.labels" }}
{{ include "msg.dpparams.labels" . }}
tib-msg-group-name: {{ .as.basename }}
app.kubernetes.io/component: msg-activespaces
{{ end }}

{{/*
need.msg.as.params
*/}}
{{ define "need.msg.as.params" }}
{{- $dpParams := include "need.msg.dp.params" . | fromYaml -}}
{{- $asDefaultFullImage := printf "%s/%s/msg-as-all:5.2.0-3" $dpParams.dp.registry $dpParams.dp.repository -}}
{{- $k8bashDefaultFullImage := printf "%s/%s/msg-ubu-k8bash:24.04.0-21" $dpParams.dp.registry $dpParams.dp.repository -}}
{{- $basename :=  .Values.as.basename | default "tp-as" -}}
{{- $numCopysets :=  .Values.as.numCopysets | default 1 -}}
{{- $numProxies :=  .Values.as.numProxies | default 2 -}}
{{- $isProduction :=  false -}}
{{- if hasKey .Values.as "isProduction" -}}
  {{- $isProduction = .Values.as.isProduction -}}
{{- end -}}
{{- $useCompact :=  true -}}
{{- if eq .Values.as.useCompact false -}}
  {{- $useCompact = false -}}
{{- else if  gt ( int $numCopysets) 1 -}}
  {{- $useCompact =  false -}}
{{- else if  gt (int $numProxies)  2 -}}
    {{- $useCompact =  false -}}
{{- end -}}
#
{{ include "need.msg.dp.params" . }}
as:
  basename: "{{ include "msg.as.basename" . }}"
  image: "{{ .Values.as.image | default $asDefaultFullImage }}"
  kubectlImage: "{{ .Values.as.kubectlImage | default $k8bashDefaultFullImage }}"
  numCopysets: {{ $numCopysets }}
  numProxies: {{ $numProxies }}
  useCompact: {{ $useCompact }}
  forceBootUpgrade: {{ .Values.as.forceBootUpgrade | default "force" }}
  usePodStats: {{ .Values.as.usePodStats | default "yes" | quote }}
  isProduction: {{ $isProduction }}
  zoneLabel: {{ .Values.as.zoneLabel | default "topology.kubernetes.io/zone" }}
  ports:
    watchdogPort: 12502
    loggerPort: 12506
    core: 30080
  # Volumes
  boot:
    volName: boot-vol
    storageType: configMap
    storageName: {{ $basename }}-boot
    readOnly: true
    defaultMode: 0777
  msgData: 
    volName: data
    storageType: "{{ .Values.as.msgData.storageType | default "storageClass" }}"
    storageName: "{{ .Values.as.msgData.storageName | default "" }}"
    storageSize: {{ .Values.as.msgData.storageSize | default "4Gi" }}
  conf:
    volName: conf-vol
    storageType: secret
    storageName: {{ $basename }}-conf
    readOnly: true
  coreData: 
    volName: coredata
    storageType: "{{ .Values.as.coreData.storageType | default .Values.as.msgData.storageType | default "storageClass"}}"
    storageName: "{{ .Values.as.coreData.storageName | default .Values.as.msgData.storageName | default "" }}"
{{- if $useCompact }}
    storageSize: {{ .Values.as.msgData.storageSize | default "4Gi" }}
{{- else }}
    storageSize: {{ .Values.as.coreData.storageSize | default "4Gi" }}
{{- end }}
  logs: 
    volName: logs
    storageType: "{{ .Values.as.logs.storageType | default "emptyDir" }}"
    storageName: "{{ .Values.as.logs.storageName | default "none" }}"
    storageSize: {{ .Values.as.logs.storageSize | default "4Gi" }}
securityProfile: "{{ .Values.securityProfile | default "pss-restrictive" }}"
core:
  resources:
  {{ if .Values.core.resources }}
{{ .Values.core.resources | toYaml | indent 4 }}
  {{ else if .Values.ftlserver.resources }}
{{ .Values.ftlserver.resources | toYaml | indent 4 }}
  {{ else if $isProduction }}
    limits: {"memory": "6.0Gi", "cpu": "6"}
    requests: {"memory": "6.0Gi", "cpu": "6"}
  {{ else if $useCompact }}
    limits: {"memory": "5.0Gi", "cpu": "4"}
    requests: {"memory": "1.0Gi", "cpu": "400m"}
  {{ else }}
    limits: {"memory": "3.0Gi", "cpu": "3"}
    requests: {"memory": "1.0Gi", "cpu": "400m"}
  {{ end }}
node:
  resources:
  {{ if .Values.node.resources }}
{{ .Values.node.resources | toYaml | indent 4 }}
  {{ else if $isProduction }}
    limits: {"memory": "5.0Gi", "cpu": "4"}
    requests: {"memory": "5.0Gi", "cpu": "4"}
  {{ else }}
    limits: {"memory": "3.0Gi", "cpu": "3"}
    requests: {"memory": "1.0Gi", "cpu": "100m"}
  {{ end }}
proxy:
  resources:
  {{ if .Values.proxy.resources }}
{{ .Values.proxy.resources | toYaml | indent 4 }}
  {{ else if $isProduction }}
    limits: {"memory": "3.0Gi", "cpu": "3"}
    requests: {"memory": "3.0Gi", "cpu": "3"}
  {{ else }}
    limits: {"memory": "2.0Gi", "cpu": "2"}
    requests: {"memory": "512Mi", "cpu": "100m"}
  {{ end }}
job:
  resources:
  {{ if and .Values.job .Values.job.resources }}
{{ .Values.job.resources | toYaml | indent 4 }}
  {{ else if $isProduction }}
    limits: {"memory": "1.0Gi", "cpu": "1"}
    requests: {"memory": "1.0Gi", "cpu": "1"}
  {{ else }}
    limits: {"memory": "1.0Gi", "cpu": "1"}
    requests: {"memory": "512Mi", "cpu": "100m"}
  {{ end }}
{{ end }}


{{/*
as.prom.o11y.annotations 
*/}}
{{- define "as.prom.o11y.annotations" }}
prometheus.io/scrape: "true"
prometheus.io/port: "{{ .as.ports.core }}"
prometheus.io/scheme: "http"
prometheus.io/path: /metrics
prometheus.io/insecure_skip_verify: "true"
{{- end }}

{{/*
as.prom.o11y.labels 
*/}}
{{- define "as.prom.o11y.labels" }}
platform.tibco.com/scrape_o11y: "true"
prometheus.io/scrape: "true"
prometheus.io/port: "{{ .as.ports.core }}"
{{- end }}
