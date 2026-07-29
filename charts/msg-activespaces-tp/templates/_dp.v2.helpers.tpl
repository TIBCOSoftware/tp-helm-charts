
{{/*
MSG DP Common Helpers
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

V2 - splify attempt, not that PCP is a little more stable.

*/}}

{{- define "msgdp.ghcrImageRepo" -}}"tibco/msg-platform-cicd"{{ end }}
{{- define "msgdp.jfrogImageRepo" -}}"tibco-platform-docker-dev"{{ end }}
{{- define "msgdp.ecrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.acrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.defaultImageRepo" -}}"messaging"{{ end }}

{{/*
need.msg.dp.params
*/}}
{{ define "need.msg.dp.params" }}
  # Reference for global.cp attributes : 
  #   https://confluence.tibco.com/x/uoBUEQ
  # Use TCM testbed defaults for now
  {{- $registry := "ghcr.io" -}}
  {{- $fluentbitEnabled := .Values.global.cp.logging.fluentbit.enabled -}}
  {{- $repo := include "msgdp.ghcrImageRepo" . -}}
  {{- $scSharedName := "none" -}}
  # These 3 are currently unused!
  {{- if .Values.global -}}
    {{- if .Values.global.cp -}}
        {{- if .Values.global.cp.containerRegistry -}}
          {{- $registry = ternary  $registry  .Values.global.cp.containerRegistry.url ( not  .Values.global.cp.containerRegistry.url ) -}}
          {{- if .Values.global.cp.containerRegistry.repository -}}
            {{- $repo = .Values.global.cp.containerRegistry.repository -}}
          {{- else if contains "ghcr.io" $registry -}}
            {{- $repo = "tibco/msg-platform-cicd" -}}
          {{- else if contains "jfrog.io" $registry -}}
            {{- $repo = include "msgdp.jfrogImageRepo" . -}}
          {{- else if contains "amazonaws.com" $registry -}}
            {{- $repo = include "msgdp.ecrImageRepo" . -}}
          {{- else if contains "azurecr.io" $registry -}}
            {{- $repo = include "msgdp.acrImageRepo" . -}}
          {{- else -}}
            {{- $repo = include "msgdp.defaultImageRepo" . -}}
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
    {{- $registry = ternary  $registry  .Values.dp.registry ( not  .Values.dp.registry ) -}}
    {{- $repo = ternary  $repo  .Values.dp.repository ( not  .Values.dp.repository ) -}}
    {{- $scSharedName = ternary  $scSharedName  .Values.dp.scSharedName ( not  .Values.dp.scSharedName ) -}}
      {{- if hasKey .Values.dp "fluentbitEnabled" -}}
        {{- $fluentbitEnabled = .Values.dp.fluentbitEnabled -}}
      {{- end -}}
  {{- end -}}
