{{/*
Copyright © 2023. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* Validate value of fileSystemId */}}
{{- define "dpConfigAws.validateValues.fileSystemId" -}}
{{ if .Values.storageClass.efs.enabled }}
{{ required "storageClass.efs.parameters.fileSystemId is required when efs is enabled" .Values.storageClass.efs.parameters.fileSystemId}}
{{- end -}}
{{- end -}}

{{/* Build the list of port for service */}}
{{- define "service.servicePortsConfig" -}}
{{- $ports := deepCopy .Values.service.ports }}
{{- range $key, $port := $ports }}
{{- if $port.enabled }}
- name: {{ $key }}
  port: {{ $port.servicePort }}
  targetPort: {{ $port.containerPort }}
  protocol: {{ $port.protocol }}
  {{- if $port.appProtocol }}
  appProtocol: {{ $port.appProtocol }}
  {{- end }}
{{- if $port.nodePort }}
  nodePort: {{ $port.nodePort }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}