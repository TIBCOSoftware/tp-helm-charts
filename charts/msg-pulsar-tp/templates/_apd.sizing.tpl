
{{/*
MSGDP Pulsar Pod sizing 
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
*/}}

{{/*
msg.apd.sizing.spec
.. missing components defaults to toolset spec
.. missing size defaults to medium
*/}}
{{ define "msg.apd.sizing.spec" }}
zookeeper:
  small:
    replicas: 3
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 256Mi
    memLm: 1024Mi
    jvmMs: 128m
    jvmMx: 758m
    jvmDir: 128m
  medium:
    replicas: 3
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1664m
  large:
    replicas: 5
    cpuRq: 200m
    cpuLm: 2000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1664m
  xlarge:
    replicas: 5
    cpuRq: 200m
    cpuLm: 4000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1664m
bookkeeper:
  small:
    replicas: 3
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 256Mi
    memLm: 1024Mi
    jvmMs: 128m
    jvmMx: 758m
    jvmDir: 128m
  medium:
    replicas: 3
    cpuRq: 200m
    cpuLm: 2000m
    memRq: 512Mi
    memLm: 4096Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 3840m
  large:
    replicas: 4
    cpuRq: 200m
    cpuLm: 2000m
    memRq: 512Mi
    memLm: 4096Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 3840m
  xlarge:
    replicas: 6
    cpuRq: 1000m
    cpuLm: 4000m
    memRq: 4Gi
    memLm: 12Gi
    jvmMs: 2048m
    jvmDir: 2048m
    jvmMx: 8100m
broker:
  small:
    replicas: 2
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 256Mi
    memLm: 1024Mi
    jvmMs: 128m
    jvmMx: 758m
    jvmDir: 128m
  medium:
    replicas: 3
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
  large:
    replicas: 4
    cpuRq: 200m
    cpuLm: 2000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
  xlarge:
    replicas: 5
    cpuRq: 200m
    cpuLm: 4000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
broker-init:
  medium:
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 2048Mi
    memLm: 3072Mi
proxy:
  small:
    replicas: 2
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 256Mi
    memLm: 1024Mi
    jvmMs: 128m
    jvmMx: 758m
    jvmDir: 128m
  medium:
    replicas: 2
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
  large:
    replicas: 3
    cpuRq: 200m
    cpuLm: 2000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
  xlarge:
    replicas: 3
    cpuRq: 200m
    cpuLm: 4000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
proxy-init:
  medium:
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 2048Mi
    memLm: 3072Mi
recovery:
  small:
    replicas: 1
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 256Mi
    memLm: 1024Mi
    jvmMs: 128m
    jvmMx: 758m
    jvmDir: 128m
  medium:
    replicas: 1
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
toolset:
  small:
    replicas: 1
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 256Mi
    memLm: 1024Mi
    jvmMs: 128m
    jvmMx: 758m
    jvmDir: 128m
  medium:
    replicas: 1
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 512Mi
    memLm: 2048Mi
    jvmMs: 256m
    jvmDir: 256m
    jvmMx: 1526m
job:
  medium:
    replicas: 1
    cpuRq: 100m
    cpuLm: 1000m
    memRq: 512Mi
    memLm: 4096Mi
{{ end }}

{{ define "msg.apd.sizing.values" }}
zookeeper:
  {{- if .Values.zookeeper.resources }}
{{ toYaml .Values.zookeeper.resources | indent 2 }}
 {{- end }}
bookkeeper:
  {{- if .Values.bookkeeper.resources }}
{{ toYaml .Values.bookkeeper.resources | indent 2 }}
  {{- end }}
broker:
  {{- if .Values.broker.resources }}
{{ toYaml .Values.broker.resources | indent 2 }}
  {{- end }}
proxy:
  {{- if .Values.proxy.resources }}
{{ toYaml .Values.proxy.resources | indent 2 }}
  {{- end }}
recovery:
  {{- if .Values.autorecovery.resources }}
{{ toYaml .Values.autorecovery.resources | indent 2 }}
  {{- end }}
toolset:
  {{- if .Values.toolset.resources }}
{{ toYaml .Values.toolset.resources | indent 2 }}
  {{- end }}
pulsar-init:
  {{- if .Values.pulsar_metadata.resources }}
{{ toYaml .Values.pulsar_metadata.resources | indent 2 }}
  {{- end }}
bookkeeper-init:
  {{- if .Values.bookkeeper.metadata.resources }}
{{ toYaml .Values.bookkeeper.metadata.resources | indent 2 }}
  {{- end }}
job:
  {{- if .Values.job.resources }}
{{ toYaml .Values.job.resources | indent 2 }}
  {{- end }}
{{ end }}

