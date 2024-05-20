{{/*
Copyright © 2024. Cloud Software Group, Inc.
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
{{- define "claims.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "claims.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "claims.component" -}}claims{{- end }}

{{- define "claims.part-of" -}}
{{- "tibco-platform" }}
{{- end }}

{{- define "claims.team" -}}
{{- "cic-compute" }}
{{- end }}

{{- define "claims.appName" -}}
{{- "claims" }}
{{- end }}

{{/* Control plane environment configuration. This will have shared configuration used across control plane components. */}}
{{- define "cluster-env" -}}
{{- $data := (lookup "v1" "ConfigMap" "kube-system" "tibco-platform-infra") }}
{{- $data | toYaml }}
{{- end -}}

{{- define "claims.cloud-account-id" -}}
  {{- include "cluster-env.get" (dict "key" "CLOUD_ACCOUNT_ID" "Release" .Release) }}
{{- end -}}

{{- define "claims.cloud-region" -}}
  {{- include "cluster-env.get" (dict "key" "CLOUD_REGION" "Release" .Release) }}
{{- end -}}

{{- define "claims.net-vpc-identifier" -}}
  {{- include "cluster-env.get" (dict "key" "NET_VPC_IDENTIFIER" "Release" .Release) }}
{{- end -}}

{{- define "claims.net-node-cidr" -}}
  {{- include "cluster-env.get" (dict "key" "NET_NODE_CIDR" "Release" .Release) }}
{{- end -}}

{{- define "claims.net-private-subnets" -}}
  {{- include "cluster-env.get" (dict "key" "NET_PRIVATE_SUBNETS" "Release" .Release) | trimSuffix "\n" }}
{{- end -}}

{{- define "claims.net-public-subnets" -}}
  {{- include "cluster-env.get" (dict "key" "NET_PUBLIC_SUBNETS" "Release" .Release) | trimSuffix "\n" }}
{{- end -}}

{{- define "claims.oidc-issuer-hostpath" -}}
  {{- include "cluster-env.get" (dict "key" "OIDC_ISSUER_HOSTPATH" "Release" .Release) }}
{{- end -}}

{{- define "claims.oidc-issuer-url" -}}
  {{- include "cluster-env.get" (dict "key" "OIDC_ISSUER_URL" "Release" .Release) }}
{{- end -}}

{{- define "claims.oidc-provider-arn" -}}
  {{- include "cluster-env.get" (dict "key" "OIDC_PROVIDER_ARN" "Release" .Release) }}
{{- end -}}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "claims.labels" -}}
helm.sh/chart: {{ include "claims.chart" . }}
{{ include "claims.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "claims.team" .}}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "claims.selectorLabels" -}}
app.kubernetes.io/name: {{ include "claims.name" . }}
app.kubernetes.io/component: {{ include "claims.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "claims.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
