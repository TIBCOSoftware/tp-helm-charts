
{{/*
MSGDP Control Tower Gateway Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

# $params
# msg.dp.stdenv
# msg.dp.security.pod
# msg.dp.security.container

*/}}

{{- define "msgdp.ghcrImageRepo" -}}"tibco/msg-platform-cicd"{{ end }}
{{- define "msgdp.jfrogImageRepo" -}}"tibco-platform-docker-dev"{{ end }}
{{- define "msgdp.ecrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.acrImageRepo" -}}"msg-platform-cicd"{{ end }}
{{- define "msgdp.defaultImageRepo" -}}"messaging"{{ end }}

{{ define "msg.dp.repository" }}
  {{- $registry := .Values.global.cp.containerRegistry.url | default "ghcr.io" -}}
  {{- $repository := .Values.global.cp.containerRegistry.repository | default "UseDefault" -}}
  {{- if eq "UseDefault" $repository -}}
          {{- if contains "ghcr.io" $registry -}}
            {{- $repository = "tibco/msg-platform-cicd" -}}
          {{- else if contains "jfrog.io" $registry -}}
            {{- $repository = include "msgdp.jfrogImageRepo" . -}}
          {{- else if contains "amazonaws.com" $registry -}}
            {{- $repository = include "msgdp.ecrImageRepo" . -}}
          {{- else if contains "azurecr.io" $registry -}}
            {{- $repository = include "msgdp.acrImageRepo" . -}}
          {{- else -}}
            {{- $repository = include "msgdp.defaultImageRepo" . -}}
          {{- end -}}
  {{- end -}}
  {{ printf "%s" $repository }}
{{ end }}

{{/*
need.msg.dp.params
*/}}
{{ define "need.msg.dp.params" }}
# SET Defaults just in case
  {{- $adminUser := "tibadmin" -}}
  {{- $jwks := "" -}}
  {{- $scSharedName := "none" -}}
  {{- $cpHostname := "no-cpHostname" -}}
  {{- $subscriptionId := "no-subscriptionId" -}}
  # currently unused below
  {{- $environmentType := "no-environmentType" -}}
