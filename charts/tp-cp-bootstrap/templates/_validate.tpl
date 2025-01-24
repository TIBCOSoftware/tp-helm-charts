{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
================================================================
                  SECTION VALIDATION
================================================================   
*/}}

{{- define "tp-cp-bootstrap.validate" -}}

{{- with .Values.global.tibco.containerRegistry }}
{{/* Check for container registry */}}
{{- if .url }}
{{- if contains "jfrog.io" .url }}
{{/* Check for container registry username */}}
{{- if .username }}
{{/* no-op if username is provided */}}
{{- else }}
{{- fail (printf "image registry username is not passed as helm values") }}
{{- end }}
{{/* Check for container registry password */}}
{{- if .password }}
{{/* no-op if password is provided */}}
{{- else }}
{{- fail (printf "image registry password is not passed as helm values") }}
{{- end }}
{{- end }}
{{- else }}
{{- fail (printf "image registry url is not passed as helm values") }}
{{- end }}
{{- end }}

{{/* Verify platform label for the control plane namespace.*/}}
{{- $ns_name := .Release.Namespace -}}
{{- $ns := (lookup "v1" "Namespace" "" $ns_name) -}}
{{- if $ns -}}
{{- if $ns.metadata.labels -}}
{{- if (hasKey $ns.metadata.labels "platform.tibco.com/controlplane-instance-id" ) -}}
{{- if eq (get $ns.metadata.labels "platform.tibco.com/controlplane-instance-id") .Values.global.tibco.controlPlaneInstanceId -}}
{{- printf "Namespace %s validation for control plane namespace label is successful." $ns_name -}}
{{- else -}}
{{- printf "Namespace %s is NOT labelled with the correct label platform.tibco.com/controlplane-instance-id %s." $ns_name .Values.global.tibco.controlPlaneInstanceId | fail -}}
{{- end -}}
{{- else -}}
{{- printf "Namespace %s does not have label platform.tibco.com/controlplane-instance-id" $ns_name | fail -}}
{{- end -}}
{{- end -}}
{{- else -}}
{{/* no-op if namespace does not exist. It is expected that the namespace is already created. We have this to avoid helm templating issue */}}
{{- end -}}

{{/* Check for namespace and service account */}}
{{- $ns_name := .Release.Namespace }}
{{- $ns := (lookup "v1" "Namespace" "" $ns_name) }}
{{- if $ns }}
{{/* check for service account */}}
{{- if .Values.global.tibco.serviceAccount }}
{{- $sa := (lookup "v1" "ServiceAccount" $ns_name .Values.global.tibco.serviceAccount) }}
{{- if $sa }}
{{/* no-op if service account exists in the namespace */}}
{{- else }} 
{{- fail (printf "service acccount %s is not present in namespace %s" .Values.global.tibco.serviceAccount .Release.Namespace) }}
{{- end }}
{{- else }}
{{/* default service account will be created */}}
{{- end }}
{{- else }}
{{/* no-op if namespace does not exist. It is expected that the namespace is already created. We have this to avoid helm templating issue */}}
{{- end }}

{{/* Check for nodeCIDR */}}
{{- if .Values.global.tibco.createNetworkPolicy }}
{{- if .Values.global.external.clusterInfo }}
{{- if empty .Values.global.external.clusterInfo.nodeCIDR }}
{{- fail (printf "external.clusterInfo.nodeCIDR is required, if Network Policy is enabled.\nIf Node CIDR and Pod CIDR are different, both need to be passed from values.\nOtherwise same values will be used for global.external.clusterInfo.nodeCIDR and global.external.clusterInfo.podCIDR.\n\nUse --set global.external.clusterInfo.nodeCIDR=<Node_IP_CIDR>\nNode_IP_CIDR=<IP range of Nodes VPC or VNet address space (CIDR notation)> e.g. 10.180.0.0/16\n\nUse --set global.external.clusterInfo.podCIDR=<Pod_IP_CIDR>\nPod_IP_CIDR=<IP range of Pod IP CIDR (CIDR notation)> e.g. 192.168.0.0/16") }}
{{- end }}
{{- if empty .Values.global.external.clusterInfo.serviceCIDR }}
{{- fail (printf "external.clusterInfo.serviceCIDR is required, if Network Policy is enabled.\n\nUse --set global.external.clusterInfo.serviceCIDR=<Service_CIDR>\nService_CIDR=<IP range of Service CIDR (CIDR notation)> e.g. 172.20.0.0/16") }}
{{- end }}
{{- else }}
{{- fail (printf "external.clusterInfo.nodeCIDR and external.clusterInfo.serviceCIDR are required and external.clusterInfo.podCIDR is optional, if Network Policy is enabled.\n\nUse --set global.external.clusterInfo.nodeCIDR=<Node_IP_CIDR>\nNode_IP_CIDR=<IP range of Nodes VPC or VNet address space (CIDR notation)> e.g. 10.180.0.0/16\n\nUse --set global.external.clusterInfo.podCIDR=<Pod_IP_CIDR>\nPod_IP_CIDR=<IP range of Pod IP CIDR (CIDR notation)> e.g. 192.168.0.0/16\n\nUse --set global.external.clusterInfo.serviceCIDR=<Service_CIDR>\nService_CIDR=<IP range of Service CIDR (CIDR notation)> e.g. 172.20.0.0/16") }}
{{- end }}
{{- end }}

{{/* Check for control plane instance Id */}}
{{- if .Values.global.tibco.controlPlaneInstanceId }}
{{- else }}
{{- fail (printf "control plane instance id is not passed as helm values") }}
{{- end }}

{{/* Check for logserver */}}
{{- if .Values.global.external.logserver }}
{{- if empty .Values.global.external.logserver.endpoint }}
{{- fail (printf "external.logserver.endpoint is required") }}
{{- end }}
{{- if empty .Values.global.external.logserver.username }}
{{- fail (printf "external.logserver.username is required") }}
{{- end }}
{{- if empty .Values.global.external.logserver.index }}
{{- fail (printf "external.logserver.index is required") }}
{{- end }}
{{- if empty .Values.global.external.logserver.password }}
{{- fail (printf "external.logserver.password is required") }}
{{- end }}
{{- end }}

{{/* Check for dns tunnel domain */}}
{{- if .Values.global.external.dnsTunnelDomain }}
{{- else }}
{{- fail (printf "dns tunnel domain is not passed as helm values") }}
{{- end }}

{{/* Check for dns domain */}}
{{- if .Values.global.external.dnsDomain }}
{{- else }}
{{- fail (printf "dns domain is not passed as helm values") }}
{{- end }}

{{- end }}