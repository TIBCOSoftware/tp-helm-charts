
{{/*
MSG DP Common Helpers
#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{- define "msgdp.ghcrImageRepo" -}}"tibco/msg-platform-cicd"{{ end }}
{{- define "msgdp.jfrogImageRepo" -}}"tibco-platform-local-docker/msg"{{ end }}
{{- define "msgdp.ecrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.acrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.reldockerImageRepo" -}}"messaging"{{ end }}
{{- define "msgdp.defaultImageRepo" -}}"messaging"{{ end }}

{{/*
need.msg.dp.params
*/}}
{{ define "need.msg.dp.params" }}
  # Reference for global.cp attributes : 
  #   https://confluence.tibco.com/x/uoBUEQ
  # Use TCM testbed defaults for now
  {{- $where := "local" -}}
  {{- $name := "dp-noname" -}}
  {{- $pullSecret := "cic2-tcm-ghcr-secret" -}}
  {{- $registry := "ghcr.io" -}}
  {{- $repo := include "msgdp.ghcrImageRepo" . -}}
  {{- $pullPolicy := "IfNotPresent" -}}
  {{- $serviceAccount := "provisioner" -}}
  {{- $scSharedName := "none" -}}
  # These 4 are currently unused!
  {{- $cpHostname := "no-cpHostname" -}}
  {{- $instanceId := "no-instanceId" -}}
  {{- $environmentType := "no-environmentType" -}}
  {{- $subscriptionId := "no-subscriptionId" -}}
  {{- if .Values.global -}}
    {{- if .Values.global.cp -}}
      {{- $name = ternary  $name .Values.global.cp.dataplaneId ( not  .Values.global.cp.dataplaneId ) -}}
      {{- $serviceAccount = ternary  $serviceAccount  .Values.global.cp.serviceAccount ( not  .Values.global.cp.serviceAccount ) -}}
      {{- $pullPolicy = ternary  $pullPolicy  .Values.global.cp.pullPolicy ( not  .Values.global.cp.pullPolicy ) -}}
        {{- if .Values.global.cp.containerRegistry -}}
          {{- $registry = ternary  $registry  .Values.global.cp.containerRegistry.url ( not  .Values.global.cp.containerRegistry.url ) -}}
          {{- if .Values.global.cp.containerRegistry.repo -}}
            {{- $repo = .Values.global.cp.containerRegistry.repo -}}
          {{- else if contains "ghcr.io" $registry -}}
            {{- $repo = "tibco/msg-platform-cicd" -}}
            {{- $pullSecret = "cic2-tcm-ghcr-secret" -}}
          {{- else if contains "jfrog.io" $registry -}}
            {{- $repo = include "msgdp.jfrogImageRepo" . -}}
          {{- else if contains "amazonaws.com" $registry -}}
            {{- $repo = include "msgdp.ecrImageRepo" . -}}
          {{- else if contains "azurecr.io" $registry -}}
            {{- $repo = include "msgdp.acrImageRepo" . -}}
          {{- else if contains "reldocker.tibco.com" $registry -}}
            {{- $repo = include "msgdp.reldockerImageRepo" . -}}
          {{- else -}}
            {{- $repo = include "msgdp.defaultImageRepo" . -}}
          {{- end -}}
          {{- $pullSecret = ternary  $pullSecret  .Values.global.cp.containerRegistry.secret ( not  .Values.global.cp.containerRegistry.secret ) -}}
        {{- end -}}
      {{- $cpHostname = ternary  $cpHostname .Values.global.cp.cpHostname ( not  .Values.global.cp.cpHostname ) -}}
      {{- $instanceId = ternary  $instanceId .Values.global.cp.instanceId ( not  .Values.global.cp.instanceId ) -}}
      {{- $environmentType = ternary  $environmentType .Values.global.cp.environmentType ( not  .Values.global.cp.environmentType ) -}}
      {{- $subscriptionId = ternary  $subscriptionId .Values.global.cp.subscriptionId ( not  .Values.global.cp.subscriptionId ) -}}
        {{- if .Values.global.cp.resources -}}
        {{- if .Values.global.cp.resources.serviceaccount -}}
        {{- if .Values.global.cp.resources.serviceaccount.serviceAccountName -}}
          {{- $serviceAccount =  .Values.global.cp.resources.serviceaccount.serviceAccountName | default  $serviceAccount -}}
        {{- end -}}
        {{- end -}}
        {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.ems -}}
    {{- if .Values.ems.logs -}}
      {{- if .Values.ems.logs.storageType -}}
      {{- if eq "sharedStorageClass" .Values.ems.logs.storageType -}}
        {{- $scSharedName = .Values.ems.logs.storageName -}}
      {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- if .Values.ems.msgData -}}
      {{- if .Values.ems.msgData.storageType -}}
      {{- if eq "sharedStorageClass" .Values.ems.msgData.storageType -}}
        {{- $scSharedName = .Values.ems.msgData.storageName -}}
      {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if .Values.dp -}}
    {{- $name = ternary  $name  .Values.dp.name ( not  .Values.dp.name ) -}}
    {{- $pullSecret = ternary  $pullSecret  .Values.dp.pullSecret ( not  .Values.dp.pullSecret ) -}}
    {{- $registry = ternary  $registry  .Values.dp.registry ( not  .Values.dp.registry ) -}}
    {{- $repo = ternary  $repo  .Values.dp.repo ( not  .Values.dp.repo ) -}}
    {{- $pullPolicy = ternary  $pullPolicy  .Values.dp.pullPolicy ( not  .Values.dp.pullPolicy ) -}}
    {{- $serviceAccount = ternary  $serviceAccount  .Values.dp.serviceAccount ( not  .Values.dp.serviceAccount ) -}}
    {{- $scSharedName = ternary  $scSharedName  .Values.dp.scSharedName ( not  .Values.dp.scSharedName ) -}}
    {{- $cpHostname = ternary  $cpHostname  .Values.dp.cpHostname ( not  .Values.dp.cpHostname ) -}}
    {{- $environmentType = ternary  $environmentType  .Values.dp.environmentType ( not  .Values.dp.environmentType ) -}}
    {{- $instanceId = ternary  $instanceId  .Values.dp.instanceId ( not  .Values.dp.instanceId ) -}}
    {{- $subscriptionId = ternary  $subscriptionId  .Values.dp.subscriptionId ( not  .Values.dp.subscriptionId ) -}}
  {{- end -}}
