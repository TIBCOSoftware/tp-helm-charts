
{{/*
MSG CP Common Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}
{{- define "msgdp.ghcrImageRepo" -}}"tibco/msg-platform-cicd"{{ end }}
{{- define "msgdp.devImageRepo" -}}"tibco-platform-docker-dev"{{ end }}
{{- define "msgdp.prodImageRepo" -}}"tibco-platform-docker-prod"{{ end }}
{{- define "msgdp.defaultImageRepo" -}}"tibco-platform-docker-prod"{{ end }}

{{- define "const.nocic.dnsdomains" -}}"tp-cp-core-dnsdomains"{{ end }}
{{- define "const.cic.dnsdomains" -}}"tp-control-plane-dnsdomains"{{ end }}

{{/*
need.msg.cp.params call with . or $
  Note: cp.values.global defined in _cp.globals.helpers.tpl
  .. to make maintaining ConfigMap yes/now flag easier
*/}}
{{- define "need.msg.cp.params" -}}
{{- $vDefault := include "cp.values.defaults" . | fromYaml -}}
{{- $vCP := include "cp.values.global" ( toJson . | fromJson ) | fromYaml -}}
{{- $vOverride := include "cp.values.overrides" . | fromYaml -}}
{{- $vMerge := merge $vOverride $vCP $vDefault  -}}
{{- $vComputed := include "cp.values.computed" $vMerge | fromYaml -}}
{{- merge $vComputed $vMerge | toYaml -}}
{{- end }}

{{/*
cp.values.computed - call with $vMerge
  will use supplied values to calculate repo and imageFullName if not supplied
*/}}
{{- define "cp.values.computed" -}}
{{- $repo := .cp.repository -}}
{{- $registry := .cp.registry | default "no-registrty" -}}
  {{- if not $repo -}}
      {{- if contains "jfrog.io" $registry -}}
        {{- $repo = include "msgdp.prodImageRepo" . -}}
      {{- else if contains "amazonaws.com" $registry -}}
        {{- $repo = include "msgdp.devImageRepo" . -}}
      {{- else if contains "azurecr.io" $registry -}}
        {{- $repo = include "msgdp.devImageRepo" . -}}
      {{- else -}}
        {{- $repo = include "msgdp.defaultImageRepo" . -}}
      {{- end -}}
  {{- end -}}
{{- $repo = printf "%s" $repo | replace "\"" "" -}}
{{- $imageRepoPath := printf "%s/%s" .cp.registry $repo | replace "\"" "" -}}
{{- $imageFullName := printf "%s/%s/%s:%s" .cp.registry 
                        $repo 
                        ( .cp.imageName | default "no-name" ) 
                        ( .cp.imageTag | default "latest" ) | 
                        replace "\"" "" -}}
{{- if .cp.imageFullName -}}
  {{- $imageFullName = .cp.imageFullName -}}
{{- end -}}
{{-  dict "cp" ( dict "repo" $repo 
                "imageFullName" $imageFullName 
                "DNS_DOMAIN" ( printf "*.%s" .cp.DNS_DOMAIN | replace "\"" "" )
                "ADMIN_DNS_DOMAIN" ( printf "admin.%s" .cp.DNS_DOMAIN | replace "\"" "" )
                "DNS_SUBDOMAIN" ( printf "%s" .cp.DNS_DOMAIN | replace "\"" "" )
                "imageRepoPath" $imageRepoPath ) | toYaml  -}}
{{- end -}}

