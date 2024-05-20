{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* Generate tibtunnel configure command using values params. Ex: tp-tibtunnel configure --tibcoDataPlaneId abcd -a accessKey --config-dir /opt/config/tibtunnel */}}
{{- define "tp-tibtunnel.helpers.command.configure" -}}
{{- $profile := printf "%s%s" (ternary "--profile " "" (ne .Values.configure.profile "")) .Values.configure.profile  -}}
{{- $dataPlaneId := printf "%s%s" (ternary "--tibcoDataPlaneId " "" (ne .Values.global.tibco.dataPlaneId "")) .Values.global.tibco.dataPlaneId -}}
{{- /*--access-key is passed as an env variable and resolved at runtime. This is required as we are storing ACCESS_KEY in a k8s secret and the pod reads from env*/ -}}
tp-tibtunnel configure {{ $profile }} {{ $dataPlaneId }} --config-dir {{.Values.configDir}} --log-format json
{{- end -}}

{{/* Generate tibtunnel connect command using values params. Ex: tp-tibtunnel connect -d --config-dir /etc/config/tibtunnel --data-ack-mode=false --remote-debug --network-check-url */}}
{{- define "tp-tibtunnel.helpers.command.connect" -}}
{{- $profile := printf "%s%s" (ternary "--profile " "" (ne .Values.connect.profile "")) .Values.connect.profile  -}}
{{- $debug := ternary "-d" "" .Values.connect.debug  -}}
{{- $payload := ternary "--payload" "" .Values.connect.payload -}}
{{- $dataChunkSize := printf "%s%s" (ternary "--data-chunk-size " "" ( ne (.Values.connect.dataChunkSize| toString ) "")) (.Values.connect.dataChunkSize|toString) -}}
{{- $dataAckMode := printf "%s%t" "--data-ack-mode=" .Values.connect.dataAckMode -}}
{{- $remoteDebug := ternary "--remote-debug" "" .Values.connect.remoteDebug -}}
{{- $logFile := printf "%s%s" (ternary "--log-file " "" (ne .Values.connect.logFile "")) .Values.connect.logFile }}
{{- $networkCheckUrl := printf "%s%s" (ternary "--network-check-url " "" (ne .Values.connect.networkCheckUrl "")) .Values.connect.networkCheckUrl }}
{{- $infiniteRetries := ternary "--infinite-retries" "" .Values.connect.infiniteRetries -}}
tp-tibtunnel connect {{ $debug }} --config-dir {{.Values.configDir}} --log-format json {{ $payload }} {{ $dataChunkSize }} {{ $dataAckMode }} {{ $remoteDebug }}  {{ $logFile }} {{ $profile }} {{ $networkCheckUrl }} {{ $infiniteRetries }} -s {{ tpl .Values.connect.onPremHost .}}:{{.Values.connect.onPremPort}} {{ .Values.connect.url }}
{{- end -}}