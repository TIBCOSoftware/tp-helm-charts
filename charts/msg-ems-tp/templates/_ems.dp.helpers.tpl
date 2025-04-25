
{{/*
MSGDP EMS Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{/*
need.msg.ems.params
*/}}
{{ define "need.msg.ems.params" }}
{{-  $dpParams := include "need.msg.dp.params" . | fromYaml -}}
# FIXME: MSGDP-636: PIN until EMS K8s provisioning supports an activationUrl
{{-  $emsDefaultFullImage := printf "%s/%s/msg-ems-all:10.4.0-68" $dpParams.dp.registry $dpParams.dp.repo -}}
#{-  $emsDefaultFullImage := printf "%s/%s/msg-ems-all:10.4.0-56" $dpParams.dp.registry $dpParams.dp.repo -}}
# Set EMS defaults
{{- $name := ternary .Release.Name .Values.ems.name ( not .Values.ems.name ) -}}
{{- $namespace := .Values.namespace | default .Release.Namespace -}}
{{- $sizing := ternary  "small" .Values.ems.sizing ( not  .Values.ems.sizing ) -}}
{{- $use := ternary  "dev" .Values.ems.use ( not  .Values.ems.use ) -}}
{{- $tcpListen := printf "tcp://0.0.0.0:%d" ( .Values.ems.ports.tcpPort | int ) -}}
{{- $sslListen := printf "ssl://0.0.0.0:%d" ( .Values.ems.ports.sslPort | int ) -}}
{{- $emsListens := $tcpListen -}}
  {{- if and .Values.ems.tcpEnable .Values.ems.sslEnable -}}
    {{- $emsListens = printf "%s,%s" $tcpListen $sslListen -}}
  {{- else if .Values.ems.tcpEnable -}}
    {{- $emsListens = $tcpListen -}}
  {{- else if .Values.ems.sslEnable -}}
    {{- $emsListens = $sslListen -}}
  {{- else -}}
    {{- fail "ERROR: at least one of TCP or SSL listen must be enabled." -}}
  {{- end -}}
{{- $isProduction := false -}}
{{- $cpuReq := "0.3" -}}
{{- $cpuLim := "3" -}}
{{- $memReq := "1Gi" -}}
{{- $memLim := "4Gi" -}}
{{- $stores := ternary "ftl" .Values.ems.stores ( not .Values.ems.stores ) -}}
{{- $allowNodeSkew := "yes" -}}
{{- $allowZoneSkew := "yes" -}}
{{ $emsImage := ternary $emsDefaultFullImage .Values.ems.image ( not .Values.ems.image ) }}
{{ $quorumStrategy := ternary "quorum-based" .Values.ems.quorumStrategy ( not .Values.ems.quorumStrategy ) }}
{{ $msgStorageType := "emptyDir" }}
{{ $msgStorageName := "none" }}
{{ $msgStorageSize :=  "4Gi" }}
{{ $dpCreateSharedPvc := "no" }}
{{ $logStorageType := "useMsgData" }}
{{ $logStorageName := "none" }}
{{ $logStorageSize :=  "4Gi" }}
{{ $pvcShareName :=  "none" }}
{{ $pvcShareSize :=  $logStorageSize }}
  {{- if eq $sizing "medium" -}}
    {{- $msgStorageSize = "25Gi" -}}
    {{- $logStorageSize = "10Gi" -}}
    {{- $cpuReq = "1.0" -}}
    {{- $cpuLim = "5" -}}
    {{- $memReq = "2Gi" -}}
    {{- $memLim = "8Gi" -}}
  {{- else if eq $sizing "large" -}}
    {{- $msgStorageSize = "50Gi" -}}
    {{- $logStorageSize = "25Gi" -}}
    {{- $cpuReq = "2" -}}
    {{- $cpuLim = "8" -}}
    {{- $memReq = "8Gi" -}}
    {{- $memLim = "20Gi" -}}
  {{- else if eq $sizing "xlarge" -}}
    {{- $msgStorageSize = "100Gi" -}}
    {{- $logStorageSize = "100Gi" -}}
    {{- $cpuReq = "4" -}}
    {{- $cpuLim = "16" -}}
    {{- $memReq = "16Gi" -}}
    {{- $memLim = "30Gi" -}}
  {{- else if ne $sizing "small" -}}
    {{- $sizeError := printf "Config error, size of %s not supported. " $sizing -}}
    {{- fail $sizeError -}}
  {{ end }}
  {{- if $isProduction -}}
    {{- $cpuReq = $cpuLim -}}
    {{- $memReq = $memLim -}}
    {{- $allowNodeSkew = "no" -}}
    {{- $allowZoneSkew = "no" -}}
  {{ end }}
{{ $pvcShareSize :=  $logStorageSize }}
  {{ if .Values.ems.msgData }}
    {{ $msgStorageType = ternary  $msgStorageType .Values.ems.msgData.storageType ( not  .Values.ems.msgData.storageType ) }}
    {{ $msgStorageName = ternary  $msgStorageName .Values.ems.msgData.storageName ( not  .Values.ems.msgData.storageName ) }}
    {{ $msgStorageSize = ternary  $msgStorageSize .Values.ems.msgData.storageSize ( not  .Values.ems.msgData.storageSize ) }}
  {{ end }}
  {{ if .Values.ems.logs }}
    {{ $logStorageType = ternary  $logStorageType .Values.ems.logs.storageType ( not  .Values.ems.logs.storageType ) }}
    {{ $logStorageName = ternary  $logStorageName .Values.ems.logs.storageName ( not  .Values.ems.logs.storageName ) }}
    {{ $logStorageSize = ternary  $logStorageSize .Values.ems.logs.storageSize ( not  .Values.ems.logs.storageSize ) }}
  {{ end }}
  {{ if eq "sharedStorageClass" $logStorageType }}
    {{ $dpCreateSharedPvc = "yes" }}
    {{ $logStorageType = "sharedPvc" }}
    {{ $pvcShareName = ( printf "%s-share" $name ) }}
    {{ $logStorageName = $pvcShareName }}
  {{ end }}
  {{ if eq "sharedStorageClass" $msgStorageType }}
    {{ $dpCreateSharedPvc = "yes" }}
    {{ $msgStorageType = "sharedPvc" }}
    {{ $pvcShareName = ( printf "%s-share" $name ) }}
    {{ $msgStorageName = $pvcShareName }}
    {{ $pvcShareSize :=  $logStorageSize }}
  {{ end }}