{{/*
apd.sts.resources - get Pulsar sts pod resources
call with (dict "comp" $component "param" $apdParams "root" . )
*/}}
{{- define "apd.sts.resources" -}}
{{- if .param.dp.enableResourceConstraints }}
{{- $sizeValues := include "msg.apd.sizing.values" . | fromYaml -}}
{{- $compValues := dict -}}
    {{- if hasKey $sizeValues .comp -}}
        {{- $compValues = get $sizeValues .comp -}}
    {{- end -}}
{{-  $sizeSpec := include "msg.apd.sizing.spec" . | fromYaml -}}
{{- $compSpec := get $sizeSpec "toolset" -}}
    {{- if hasKey $sizeSpec .comp -}}
        {{- $compSpec = get $sizeSpec .comp -}}
    {{- end -}}
{{- $spec := get $compSpec "medium" }}
    {{- if hasKey $compSpec .param.apd.sizing -}}
        {{- $spec = get $compSpec .param.apd.sizing -}}
    {{- end }}
{{- if $compValues }}
{{ toYaml $compValues | indent 2 }}
{{- else if $spec }}
requests:
    {{- if .param.apd.isProduction }}
  cpu: {{ $spec.cpuLm | quote }}
  memory: {{ $spec.memLm | quote }}
    {{- else }}
  cpu: {{ $spec.cpuRq | quote }}
  memory: {{ $spec.memRq | quote }}
    {{- end }}
limits:
  cpu: {{ $spec.cpuLm | quote }}
  memory: {{ $spec.memLm | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
apd.sts.size.labels - set Pulsar sts pod sizing labels
call with (dict "comp" $component "param" $apdParams "root" . )
*/}}
{{- define "apd.sts.size.labels" -}}
{{-  $sizeSpec := include "msg.apd.sizing.spec" . | fromYaml -}}
{{- $compSpec := get $sizeSpec "toolset" -}}
    {{- if hasKey $sizeSpec .comp -}}
        {{- $compSpec = get $sizeSpec .comp -}}
    {{- end -}}
{{- $spec := get $compSpec "medium" }}
    {{- if hasKey $compSpec .param.apd.sizing -}}
        {{- $spec = get $compSpec .param.apd.sizing -}}
    {{- end }}
platform.tibco.com/app.resources.requests.cpu: {{ $spec.cpuRq | quote }}
platform.tibco.com/app.resources.requests.memory: {{ $spec.memRq | quote }}
platform.tibco.com/app.resources.limits.cpu: {{ $spec.cpuLm | quote }}
platform.tibco.com/app.resources.limits.memory: {{ $spec.memLm | quote }}
{{- end }}

{{/*
apd.sts.replicas - get Pulsar sts replicas count
call with (dict "comp" $component "param" $apdParams "root" . )
*/}}
{{- define "apd.sts.replicas" -}}
{{-  $sizeSpec := include "msg.apd.sizing.spec" . | fromYaml -}}
{{- $compSpec := get $sizeSpec "toolset" -}}
    {{- if hasKey $sizeSpec .comp -}}
        {{- $compSpec = get $sizeSpec .comp -}}
    {{- end -}}
{{- $spec := get $compSpec "medium" }}
    {{- if hasKey $compSpec .param.apd.sizing -}}
        {{- $spec = get $compSpec .param.apd.sizing -}}
    {{- end }}
{{- if not .param.dp.enableClusterScopedPerm -}}
  {{- if and (eq "bookkeeper" .comp) (gt ($spec.replicas | default 0 | int) 3 ) -}}
    {{ fail (printf "Bookie replicas %d > 3 requires get-nodes rack-aware placment" ( $spec.replicas | int)) }}
  {{- end -}}
{{- end -}}
{{- $spec.replicas | int }}
{{- end }}

{{/*
apd.sts.java.mem - get Pulsar java JVM setting string
call with (dict "comp" $component "param" $apdParams "root" . )
*/}}
{{- define "apd.sts.java.mem" -}}
{{-  $sizeSpec := include "msg.apd.sizing.spec" . | fromYaml -}}
{{- $compSpec := get $sizeSpec "toolset" -}}
    {{- if hasKey $sizeSpec .comp -}}
        {{- $compSpec = get $sizeSpec .comp -}}
    {{- end -}}
{{- $spec := get $compSpec "medium" }}
    {{- if hasKey $compSpec .param.apd.sizing -}}
        {{- $spec = get $compSpec .param.apd.sizing -}}
    {{- end }}
{{- printf "-Xms%s -Xmx%s -XX:MaxDirectMemorySize=%s" $spec.jvmMs $spec.jvmMx $spec.jvmDir }}
{{- end }}
