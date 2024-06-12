{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}


{{/*
================================================================
                  SECTION COMMON VARS
================================================================   
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "tp-cp-configuration.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tp-cp-configuration.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "tp-cp-configuration.component" -}}tp-cp-configuration{{- end }}

{{- define "tp-cp-configuration.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "tp-cp-configuration.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "tp-cp-configuration.serviceAccount" -}}
{{- "control-plane-sa" }}
{{- end }}

{{- define "tp-cp-configuration.compute-services.consts.appName" }}compute-services{{ end -}}

{{- define "tp-cp-configuration.hybrid-server.consts.appName" }}hybrid-server{{ end -}}

{{- define "tp-cp-configuration.control-tower.targetDir" }}/efs/control-tower{{ end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{- define "tp-cp-configuration.consts.jfrogImageRepo" }}tibco-platform-local-docker/infra{{end}}
{{- define "tp-cp-configuration.consts.ecrImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-configuration.consts.acrImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-configuration.consts.harborImageRepo" }}stratosphere{{end}}
{{- define "tp-cp-configuration.consts.defaultImageRepo" }}tibco-platform-local-docker/infra{{end}}

{{- define "tp-cp-configuration.image.registry" }}
  {{- if .Values.image.registry }} 
    {{- .Values.image.registry }}
  {{- else }}
    {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY" "default" "reldocker.tibco.com" "required" "false" "Release" .Release )}}
  {{- end }}
{{- end }}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-configuration.image.repository" -}}
  {{- if .Values.image.repo }} 
    {{- .Values.image.repo }}
  {{- else if contains "jfrog.io" (include "tp-cp-configuration.image.registry" .) }} 
    {{- include "tp-cp-configuration.consts.jfrogImageRepo" .}}
  {{- else if contains "amazonaws.com" (include "tp-cp-configuration.image.registry" .) }}
    {{- include "tp-cp-configuration.consts.ecrImageRepo" .}}
  {{- else if contains "reldocker.tibco.com" (include "tp-cp-configuration.image.registry" .) }}
    {{- include "tp-cp-configuration.consts.harborImageRepo" .}}
  {{- else }}
    {{- include "tp-cp-configuration.consts.defaultImageRepo" .}}
  {{- end }}
{{- end -}}


{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cp-env" -}}
{{- $data := (lookup "v1" "ConfigMap" .Release.Namespace "cp-env") }}
{{- $data | toYaml }}
{{- end }}


{{/* Service account configured for control plane. fail if service account not exist */}}
{{- define "tp-cp-configuration.service-account-name" }}
{{- if .Values.serviceAccount }}
  {{- .Values.serviceAccount }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_SERVICE_ACCOUNT_NAME" "default" "control-plane-sa" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* PVC configured for control plane. Fail if the pvc not exist */}}
{{- define "tp-cp-configuration.pvc-name" }}
{{- if .Values.pvcName }}
  {{- .Values.pvcName }}
{{- else }}
{{- include "cp-env.get" (dict "key" "CP_PVC_NAME" "default" "control-plane-pvc" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Image pull secret configured for control plane. default value empty */}}
{{- define "tp-cp-configuration.container-registry.secret" }}
{{- if .Values.imagePullSecret }}
  {{- .Values.imagePullSecret }}
{{- else }}
  {{- include "cp-env.get" (dict "key" "CP_CONTAINER_REGISTRY_IMAGE_PULL_SECRET_NAME" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}
{{- end }}

{{/* Control plane instance Id. default value local */}}
{{- define "tp-cp-configuration.cp-instance-id" }}
  {{- include "cp-env.get" (dict "key" "CP_INSTANCE_ID" "default" "cp1" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane dns domain. default value example.com */}}
{{- define "tp-cp-configuration.dns-domain" -}}
{{- include "cp-env.get" (dict "key" "CP_DNS_DOMAIN" "default" "example.com" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane dns top level domain */}}
{{- define "tp-cp-configuration.top-level-domain" -}}
{{- include "tp-cp-configuration.dns-domain" . | splitList "." | reverse | first -}}
{{- end }}

{{/* Control plane dns domain name */}}
{{- define "tp-cp-configuration.domain-name" -}}
{{- $tuples := (include "tp-cp-configuration.dns-domain" .| splitList "." | reverse) -}}
{{- index $tuples 1 }}
{{- end }}

{{/* Control plane provider */}}
{{- define "tp-cp-configuration.cp-provider" -}}
{{- include "cp-env.get" (dict "key" "CP_PROVIDER" "default" "local" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane create network policy */}}
{{- define "tp-cp-configuration.create-network-policy" -}}
{{- include "cp-env.get" (dict "key" "CP_CREATE_NETWORK_POLICY" "default" "false" "required" "false" "Release" .Release )}}
{{- end }}

{{/* Control plane node CIDR */}}
{{- define "tp-cp-configuration.nodeCIDR" -}}
{{- include "cp-env.get" (dict "key" "CP_CLUSTER_NODE_CIDR" "default" "" "required" "false" "Release" .Release )}}
{{- end }}

{{/* Control plane pod CIDR */}}
{{- define "tp-cp-configuration.podCIDR" -}}
{{- include "cp-env.get" (dict "key" "CP_CLUSTER_POD_CIDR" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/* Control plane OTEl service */}}
{{- define "tp-cp-configuration.otelServiceName" -}}
{{- include "cp-env.get" (dict "key" "CP_OTEL_SERVICE" "default" "" "required" "false"  "Release" .Release )}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tp-cp-configuration.labels" -}}
helm.sh/chart: {{ include "tp-cp-configuration.chart" . }}
{{ include "tp-cp-configuration.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "tp-cp-configuration.team" . }}
platform.tibco.com/component: {{ include "tp-cp-configuration.component" . }}
{{- end }}
platform.tibco.com/controlplane-instance-id: {{ include "tp-cp-configuration.cp-instance-id" . }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tp-cp-configuration.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tp-cp-configuration.name" . }}
app.kubernetes.io/component: {{ include "tp-cp-configuration.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "tp-cp-configuration.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tp-cp-configuration.container-registry-credential" -}}
  {{-  if (include "tp-cp-configuration.container-registry.secret" .) }}
    {{- $secret := (lookup "v1" "Secret" .Release.Namespace (include "tp-cp-configuration.container-registry.secret" .)) }}
    {{- if $secret }}
      {{- if hasKey $secret "data" }}
        {{- if hasKey $secret.data ".dockerconfigjson" }}
          {{- $encodedDockerConfig := (get $secret.data ".dockerconfigjson" )}}
          {{- $decodedDockerConfig :=  ( printf "%s" $encodedDockerConfig | b64dec ) }}
          {{- if $decodedDockerConfig }}
            {{- $decodedDockerConfigObj := ($decodedDockerConfig | fromJson ) }}
            {{- if $decodedDockerConfigObj }}
              {{- if hasKey $decodedDockerConfigObj "auths" }}
                {{- $auths := (get $decodedDockerConfigObj "auths" )}}
                {{- if hasKey $auths (include "tp-cp-configuration.image.registry" .) }}
                  {{- $creds := (get $auths (include "tp-cp-configuration.image.registry" .) )}}
                  {{- $creds | toJson }}
                {{- else }}
                  {{- fail (printf "auths key does not have credential for container registry '%s' in the dockerconfigjson in container registry secret '%s' " (include "cp-env.container-registry-url" .) (include "tp-cp-configuration.container-registry.secret" .)) }}
                {{- end }}
              {{- else }}
                {{- fail (printf "auths key missing in the dockerconfigjson in container registry secret '%s' " (include "tp-cp-configuration.container-registry.secret" .)) }}
              {{- end }}
            {{- else }}
              {{- fail (printf ".dockerconfigjson key is not a valid json in the container registry secret '%s' " (include "tp-cp-configuration.container-registry.secret" .)) }}
            {{- end }} 
          {{- else }}
            {{- fail (printf "failed to decode docker config container registry secret '%s'. Please verify the secret contents manually " (include "tp-cp-configuration.container-registry.secret" .)) }}
          {{- end }}
        {{- else }}      
          {{- fail (printf ".dockerconfigjson key missing in the container registry secret '%s' " (include "tp-cp-configuration.container-registry.secret" .)) }}
        {{- end }}
      {{- else }}
        {{- fail (printf "data key missing in the container registry secret '%s' " (include "tp-cp-configuration.container-registry.secret" .)) }}
      {{- end }}
    {{- else }}
      {{/* ignore as secret not found */}}
    {{- end }}
  {{- else }}
    {{/* ignore as secret is not created  */}}
  {{- end }}
{{- end }}

{{- define "tp-cp-configuration.container-registry-username" -}}
  {{- $creds := (include "tp-cp-configuration.container-registry-credential" .) | fromJson }}
  {{- if $creds }}
    {{- if hasKey $creds "username" }}
      {{- get $creds "username" }}
    {{- end }}
  {{- else }}
     {{- /* ignore as secret not found*/}}
  {{- end }}
{{- end }}
{{- define "tp-cp-configuration.container-registry-password" -}}
  {{- $creds := (include "tp-cp-configuration.container-registry-credential" .) | fromJson }}
  {{- if $creds }}
    {{- if hasKey $creds "password" }}
      {{- get $creds "password" }}
    {{- end }}
  {{- else }}
     {{- /* ignore as secret not found*/}}
  {{- end }}
{{- end }}

/*{{/* Control plane logging fluentbit. default value true */}}
{{- define "tp-cp-configuration.cp-logging-fluentbit-enabled" }}
  {{- include "cp-env.get" (dict "key" "CP_LOGGING_FLUENTBIT_ENABLED" "default" "true" "required" "false"  "Release" .Release )}}
{{- end }}*/