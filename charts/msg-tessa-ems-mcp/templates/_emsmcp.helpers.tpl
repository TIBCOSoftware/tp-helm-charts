
{{/*
MSGDP EMS-MCP Helpers
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
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
msg.dp.dpUrl.*
*/}}
{{- define "msg.dp.dpUrl.host" -}}
{{- $dpGlobals := include "dp.values.global" (toJson . | fromJson) | fromYaml -}}
{{- tpl (printf "%s" ($dpGlobals.cp.dpUrl.host | default "")) . -}}
{{- end -}}

{{- define "msg.dp.dpUrl.port" -}}
{{- $dpGlobals := include "dp.values.global" (toJson . | fromJson) | fromYaml -}}
{{- int ($dpGlobals.cp.dpUrl.port | default 443) -}}
{{- end -}}

{{/*
need.msg.dp.params
*/}}
{{ define "need.msg.dp.params" }}
# SET Defaults just in case
#
dp:
  name: {{ .Values.global.cp.dataplaneId | default "no-dpName" }}
  release: {{ .Release.Name }}
  chart: {{ printf "%s_%s" .Chart.Name .Chart.Version }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  pullSecret: "{{ .Values.dp.pullSecret | default  .Values.global.cp.containerRegistry.secret | default "none" }}"
  registry: {{ .Values.dp.registry | default .Values.global.cp.containerRegistry.url | default "ghcr.io" }}
  repository: {{ .Values.dp.repository | default ( include "msg.dp.repository" . ) }}
  pullPolicy: {{ .Values.dp.pullPolicy | default .Values.global.cp.pullPolicy | default "IfNotPresent" }}
  instanceId: {{  .Values.dp.instanceId | default .Values.global.cp.instanceId | default "no-instanceid" }}
  subscriptionId: {{ .Values.dp.subscriptionId | default .Values.global.cp.subscriptionId | default "no-subscriptionId" }}
  enableSecurityContext: true
  enableHaproxy: true
  uid: {{ .Values.dp.uid | default 1000 }}
  gid: {{ .Values.dp.gid | default 1000 }}
{{ end }}

{{/*
need.msg.emsmcp.params
*/}}
{{ define "need.msg.emsmcp.params" }}
{{- $dpParams := include "need.msg.dp.params" . | fromYaml -}}
{{- $mcpDefaultFullImage := printf "%s/%s/msg-tessa-ems-mcp:1.21.0-5" $dpParams.dp.registry $dpParams.dp.repository -}}
#
{{ include "need.msg.dp.params" . }}
emsmcp:
  name: "tp-msg-emsmcp"
  image: "{{ .Values.emsmcp.image | default $mcpDefaultFullImage }}"
  ports:
    mcp: 8080
{{ if .Values.emsmcp.haproxyNoauth }}
  haproxyConfig: "/logs/boot/haproxy.noauth.cfg"
{{ else }}
  haproxyConfig: "/logs/boot/haproxy.cfg"
{{ end }}
  resources:
    {{ if .Values.emsmcp.resources }}
{{ .Values.emsmcp.resources | toYaml | indent 4 }}
    {{ else }}
    requests:
      memory: "0.5Gi"
      cpu: "0.1"
    limits:
      memory: "4Gi"
      cpu: "3"
    {{ end }}
securityProfile: "{{ .Values.securityProfile | default "pss-restrictive" }}"
{{ end }}

{{/*
msg-emsmcp.std.labels prints the standard EMS group Helm labels.
note: expects a $emsParams as its argument
*/}}
{{- define "msg-emsmcp.std.labels" }}
platform.tibco.com/capability-instance-id: "{{ .dp.instanceId }}"
platform.tibco.com/subscriptionId: "{{ .dp.subscriptionId }}"
platform.tibco.com/workload-type: capability-service
platform.tibco.com/dataplane-id: "{{ .dp.name }}"
release: "{{ .dp.release }}"
tib-dp-app: msg-emsmcp
tib-msg-group-name: "{{ .emsmcp.name }}"
app.kubernetes.io/name: "{{ .emsmcp.name }}"
app.kubernetes.io/part-of: msg-tessa-ems-mcp
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
- name: FTL_REALM_URL_TEMPLATE
  value: 'http://$groupName-ftl.vdp.svc:9013'
- name: EMS_ACTIVE_URL_TEMPLATE 
  value: 'tcp://$groupName-emsactive.vdp.svc:9011'
{{- $stdRefs := (dict "MY_POD_NAME" "metadata.name" "MY_NAMESPACE" "metadata.namespace" "MY_POD_IP" "status.podIP" "MY_NODE_NAME" "spec.nodeName" "MY_NODE_IP" "status.hostIP"  ) -}}
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
