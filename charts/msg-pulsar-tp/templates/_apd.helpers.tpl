
{{/*
MSGDP Pulsar (aka. Quasar, APD) Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{/*
need.msg.apd.params
*/}}
{{ define "need.msg.apd.params" }}
#
{{-  $dpParams := include "need.msg.dp.params" . | fromYaml -}}
#
{{-  $apdDefaultFullImage := printf "%s/%s/msg-pulsar-all:3.0.2-36" $dpParams.dp.registry $dpParams.dp.repo -}}
{{-  $opsDefaultFullImage := printf "%s/%s/msg-tp-ops:1.2.0-4" $dpParams.dp.registry $dpParams.dp.repo -}}
{{-  $apdDefaultImageTag := "3.0.2-36" -}}
# Set APD defaults
{{- $apdImage := ternary $apdDefaultFullImage .Values.apd.image ( not .Values.apd.image ) -}}
{{- $name := ternary .Release.Name .Values.apd.name ( not .Values.apd.name ) -}}
{{- $sizing := ternary  "small" .Values.apd.sizing ( not  .Values.apd.sizing ) -}}
{{- $use := ternary  "dev" .Values.apd.use ( not  .Values.apd.use ) -}}
{{- $isProduction := false -}}
{{- $allowNodeSkew := "yes" -}}
{{- $allowZoneSkew := "yes" -}}
{{- $msgStorageType := .Values.apd.msgData.storageType | default "emptyDir" -}}
{{- $msgStorageName := "none" -}}
{{- $msgStorageSize :=  "4Gi" -}}
{{- $dpCreateSharedPvc := "no" -}}
{{- $logStorageType := .Values.apd.logs.storageType | default "use-pulsar-data" -}}
{{- $logStorageName := "none" -}}
{{- $logStorageSize :=  "4Gi" -}}
{{- $logSubPathExpr :=  "$(MY_RELEASE)/$(MY_POD_NAME)/pulsar-logs" -}}
{{- $walStorageType := .Values.apd.journal.storageType | default "use-pulsar-data" -}}
{{- $walStorageName := "none" -}}
{{- $walStorageSize :=  "4Gi" -}}
{{- $pvcShareName :=  "none" -}}
{{- $scSharedName :=  $dpParams.dp.scSharedName | default "none" -}}
{{- $pvcShareSize :=  $logStorageSize -}}
  {{- if eq "small" $sizing -}}
    {{- $msgStorageSize =  "2Gi" -}}
    {{- $walStorageSize =  "2Gi" -}}
  {{- else if eq "medium" $sizing -}}
    {{- $msgStorageSize =  "10Gi" -}}
    {{- $walStorageSize =  "4Gi" -}}
  {{- else if eq "large" $sizing -}}
    {{- $msgStorageSize =  "20Gi" -}}
    {{- $walStorageSize =  "10Gi" -}}
  {{- else if eq "xlarge" $sizing -}}
    {{- $msgStorageSize =  "50Gi" -}}
    {{- $walStorageSize =  "10Gi" -}}
  {{- else -}}
    {{- $sizeError := printf "Config error, size of %s not supported. " $sizing -}}
    {{- fail $sizeError -}}
  {{- end -}}
  {{- if .Values.apd.isProduction -}}
    {{- $isProduction = true -}}
    {{- $allowNodeSkew = "no" -}}
    {{- $allowZoneSkew = "no" -}}
  {{- end -}}
  {{- if .Values.apd.msgData -}}
    {{- $msgStorageType = ternary  $msgStorageType .Values.apd.msgData.storageType ( not  .Values.apd.msgData.storageType ) -}}
    {{- $msgStorageName = ternary  $msgStorageName .Values.apd.msgData.storageName ( not  .Values.apd.msgData.storageName ) -}}
    {{- $msgStorageSize = ternary  $msgStorageSize .Values.apd.msgData.storageSize ( not  .Values.apd.msgData.storageSize ) -}}
  {{- end -}}
  {{- if .Values.apd.logs -}}
    {{- $logStorageType = ternary  $logStorageType .Values.apd.logs.storageType ( not  .Values.apd.logs.storageType ) -}}
    {{- $logStorageName = ternary  $logStorageName .Values.apd.logs.storageName ( not  .Values.apd.logs.storageName ) -}}
    {{- $logStorageSize = ternary  $logStorageSize .Values.apd.logs.storageSize ( not  .Values.apd.logs.storageSize ) -}}
    {{- $logSubPathExpr = ternary  $logSubPathExpr .Values.apd.logs.subPathExpr ( not  .Values.apd.logs.subPathExpr ) -}}
  {{- end -}}
  {{- if .Values.apd.journal -}}
    {{- $walStorageType = ternary  $walStorageType .Values.apd.journal.storageType ( not  .Values.apd.journal.storageType ) -}}
    {{- $walStorageName = ternary  $walStorageName .Values.apd.journal.storageName ( not  .Values.apd.journal.storageName ) -}}
    {{- $walStorageSize = ternary  $walStorageSize .Values.apd.journal.storageSize ( not  .Values.apd.journal.storageSize ) -}}
  {{- end -}}
  {{- if eq "sharedStorageClass" $msgStorageType -}}
    {{- $scSharedName = $msgStorageName -}}
    {{- $dpCreateSharedPvc = "yes" -}}
    {{- $msgStorageType = "sharedPvc" -}}
    {{- $pvcShareName = ( printf "%s-share" $name ) -}}
    {{- $msgStorageName = $pvcShareName -}}
    {{- $pvcShareSize :=  $logStorageSize -}}
  {{- end -}}
  {{- if eq "sharedStorageClass" $logStorageType -}}
    {{- $scSharedName = $logStorageName -}}
    {{- $dpCreateSharedPvc = "yes" -}}
    {{- $logStorageType = "sharedPvc" -}}
    {{- $pvcShareName = ( printf "%s-share" $name ) -}}
    {{- $logStorageName = $pvcShareName -}}
  {{- end -}}
