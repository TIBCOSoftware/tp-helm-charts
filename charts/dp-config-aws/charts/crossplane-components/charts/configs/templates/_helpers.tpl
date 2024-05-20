{{/*
Copyright © 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cluster-env" -}}
{{- $data := (lookup "v1" "ConfigMap" "kube-system" "tibco-platform-infra") }}
{{- $data | toYaml }}
{{- end -}}

{{- define "configs.cloud-account-id" -}}
  {{- include "cluster-env.get" (dict "key" "CLOUD_ACCOUNT_ID" "Release" .Release) }}
{{- end -}}
