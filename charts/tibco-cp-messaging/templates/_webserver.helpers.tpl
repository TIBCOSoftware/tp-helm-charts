{{/*
MSGDP Controlplane Webserver Helpers
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

*/}}

{{/*
need.msg.webserver.params
*/}}
{{ define "need.msg.webserver.params" }}
{{-  $cpParams := include "need.msg.cp.params" . | fromYaml -}}
# Fill in $webserverParams yaml
{{ include "need.msg.cp.params" . }}
webserver:
  boot:
    volName: scripts-vol
    storageType: configMap
    storageName: tp-cp-msg-webserver-scripts
    readOnly: true
securityProfile: "{{ .Values.webserver.securityProfile | default $cpParams.securityProfile | default "pss-restricted" }}"
{{ end }}
