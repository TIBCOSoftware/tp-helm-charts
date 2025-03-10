{{/*
    Copyright © 2024. Cloud Software Group, Inc.
    This file is subject to the license terms contained
    in the license file that is distributed with this file.
*/}}
{{/* 
    NOTES: 
      - Helpers below are making some assumptions regarding files Chart.yaml and values.yaml. Change carefully!
      - Any change in this file needs to be synchronized with all charts
*/}}


{{/*
================================================================
                  SECTION COMMON VARS
================================================================   
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "dp-configure-namespace.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dp-configure-namespace.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "dp-configure-namespace.appName" }}dp-configure-namespace{{ end -}}

{{/* Tenant name. */}}
{{- define "dp-configure-namespace.tenantName" }}infrastructure{{ end -}}

{{- define "dp-configure-namespace.part-of" }}"tibco-platform"{{ end -}}

{{/* Component we're a part of. */}}
{{- define "dp-configure-namespace.component" }}tibco-platform-data-plane{{ end -}}

{{/* Team we're a part of. */}}
{{- define "dp-configure-namespace.team" }}cic-compute{{ end -}}

{{/* Data plane workload type */}}
{{- define "dp-configure-namespace.workloadType" }}infra{{ end -}}

{{/* Data plane primary namespace name */}}
{{- define "dp-configure-namespace.primaryNamespaceName" }}{{ required "global.tibco.primaryNamespaceName is required" .Values.global.tibco.primaryNamespaceName }}{{ end -}}

{{/* Data plane service account */}}
{{- define "dp-configure-namespace.serviceAccount" }}{{ required "global.tibco.serviceAccount is required" .Values.global.tibco.serviceAccount }}{{ end -}}

{{/* Data plane dataPlane id */}}
{{- define "dp-configure-namespace.dataPlaneId" }}{{ required "global.tibco.dataPlaneId is required" .Values.global.tibco.dataPlaneId }}{{ end -}}

{{/* Node Cidr for the cluster */}}
{{- define "dp-configure-namespace.nodeCidr" }}
{{- if .Values.networkPolicy.create }}
{{- required (printf "networkPolicy.nodeCidrIpBlock is required, if Network Policy is enabled.\nIf Node CIDR and Pod CIDR are different, both need to be passed from values.\nOtherwise same values will be used for .networkPolicy.nodeCidrIpBlock and .networkPolicy.podCidrIpBlock.\n\nUse --set networkPolicy.nodeCidrIpBlock=<NodeIpCidr>\nNodeIpCidr=<IP range of Nodes VPC or VNet address space (CIDR notation)> e.g. 10.200.0.0/16\n\nUse --set networkPolicy.podCidrIpBlock=<PodIpCidr>\nPodIpCidr=<IP range of Pod IP CIDR (CIDR notation)> e.g. 192.168.0.0/16") .Values.networkPolicy.nodeCidrIpBlock -}}
{{- end }}
{{- end }}

{{/* Pod Cidr for the cluster */}}
{{- define "dp-configure-namespace.podCidr" }}
{{- if .Values.networkPolicy.create }}
{{- if empty .Values.networkPolicy.podCidrIpBlock }}
{{- .Values.networkPolicy.nodeCidrIpBlock }}
{{- else }}
{{- .Values.networkPolicy.podCidrIpBlock }}
{{- end }}
{{- end }}
{{- end }}

{{/* Service Cidr for the cluster */}}
{{- define "dp-configure-namespace.serviceCidr" }}
{{- if .Values.networkPolicy.create }}
{{- required (printf "networkPolicy.serviceCidrIpBlock is required, if Network Policy is enabled.\n\nUse --set networkPolicy.serviceCidrIpBlock=<ServiceIpCidr>\nServiceIpCidr=<IP range of Service CIDR (CIDR notation)> e.g. 172.20.0.0/16") .Values.networkPolicy.serviceCidrIpBlock -}}
{{- end }}
{{- end }}

{{/*
================================================================
                  SECTION LABELS
================================================================   
*/}}

{{/*
Common labels
*/}}
{{- define "dp-configure-namespace.labels" -}}
helm.sh/chart: {{ include "dp-configure-namespace.chart" . }}
{{ include "dp-configure-namespace.selectorLabels" . }}
{{ include "dp-configure-namespace.platformLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.cloud.tibco.com/created-by: {{ include "dp-configure-namespace.team" .}}
{{- end -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "dp-configure-namespace.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dp-configure-namespace.name" . }}
app.kubernetes.io/component: {{ include "dp-configure-namespace.component" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "dp-configure-namespace.part-of" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Platform labels to be added in all the resources created by this chart.*/}}
{{- define "dp-configure-namespace.platformLabels" -}}
platform.tibco.com/dataplane-id: {{ .Values.global.tibco.dataPlaneId }}
{{- end -}}

{{/*
================================================================
                  FUNCTIONS
================================================================
*/}}


{{/* Verify platform label for the release namespace.*/}}
{{- define "dp-configure-namespace.validate-namespace" -}}
{{- $ns_name := .Release.Namespace -}}
{{- $ns := (lookup "v1" "Namespace" "" $ns_name) -}}
{{- if $ns -}}
{{- if $ns.metadata.labels -}}
{{- if (hasKey $ns.metadata.labels "platform.tibco.com/dataplane-id" ) -}}
{{- if eq (get $ns.metadata.labels "platform.tibco.com/dataplane-id") .Values.global.tibco.dataPlaneId -}}
{{- printf "Namespace %s validation for data plane id %s label is successful." $ns_name .Values.global.tibco.dataPlaneId -}}
{{- else -}}
{{- printf "Namespace %s is NOT labelled with the correct data plane id %s." $ns_name .Values.global.tibco.dataPlaneId | fail -}}
{{- end -}}
{{- else -}}
{{- printf "Namespace %s does not have label platform.tibco.com/dataplane-id." $ns_name | fail -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{/* no op is ns does not exists. We expect the ns to be already present. We have this to avoid helm templating issue*/}}
{{- end -}}
{{- end -}}