#
dp:
  name: {{ .Values.global.cp.dataplaneId | default "no-dpName" }}
  release: {{ .Release.Name }}
  chart: {{ printf "%s_%s" .Chart.Name .Chart.Version }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  pullSecret: "{{ .Values.dp.pullSecret | default  .Values.global.cp.containerRegistry.secret | default "cic2-tcm-ghcr-secret" }}"
  adminUser: {{ .Values.dp.adminUser | default "tibadmin" }}
  registry: {{ .Values.dp.registry | default .Values.global.cp.containerRegistry.url | default "ghcr.io" }}
  repository: {{ .Values.dp.repository | default ( include "msg.dp.repository" . ) }}
  pullPolicy: {{ .Values.dp.pullPolicy | default .Values.global.cp.pullPolicy | default "IfNotPresent" }}
  serviceAccount: {{ .Values.dp.serviceAccount | default .Values.global.cp.resources.serviceaccount.serviceAccountName  | default "provisioner" }}
  cpHostname: {{ .Values.global.cp.cpHostname | default "no-cpHostname" }}
  subscriptionId: {{ .Values.global.cp.subscriptionId  | default "noSubid" }}
  cpInstanceId: {{ .Values.global.cp.instanceId  | default "noCPwho" }}
  hostCloudType: {{ .Values.global.cp.hostCloudType | default "unset" }}
  enableClusterScopedPerm: {{ .Values.global.cp.enableClusterScopedPerm | default true }}
  fluentbitEnabled: {{ .Values.global.cp.logging.fluentbit.enabled | default true }}
  enableSecurityContext: true
  enableHaproxy: true
  uid: {{ .Values.dp.uid | default 1000 }}
  gid: {{ .Values.dp.gid | default 1000 }}
{{ end }}

{{/*
need.msg.gateway.params
*/}}
{{ define "need.msg.gateway.params" }}
{{- $dpParams := include "need.msg.dp.params" . | fromYaml -}}
{{- $emsDefaultFullImage := printf "%s/%s/msg-ems-all:10.4.0-85" $dpParams.dp.registry $dpParams.dp.repository -}}
{{- $basename :=  .Values.msggw.basename | default "tp-msg-gateway" -}}
#
{{ include "need.msg.dp.params" . }}
msggw:
  basename: "{{ $basename }}"
  image: "{{ .Values.msggw.image | default $emsDefaultFullImage }}"
  supportShellEnabled: {{ .Values.msggw.supportShellEnabled | quote }}
  ports:
    gatewayApiPort: 8376
    restdPort: 9014
    watchdogPort: 12502
    loggerPort: 12506
  # Volumes
  boot:
    volName: scripts-vol
    storageType: configMap
    storageName: {{ $basename }}-scripts
    readOnly: true
    defaultMode: 0777
  hawk: 
    volName: hawk
    storageType: sharedPvc
    storageName: hawk-console-data-tp-dp-hawk-console-0
    subPath: "."
  logs: 
    volName: logs
    storageType: sharedPvc
    storageName: hawk-console-data-tp-dp-hawk-console-0
    subPath: "msg/logs"
  lbHost: "alternateNlbNameHere"
  resources:
    {{ if .Values.msggw.resources }}
{{ .Values.msggw.resources | toYaml | indent 4 }}
    {{ else }}
    requests:
      memory: "0.5Gi"
      cpu: "0.1"
    limits:
      memory: "4Gi"
      cpu: "3"
    {{ end }}
enableIngress: {{ .Values.enableIngress | default true }}
securityProfile: "{{ .Values.securityProfile | default "pss-restrictive" }}"
job:
  resources:
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

{{/*
msg.gateway.mon.labels $params - Generate CP monitoring labels
*/}}
{{- define "msg.gateway.mon.labels" }}
tib-dp-release: {{ .dp.release }}
tib-dp-msgbuild: "1.10.0.7"
tib-dp-chart: {{ .dp.chart }}
platform.tibco.com/app-type: "msg-gateway"
platform.tibco.com/scrape_finops: "true"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: "{{ .dp.name }}"
platform.tibco.com/cpHostname: "{{ .dp.cpHostname }}"
platform.tibco.com/environmentType: "{{ .dp.environmentType }}"
prometheus.io/scrape: "true"
{{ end }}

{{/*
msg.gateway.mon.anno $params - Generate CP monitoring scrape annotations
*/}}
{{- define "msg.gateway.mon.anno" }}
prometheus.io/scrape: "true"
prometheus.io/port: "{{ .msggw.ports.gatewayApiPort }}"
prometheus.io/scheme: "http"
prometheus.io/path: /dp/metric/health
prometheus.io/insecure_skip_verify: "true"
{{ end }}

{{/*
ems.std.labels prints the standard EMS group Helm labels.
note: expects a $emsParams as its argument
*/}}
{{- define "msg-gateway.std.labels" }}

platform.tibco.com/capability-instance-id: "{{ .dp.cpInstanceId }}"
platform.tibco.com/workload-type: infra
platform.tibco.com/dataplane-id: "{{ .dp.name }}"

app.cloud.tibco.com/created-by: tp-msg
app.cloud.tibco.com/tenant-name: messaging
release: "{{ .dp.release }}"
tib-dp-name: "{{ .dp.name }}"
tib-dp-app: msg-gateway
tib-msg-group-name: "{{ .msggw.basename }}"
app.kubernetes.io/name: "{{ .msggw.basename }}"
app.kubernetes.io/part-of: tp-hawk-console
platform.tibco.com/workload-type: "infra"
{{- end }}

{{/*
msg.dp.net.kubectl
Labels to allow pods kubeapi access
*/}}
{{- define "msg.dp.net.kubectl" }}
networking.platform.tibco.com/kubernetes-api: enable
{{- end }}

{{/*
msg.dp.net.egress
Labels to allow pods full outbound K8s + cluster CIDR access
*/}}
{{- define "msg.dp.net.egress" }}
networking.platform.tibco.com/msgInfra: enable
networking.platform.tibco.com/cluster-egress: enable
networking.platform.tibco.com/internet-egress: enable
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
    storageClassName: {{ .storageName }}
    resources:
      requests:
        storage: {{ .storageSize | default "2Gi" }}
{{- end }}
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
msg.dp.security.pod - Generate a pod securityContext section from $params struct
.. works with msg.dp.security.container to standardize non-root securityContext restrictions
.. use "pod-edit" for a root-editable pod.
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
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
msg.dp.security.container - Generate a container securityContext section from $params struct
.. works with msg.dp.security.pod to standardize non-root securityContext restrictions
Supported Profiles:
  pss-restrictive:  drop all caps, read-only root, runAsNonRoot
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
  {{- end }}
{{- end }}
{{- end }}