# Fill in $emsParams yaml
{{ include "need.msg.dp.params" . }}
ems:
  name: {{ $name }}
  namespace: {{ $namespace }}
  image: {{ $emsImage }}
  sizing: {{ $sizing }}
  activationUrl: "{{ .Values.ems.activationUrl }}"
  use: {{ $use }}
  isProduction: {{ $isProduction }}
  pvcShareName: {{ $pvcShareName }}
  pvcShareSize: {{ $pvcShareSize }}
  msgData: 
    volName: ems-data
    storageType: {{ $msgStorageType }}
    storageName: {{ $msgStorageName }}
    storageSize: {{ $msgStorageSize }}
  logs: 
    volName: ems-logs
    storageType: {{ $logStorageType }}
    storageName: {{ $logStorageName }}
    storageSize: {{ $logStorageSize }}
  boot:
    volName: scripts-vol
    storageType: configMap
    storageName: {{ $name }}-scripts
    readOnly: true
  certs:
    volName: certs-vol
    storageType: secret
    storageName: {{ $name }}-certs
    readOnly: true
  params:
    volName: config-vol
    storageType: configMap
    storageName: {{ $name }}-params
    readOnly: true
  toolsetData:
    volName: toolset-data
    storageType: emptyDir
    storageName: none
  toolset:
    volName: toolset-vol
    storageType: emptyDir
    storageName: none
  skipRedeploy: "{{ .Values.ems.skipRedeploy }}"
  istioEnable: "{{ .Values.ems.istioEnable | default "false" }}"
  allowNodeSkew: "{{ .Values.ems.allowNodeSkew | default $allowNodeSkew }}"
  allowZoneSkew: "{{ .Values.ems.allowZoneSkew | default $allowZoneSkew }}"
  resources:
    {{ if $dpParams.dp.enableResourceConstraints }}
    {{ if .Values.ems.resources }}
{{ .Values.ems.resources | toYaml | indent 4 }}
    {{ else }}
    requests:
      memory: {{ $memReq }}
      cpu: {{ $cpuReq }}
    limits:
      memory: {{ $memLim }}
      cpu: {{ $cpuLim }}
    {{ end }}
    {{ end }}
  # Computed settings below, not intended for user changes
  # use -pods instead of -headless to avoid reducing STS name size
  stsname: "{{ $name }}-ems"
  headless: "{{ $name }}-ems-pods"
  headlessDomain: "{{ $name }}-ems-pods.{{ $namespace }}.svc"
  ftl_spin: "{{ .Values.ems.ftl_spin | default "disabled" }}"
  replicas: 3
  ports:
{{ .Values.ems.ports | toYaml | indent 4 }}
  stores: {{ $stores }}
  listens: {{ .Values.ems.listens | default $emsListens }}
  quorumStrategy: {{ $quorumStrategy }}
  isLeader: {{ printf "http://localhost:%d/isReady" ( int .Values.ems.ports.httpPort ) }}
  isInQuorum: {{ printf "http://localhost:%d/api/v1/available" ( int .Values.ems.ports.realmPort ) }}