#
dp:
  uid: 0
  gid: 0
  where: {{ $where }}
  name: {{ $name }}
  pullSecret: {{ $pullSecret }}
  registry: {{ $registry }}
  repo: {{ $repo }}
  pullPolicy: {{ $pullPolicy }}
  serviceAccount: {{ $serviceAccount }}
  cpHostname: {{ $cpHostname }}
  instanceId: {{ $instanceId }}
  environmentType: {{ $environmentType }}
  subscriptionId: {{ $subscriptionId }}
  scSharedName: {{ $scSharedName }}
{{- end }}

{{/*
msg.dp.mon.annotations adds
note: tib-msg-stsname will be added directly in statefulset charts, as it needs to be the pod match label
*/}}
{{- define "msg.dp.mon.annotations" }}
{{-  $dpParams := include "need.msg.dp.params" . | fromYaml }}
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: "{{ $dpParams.dp.name }}"
platform.tibco.com/cpHostname: "{{ $dpParams.dp.cpHostname }}"
platform.tibco.com/environmentType: "{{ $dpParams.dp.environmentType }}"
platform.tibco.com/capability-instance-id: "{{ $dpParams.dp.instanceId | default .Release.Name }}"
{{ end }}

{{/*
msg.dp.labels prints the standard dataplane Helm labels.
note: tib-msg-stsname will be added directly in statefulset charts, as it needs to be the pod match label
*/}}
{{- define "msg.dp.labels" }}
{{-  $dpParams := include "need.msg.dp.params" . | fromYaml }}
tib-dp-release: {{ .Release.Name | quote }}
tib-dp-msgbuild: "1.1.0.14"
tib-dp-chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
tib-dp-workload-type: "capability-service"
tib-dp-dataplane-id: "{{ $dpParams.dp.name }}"
tib-dp-capability-instance-id: "{{ $dpParams.dp.instanceId }}"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/capability-instance-id: "{{ $dpParams.dp.instanceId }}"
platform.tibco.com/dataplane-id: "{{ $dpParams.dp.name }}"
platform.tibco.com/subscriptionId: "{{ $dpParams.dp.subscriptionId }}"
{{- end }}

{{/*
msg.dp.net.kubectl
Labels to allow pods kubeapi access
*/}}
{{- define "msg.dp.net.kubectl" }}
networking.platform.tibco.com/kubernetes-api: enable
{{- end }}

{{/*
msg.dp.net.fullCluster
Labels to allow pods full K8s + cluster CIDR (ingress/LBs) access
*/}}
{{- define "msg.dp.net.fullCluster" }}
ingress.networking.platform.tibco.com/cluster-access: enable
{{- end }}

{{/*
msg.dp.net.external
Labels to allow pods external N-S access
*/}}
{{- define "msg.dp.net.external" }}
egress.networking.platform.tibco.com/internet-all: enable
ingress.networking.platform.tibco.com/internet-access: enable
{{- end }}

{{/*
msg.dp.net.all
Labels to allow pods kube+cluster+external
*/}}
{{- define "msg.dp.net.all" }}
{{ include "msg.dp.net.kubectl" . }}
{{ include "msg.dp.net.fullCluster" . }}
{{ include "msg.dp.net.external" . }}
{{- end }}

{{/*
msg.envPodRefs - expand a list of <name: field> for use in a env: section
*/}}
{{- define "msg.envPodRefs" }}
# START-OF- EXPANDED PodRef List
{{- range $key, $val := . }}
- name: {{ $key | quote }}
  valueFrom:
    fieldRef:
      fieldPath: {{ $val }}
{{- end }}
# END-OF-EXPANDED PodRef List
{{- end }}

{{/*
msg.envStdPodRefs - generate a list of standard <name: field> for use in a env: section
*/}}
{{- define "msg.envStdPodRefs" }}
{{- $stdRefs := (dict "MY_POD_NAME" "metadata.name" "MY_NAMESPACE" "metadata.namespace" "MY_POD_IP" "status.podIP" "MY_NODE_NAME" "spec.nodeName" "MY_NODE_IP" "status.hostIP" "MY_SA_NAME" "spec.serviceAccountName"  ) -}}
{{ include "msg.envPodRefs" $stdRefs }}
{{- end }}
