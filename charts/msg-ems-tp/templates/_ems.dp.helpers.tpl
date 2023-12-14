
{{/*
MSG DP EMS-on-FTL Helpers
#
# Copyright (c) 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{/*
need.msg.ems.params
*/}}
{{ define "need.msg.ems.params" }}
{{-  $dpParams := include "need.msg.dp.params" . | fromYaml -}}
{{-  $emsDefaultFullImage := printf "%s/%s/msg-ems-all:10.2.1-9" $dpParams.dp.registry $dpParams.dp.repo -}}
{{-  $opsDefaultFullImage := printf "%s/%s/msg-dp-ops:1.0.0-2" $dpParams.dp.registry $dpParams.dp.repo -}}
# Set EMS defaults
{{- $name := ternary .Release.Name .Values.ems.name ( not .Values.ems.name ) -}}
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
{{- $cpuReq := "0.2" -}}
{{- $cpuLim := "3" -}}
{{- $memReq := "500Mi" -}}
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
ops:
  image: {{ $opsDefaultFullImage }}
ems:
  name: {{ $name }}
  image: {{ $emsImage }}
  replicas: 3
  sizing: {{ $sizing }}
  use: {{ $use }}
  isProduction: {{ $isProduction }}
  pvcShareName: {{ $pvcShareName }}
  pvcShareSize: {{ $pvcShareSize }}
  msgData: 
    storageType: {{ $msgStorageType }}
    storageName: {{ $msgStorageName }}
    storageSize: {{ $msgStorageSize }}
  logs: 
    storageType: {{ $logStorageType }}
    storageName: {{ $logStorageName }}
    storageSize: {{ $logStorageSize }}
  skipRedeploy: "{{ .Values.ems.skipRedeploy }}"
  istioEnable: "{{ .Values.ems.istioEnable | default "false" }}"
  ports:
{{ .Values.ems.ports | toYaml | indent 4 }}
  stores: {{ $stores }}
  listens: {{ .Values.ems.listens | default $emsListens }}
  quorumStrategy: {{ $quorumStrategy }}
  isLeader: {{ printf "http://localhost:%d/isReady" ( int .Values.ems.ports.httpPort ) }}
  isInQuorum: {{ printf "http://localhost:%d/api/v1/available" ( int .Values.ems.ports.realmPort ) }}
  allowNodeSkew: "{{ .Values.ems.allowNodeSkew | default $allowNodeSkew }}"
  allowZoneSkew: "{{ .Values.ems.allowZoneSkew | default $allowZoneSkew }}"
  resources:
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