toolset:
  lbHost: "nlbNameHere"
  enableIngress: true
  resources:
    {{ if $dpParams.dp.enableResourceConstraints }}
    {{ if and .Values.toolset .Values.toolset.resources }}
{{ .Values.toolset.resources | toYaml | indent 4 }}
    {{ else }}
    requests:
      memory: "0.5Gi"
      cpu: "0.1"
    limits:
      memory: "4Gi"
      cpu: "3"
    {{ end }}
    {{ end }}
job:
  resources:
    {{ if $dpParams.dp.enableResourceConstraints }}
    {{ if and .Values.job .Values.job.resources }}
{{ .Values.job.resources | toYaml | indent 4 }}
    {{ else }}
    requests:
      memory: "0.5Gi"
      cpu: "0.1"
    limits:
      memory: "1Gi"
      cpu: "1"
    {{ end }}
    {{ end }}
securityProfile: "{{ .Values.ems.securityProfile | default "ems" }}"
{{ end }}

{{/*
ems.std.labels prints the standard EMS group Helm labels.
note: expects a $emsParams as its argument
*/}}
{{- define "ems.std.labels" }}
release: "{{ .dp.release }}"
tib-dp-app: msg-ems-ftl
tib-msg-group-name: "{{ .ems.name }}"
tib-msg-ems-name: "{{ .ems.name }}"
tib-msg-ems-sizing: "{{ .ems.sizing }}"
tib-msg-ems-use: "{{ .ems.use }}"
app.kubernetes.io/name: "ems"
platform.tibco.com/app-type: "msg-ems"
app.kubernetes.io/part-of: "{{ .ems.name }}"
platform.tibco.com/app.resources.requests.cpu: {{ if and .ems.resources .ems.resources.requests -}} {{ .ems.resources.requests.cpu | default "100m" | quote }} {{- else -}} "100m" {{- end }}
platform.tibco.com/app.resources.requests.memory: {{ if and .ems.resources .ems.resources.requests -}}  {{ .ems.resources.requests.memory | default "128Mi" | quote }} {{- else -}} "128Mi" {{- end }}
platform.tibco.com/app.resources.limits.cpu: {{ if and .ems.resources .ems.resources.limits -}}  {{ .ems.resources.limits.cpu | default "3" | quote }} {{- else -}} "3" {{- end }}
platform.tibco.com/app.resources.limits.memory: {{ if and .ems.resources .ems.resources.limits -}} {{ .ems.resources.limits.memory | default "4Gi" | quote }} {{- else -}} "4Gi" {{- end }}
{{- end }}