# Fill in $apdParams yaml
{{ include "need.msg.dp.params" . }}
ops:
  image: {{ $opsDefaultFullImage }}
apd:
  name: {{ $name }}
  imageFullName: {{ $apdImage }}
  imageTag: {{ .Values.defaultPulsarImageTag | default $apdDefaultImageTag }}
  sizing: {{ $sizing }}
  use: {{ $use }}
  isProduction: {{ $isProduction }}
  scSharedName: {{ $scSharedName }}
  pvcShareName: {{ $pvcShareName }}
  pvcShareSize: {{ $pvcShareSize }}
  msgData: 
    volName: {{ .Values.apd.msgData.volName | default "pulsar-data" }}
    storageType: {{ $msgStorageType }}
    storageName: {{ $msgStorageName }}
    storageSize: {{ $msgStorageSize }}
  logs: 
    volName: {{ .Values.apd.logs.volName | default "pulsar-logs" }}
    storageType: {{ $logStorageType }}
    storageName: {{ $logStorageName }}
    storageSize: {{ $logStorageSize }}
    subPathExpr: {{ $logSubPathExpr }}
  conf: 
    # NOTE: no new msg.pv.vol.def used
    volName: "pulsar-conf"
    storageName: {{ $logStorageName }}
    subPathExpr: "$(MY_RELEASE)/$(MY_POD_NAME)/pulsar-conf"
      {{- if eq "use-pulsar-data" $logStorageType }}
    storageType: "use-pulsar-data"
      {{- else if eq "sharedPvc" $logStorageType }}
    storageType: "sharedPvc"
      {{- else }}
    storageType: "use-pulsar-logs"
      {{- end }}
  journal: 
    volName: {{ .Values.apd.journal.volName | default "pulsar-wal" }}
    storageType: {{ $walStorageType }}
    storageName: {{ $walStorageName }}
    storageSize: {{ $walStorageSize }}
  boot:
    volName: scripts-vol
    storageType: configMap
    storageName: {{ $name }}-scripts
    readOnly: true
  log4j2:
    volName: log4j2-vol
    storageType: configMap
    storageName: {{ $name }}-conf
    subPath: "log4j2.yaml"
    readOnly: true
  vartmp:
    volName: vartmp
    storageType: emptyDir
    readOnly: false
    permissions:
      mode: "1777"
  params:
    volName: config-vol
    storageType: configMap
    storageName: {{ $name }}-params
    readOnly: true
  toolsetData:
    volName: toolset-data
    storageType: emptyDir
    storageName: none
  skipRedeploy: "{{ .Values.apd.skipRedeploy }}"
  allowNodeSkew: "{{ .Values.apd.allowNodeSkew | default $allowNodeSkew }}"
  allowZoneSkew: "{{ .Values.apd.allowZoneSkew | default $allowZoneSkew }}"
  ports:
{{ .Values.apd.ports | toYaml | indent 4 }}
  # Allow some component specific overrides
  zoo:
    serviceAccount: {{ .Values.apd.zoo.serviceAccount | default $dpParams.dp.serviceAccount }}
    resources: {}
  bookie:
    serviceAccount: {{ .Values.apd.bookie.serviceAccount | default $dpParams.dp.serviceAccount }}
    resources: {}
  broker:
    serviceAccount: {{ .Values.apd.broker.serviceAccount | default $dpParams.dp.serviceAccount }}
    resources: {}
  proxy:
    serviceAccount: {{ .Values.apd.proxy.serviceAccount | default $dpParams.dp.serviceAccount }}
    resources: {}
  recovery:
    serviceAccount: {{ .Values.apd.recovery.serviceAccount | default $dpParams.dp.serviceAccount }}
    resources: {}
  toolset:
    serviceAccount: {{ .Values.apd.toolset.serviceAccount | default $dpParams.dp.serviceAccount }}
    resources: {}
toolset:
  lbHost: "nlbNameHere"
  enableIngress: true
securityProfile: "{{ .Values.apd.securityProfile | default "pulsar" }}"
{{ end }}

{{/*
apd.std.labels prints the standard Pulsar group Helm labels.
note: expects a $apdParams as its argument
*/}}
{{- define "apd.std.labels" }}
tib-dp-app: msg-apd
release: "{{ .dp.release }}"
tib-msg-group-name: "{{ .apd.name }}"
tib-msg-apd-name: "{{ .apd.name }}"
tib-msg-apd-sizing: "{{ .apd.sizing }}"
tib-msg-apd-use: "{{ .apd.use }}"
platform.tibco.com/app-type: "msg-pulsar"
{{- end }}