{{/* Map CP chart defaults 
    call as: include "cp.values.defaults" . ) 
*/}}
{{- define "cp.values.defaults" -}}
randomSuffix: {{ .Values.randomSuffix | default (randAlphaNum 4 | lower ) }}
cp:
  uid: 1000
  gid: 1000
  registry: "csgprdusw2reposaas.jfrog.io"
  repository: 
  imageFullName:
  pullSecret: "tibco-container-registry-credentials"
  pullPolicy: Always
  imageName: "msg-cp-ui-contrib"
  imageTag: "1.13.0-14"
  enableResourceConstraints: true
    {{ if hasKey .Values.cp "enableSecurityContext" }}
  enableSecurityContext: {{ .Values.cp.enableSecurityContext }}
    {{ end }}
  serviceAccount: "no-serviceAcountName"
  # CP_SERVICE_ACCOUNT_NAME: "no-serviceAcountName"
  ADMIN_DNS_DOMAIN: "no-adminDnsDomain"
  CP_VOLUME_CLAIM: "control-plane-pvc"
  # CP_ENABLE_RESOURCE_CONSTRAINTS: "true"
  DNS_DOMAIN: "no-dnsDomain"
  ENV_TYPE: "nocic"
  LOGGING_FLUENTBIT_ENABLED: "false"
  OTEL_SERVICE: {{ printf "otel-services.%s.svc.cluster.local" .Release.Namespace | quote }}
  SUBSCRIPTION_SINGLE_NAMESPACE: "false"
  SYSTEM_WHO: "no-instanceId"
  cp_env:
    volName: cp-env-vol
    storageType: configMap
    storageName: cp-env
    readOnly: false
    optional: true
  cic_env:
    volName: cic-env-vol
    storageType: configMap
    storageName: cic-env
    readOnly: false
    optional: true
  cp_dns:
    volName: cp-dns-vol
    storageType: configMap
    storageName: {{ include "const.nocic.dnsdomains" . }}
    readOnly: false
    optional: true
  cic_dns:
    volName: cic-dns-vol
    storageType: configMap
    storageName: {{ include "const.cic.dnsdomains" . }}
    readOnly: false
    optional: true
  cp_extra:
    volName: cp-extra-vol
    storageType: configMap
    storageName: msg-cp-extra
    readOnly: false
    optional: true
recipes:
  TARGET_PATH: {{ .Values.recipes.TARGET_PATH | default "/private/tsc/config/capabilities" }}
  jobPostSleep: {{ .Values.recipes.jobPostSleep | default "10" }}
securityProfile: "{{ .Values.securityProfile | default "pss-restricted" }}"
{{- end -}}

{{/* Map CP chart supported overrides 
    call as: include "cp.values.overrides" . | from Yaml
*/}}
{{- define "cp.values.overrides" -}}
cp:
  CP_VOLUME_CLAIM: {{ .Values.cp.CP_VOLUME_CLAIM | default "" }}
  registry: {{ .Values.cp.registry | default "" }}
  repository: {{ .Values.cp.repository | default "" }}
  imageName: {{ .Values.cp.imageName | default "" }}
  imageTag: {{ .Values.cp.imageTag | default "" }}
  pullPolicy: {{ .Values.cp.pullPolicy | default "" }}
  pullSecret: {{ .Values.cp.pullSecret | default "" }}
  enableSecurityContext: {{ .Values.cp.enableSecurityContext | default nil }}
  uid: {{ .Values.cp.uid | default "" }}
  gid: {{ .Values.cp.gid | default "" }}
{{- end -}}


{{/*
msg.cp.security.pod - Generate a pod securityContext section from $xxParams struct
.. works with msg.cp.security.container to standardize non-root securityContext restrictions
*/}}
{{- define "msg.cp.security.pod" }}
securityContext:
  # {{ printf "securityProfile:%s" .securityProfile }}
{{- if .cp.enableSecurityContext }}
  {{- if eq .securityProfile "pss-restricted" }}
  runAsUser: {{ int .cp.uid }}
  runAsGroup: {{ int .cp.gid }}
  fsGroup: {{ int .cp.gid }}
    {{- if eq (int 0) (int .cp.uid) }}
  runAsNonRoot: false
    {{- else }}
  runAsNonRoot: true
  fsGroupChangePolicy: Always
  seccompProfile:
    type: RuntimeDefault
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
msg.cp.security.container - Generate a container securityContext section from $xxParams struct
.. works with msg.cp.security.pod to standardize non-root securityContext restrictions
*/}}
{{- define "msg.cp.security.container" }}
securityContext:
  # {{ printf "securityProfile:%s" .securityProfile }}
{{- if .cp.enableSecurityContext }}
  {{- if eq .securityProfile "pss-restricted" }}
  runAsUser: {{ int .cp.uid }}
  runAsGroup: {{ int .cp.gid }}
    {{- if ne (int 0) (int .cp.uid) }}
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