#
dp:
  uid: 1000
  gid: 1000
  where: "local"
  name: {{  .Values.dp.name | default .Values.global.cp.dataplaneId | default "dp-noname" }}
  adminUser: {{  .Values.dp.adminUser | default .Values.cp.adminUser | default "tibadmin" }}
  jwks: {{  .Values.cp.jwks }}

  # From global dig ?? 
  pullSecret: {{ .Values.dp.pullSecret | default .Values.global.cp.containerRegistry.secret | default "none" }}
  registry: {{ $registry }}
  repository: {{ $repo }}
  activationUrl: {{ .Values.dp.activationUrl | default .Values.global.cp.activationUrl | default "file:///boot-activation/license-file.bin" }}
  pullPolicy: {{ .Values.dp.pullPolicy | default .Values.global.cp.pullPolicy | default "IfNotPresent" }}
  serviceAccount: {{ .Values.dp.serviceAccount | default .Values.global.cp.resources.serviceaccount.serviceAccountName | default .Values.global.cp.serviceAccount | default "provisioner" }}
  cpHostname: {{ .Values.dp.cpHostname | default .Values.global.cp.cpHostname | default "no-cpHostname" }}
  instanceId: {{  .Values.dp.instanceId | default .Values.global.cp.instanceId | default "no-instanceid" }}
  # environmentType: {{  .Values.dp.environmentType | default .Values.global.cp.environmentType | default "no-environmentType" }}
  subscriptionId: {{ .Values.dp.subscriptionId | default .Values.global.cp.subscriptionId | default "no-subscriptionId" }}
  scSharedName: {{ $scSharedName }}
  release: {{ .Release.Name }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  chart: {{ printf "%s_%s" .Chart.Name .Chart.Version }}
  fluentbitEnabled: {{ $fluentbitEnabled }}
  enableClusterScopedPerm: {{ .Values.global.cp.enableClusterScopedPerm }}
  enableSecurityContext: {{ .Values.enableSecurityContext }}
  # enableHaproxy: true
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
platform.tibco.com/capability-instance-id: "{{ $dpParams.dp.instanceId | default .Release.Name }}"
{{ end }}

{{/*
msg.dp.labels prints the standard dataplane Helm labels.
note: tib-msg-stsname will be added directly in statefulset charts, as it needs to be the pod match label
*/}}
{{- define "msg.dp.labels" }}
{{-  $dpParams := include "need.msg.dp.params" . | fromYaml }}
{{ include "msg.dpparams.labels" $dpParams }}
{{- end }}

{{/*
msg.dpparams.labels prints the standard dataplane Helm labels, takes a $xxParams argument
note: tib-msg-stsname will be added directly in statefulset charts, as it needs to be the pod match label
*/}}
{{- define "msg.dpparams.labels" }}
tib-dp-release: {{ .dp.release }}
tib-dp-msgbuild: "1.19.0.23"
tib-dp-chart: {{ .dp.chart }}
tib-dp-workload-type: "capability-service"
tib-dp-dataplane-id: "{{ .dp.name }}"
tib-dp-capability-instance-id: "{{ .dp.instanceId }}"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/capability-instance-id: "{{ .dp.instanceId }}"
platform.tibco.com/dataplane-id: "{{ .dp.name }}"
platform.tibco.com/subscriptionId: "{{ .dp.subscriptionId }}"
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
networking.platform.tibco.com/msgInfra: enable
networking.platform.tibco.com/cluster-ingress: enable
networking.platform.tibco.com/cluster-egress: enable
ingress.networking.platform.tibco.com/cluster-access: enable
{{- end }}

{{/*
msg.dp.net.external
Labels to allow pods external N-S access
*/}}
{{- define "msg.dp.net.external" }}
networking.platform.tibco.com/internet-ingress: enable
networking.platform.tibco.com/internet-egress: enable
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
- name: {{ $key }}
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
- name: MY_RELEASE
  value: {{ .Release.Name }}
{{- $stdRefs := (dict "MY_POD_NAME" "metadata.name" "MY_NAMESPACE" "metadata.namespace" "MY_POD_IP" "status.podIP" "MY_NODE_NAME" "spec.nodeName" "MY_NODE_IP" "status.hostIP" "MY_SA_NAME" "spec.serviceAccountName"  ) -}}
{{ include "msg.envPodRefs" $stdRefs }}
{{- end }}

{{/*
msg.dp.stdenv - generate a list of standard pod ENV settigns including PodRefs
.. expects a $xxParams struct with a dp subsection
*/}}
{{- define "msg.dp.stdenv" }}
- name: MY_RELEASE
  value: {{ .dp.release }}
- name: DP_LOGGING_FLUENTBIT_ENABLED
  value: {{ .dp.fluentbitEnabled | quote }}
- name: LOG_ALERT_PORT
  value: "8099"
{{- $stdRefs := (dict "MY_POD_NAME" "metadata.name" "MY_NAMESPACE" "metadata.namespace" "MY_POD_IP" "status.podIP" "MY_NODE_NAME" "spec.nodeName" "MY_NODE_IP" "status.hostIP" "MY_SA_NAME" "spec.serviceAccountName"  ) -}}
{{ include "msg.envPodRefs" $stdRefs }}
{{- end }}

{{/*
msg.pv.vol.mount - Generate a volumeMount from a standard volSpec structure
.. works with msg.pv.vol.def and msg.pv.vol.vct to standardize volume config options
.. fields: volName, storageType, storageName, subPath, subPathExpr, storageSize
.. storageType: in {storageClass, emptyDir, sharedPvc, sharedStorageClass, use-<volName> }
.. default shared subPathExpr: "$(MY_RELEASE)/$(MY_POD_NAME)/<volName>"
.. default use-*  subPath: "<volName>"
*/}}
{{- define "msg.pv.vol.mount" }}
{{- $volName := .volName -}}
{{- if hasPrefix "use-" .storageType -}}
  {{- $volName = trimPrefix "use-" .storageType -}} 
{{- else if eq "sharedPvc" .storageType -}}
  {{- $volName = .storageName -}} 
{{- end -}}
name: {{ $volName }}
{{- if .subPathExpr }}
subPathExpr: "{{ .subPathExpr }}"
{{- else if .subPath }}
subPath: "{{ .subPath }}"
{{- else if eq "sharedPvc" .storageType }}
subPathExpr: "$(MY_RELEASE)/$(MY_POD_NAME)/{{ .volName }}"
{{- else if hasPrefix "use-" .storageType }}
subPath: "{{ .volName }}"
{{- end }}
  {{- if .readOnly }}
readOnly: true
  {{- end }}
{{- end }}

{{/*
msg.pv.vol.def - Generate a volumes: section from a standard volSpec structure
.. works with msg.pv.vol.mount and msg.pv.vol.vct to standardize volume config options
.. storageType in {storageClass, use-* } do not need a vdef 
*/}}
{{- define "msg.pv.vol.def" }}
{{- $volName := .volName -}}
{{- if eq "sharedPvc" .storageType -}}
  {{- $volName = .storageName -}} 
{{- end -}}
{{- if eq "sharedPvc" .storageType -}}
- name: {{ $volName }}
  persistentVolumeClaim:
    claimName: {{ .storageName }}
{{- else if eq "configMap" .storageType -}}
- name: {{ $volName }}
  configMap:
    name: {{ .storageName }}
      {{- if .optional }}
    optional: true
      {{- end }}
      {{- if .defaultMode }}
    defaultMode: {{ .defaultMode }}
      {{- end }}
{{- else if eq "secret" .storageType -}}
- name: {{ $volName }}
  secret:
    secretName: {{ .storageName }}
      {{- if .optional }}
    optional: true
      {{- end }}
{{- else if eq "emptyDir" .storageType -}}
- name: {{ $volName }}
  emptyDir: {}
{{- else if eq "storageClass" .storageType -}}
{{- else if not (hasPrefix "use-" .storageType) -}}
  {{ fail (printf "unknown storageType: %s" .storageType) }}
{{- end }}
{{- end }}

{{/*
msg.pv.vol.vct - Generate a volume VolumeClaimTemplate section from a standard volSpec structure
.. works with msg.pv.vol.mount and msg.pv.vol.def to standardize volume config options
.. basically just storageType == storageClass need a VCT
*/}}
{{- define "msg.pv.vol.vct" }}
{{- if eq "storageClass" (required "storageType is required." .storageType) -}}
- metadata:
    name: {{ .volName }}
  spec:
    accessModes: [ {{ .accessMode | default "ReadWriteOnce" }} ]
    storageClassName: "{{ .storageName }}"
    resources:
      requests:
        storage: {{ .storageSize | default "2Gi" }}
{{- end }}
{{- end }}

{{/*
msg.node.skew - Generate topology node skew contraint from a $params struct
.. Key: .params in {yes, no},  .comp - name suffix
*/}}
{{- define "msg.node.skew" }}
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  {{- if eq .params.allowNodeSkew "no" }}
  whenUnsatisfiable: DoNotSchedule
  {{- else }}
  whenUnsatisfiable: ScheduleAnyway
  {{- end }}
  labelSelector:
    matchLabels:
      tib-msg-stsname: {{ printf "%s-%s" .params.name .comp }}
{{- end }}

{{/*
msg.zone.skew - Generate topology zone skew contraint from a $params struct
.. Key: .params in {yes, no},  .comp - name suffix
*/}}
{{- define "msg.zone.skew" }}
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  {{- if eq .params.allowZoneSkew "no" }}
  whenUnsatisfiable: DoNotSchedule
  {{- else }}
  whenUnsatisfiable: ScheduleAnyway
  {{- end }}
  labelSelector:
    matchLabels:
      tib-msg-stsname: {{ printf "%s-%s" .params.name .comp }}
{{- end }}

{{/*
msg.dp.security.pod - Generate a pod securityContext section from $xxParams struct
.. works with msg.dp.security.container to standardize non-root securityContext restrictions
*/}}
{{- define "msg.dp.security.pod" }}
{{- if .dp.enableSecurityContext }}
  {{- if eq .securityProfile "pss-restrictive" }}
securityContext:
  runAsUser: {{ int .dp.uid }}
  runAsGroup: {{ int .dp.gid }}
  fsGroup: {{ int .dp.gid }}
    {{- if eq (int 0) (int .dp.uid) }}
  runAsNonRoot: false
    {{- else }}
  runAsNonRoot: true
  fsGroupChangePolicy: "OnRootMismatch"
  seccompProfile:
    type: RuntimeDefault
    {{- end }} {{/* root */}}
  {{- end }} {{/* pss */}}
{{- end }} {{/* enable */}}
{{- end }} {{/* define */}}

{{/*
msg.dp.security.container - Generate a container securityContext section from $xxParams struct
.. works with msg.dp.security.pod to standardize non-root securityContext restrictions
Supported Profiles:
  ems:  drop all caps, read-only root, runAsNonRoot
  pulsar:  drop all caps, read-write root, runAsNonRoot
  pod-edit: root, read-write, main=wait-for-shutdown, no liveness/readiness
*/}}
{{- define "msg.dp.security.container" }}
{{- if .dp.enableSecurityContext }}
  {{- if eq .securityProfile "pss-restrictive" }}
securityContext:
  runAsUser: {{ int .dp.uid }}
  runAsGroup: {{ int .dp.gid }}
    {{- if ne (int 0) (int .dp.uid) }}
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
    - CAP_NET_RAW
  readOnlyRootFilesystem: true
  runAsNonRoot: true
    {{- end }}
  {{- end }} {{/* pss */}}
{{- end }}
{{- end }}
