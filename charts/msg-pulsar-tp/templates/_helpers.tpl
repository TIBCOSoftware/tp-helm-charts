{{/*
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
pulsar home
*/}}
{{- define "pulsar.home" -}}
{{- print "/pulsar" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "pulsar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "pulsar.namespace" -}}
{{- default .Release.Namespace .Values.namespace  -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pulsar.fullname" -}}
{{- $localParams := include "need.msg.apd.params" . | fromYaml -}}
{{- $localParams.apd.name -}}
{{- end -}}

{{- define "pulsar.xfullname" -}}
{{-  $localParams := include "need.msg.apd.params" . | fromYaml -}}
{{- if .Values.fullnameOverride -}}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.nameOverride -}}
  {{- $name := default .Chart.Name .Values.nameOverride -}}
  {{- if contains $name .Release.Name -}}
    {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- else -}}
  {{- $localParams.apd.name -}}
{{- end -}}
{{- end -}}

{{/*
Define cluster's name
*/}}
{{- define "pulsar.cluster.name" -}}
{{- if .Values.clusterName }}
{{- .Values.clusterName }}
{{- else -}}
{{- template "pulsar.fullname" .}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pulsar.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the common labels.
*/}}
{{- define "pulsar.standardLabels" -}}
{{-  $localParams := include "need.msg.apd.params" . | fromYaml -}}
{{ include "apd.std.labels" $localParams }}
{{ include "msg.dpparams.labels" $localParams }}
app: {{ template "pulsar.name" . }}
chart: {{ template "pulsar.chart" . }}
release: {{ .Release.Name }}
heritage: {{ .Release.Service }}
cluster: {{ template "pulsar.cluster.name" . }}
{{- if .Values.labels }}
{{ .Values.labels | toYaml | trim }}
{{- end }}
{{- end }}

{{/*
Create the template labels.
*/}}
{{- define "pulsar.template.labels" -}}
{{-  $localParams := include "need.msg.apd.params" . | fromYaml -}}
{{ include "apd.std.labels" $localParams }}
{{ include "msg.dpparams.labels" $localParams }}
app: {{ template "pulsar.name" . }}
release: {{ .Release.Name }}
cluster: {{ template "pulsar.cluster.name" . }}
{{ include "msg.dp.net.kubectl" . }}
{{- if .Values.labels }}
{{ .Values.labels | toYaml | trim }}
{{- end }}
{{- end }}

{{/*
Create the match labels.
*/}}
{{- define "pulsar.matchLabels" -}}
app: {{ template "pulsar.name" . }}
release: {{ .Release.Name }}
tib-msg-group-name: "{{ template "pulsar.fullname" . }}"
{{- end }}

{{/*
Create ImagePullSecrets
*/}}
{{- define "pulsar.imagePullSecrets" -}}
{{-  $localParams := include "need.msg.apd.params" . | fromYaml -}}
{{- if or .Values.images.imagePullSecrets $localParams.dp.pullSecret -}}
imagePullSecrets:
{{- end }}
{{- if .Values.images.imagePullSecrets -}}
{{- range .Values.images.imagePullSecrets }}
- name: {{ . }}
{{- end }}
{{- else if $localParams.dp.pullSecret }}
- name: {{ $localParams.dp.pullSecret }}
{{- end }}
{{- end }}

{{/*
Create full image name
*/}}
{{- define "pulsar.imageFullName" -}}
{{-  $localParams := include "need.msg.apd.params" .root | fromYaml -}}
{{- if .image.repository -}}
{{- printf "%s:%s" .image.repository (.image.tag | default $localParams.apd.imageTag ) -}}
{{- else -}}
{{- printf "%s" $localParams.apd.imageFullName -}}
{{- end -}}
{{- end -}}

{{/*
Create image pull policy
*/}}
{{- define "pulsar.imagePullPolicy" -}}
{{-  $localParams := include "need.msg.apd.params" .root | fromYaml -}}
{{- if .image.pullPolicy -}}
{{- printf "%s" (.image.pullPolicy | default $localParams.dp.pullPolicy ) -}}
{{- else -}}
{{- printf "%s" $localParams.dp.pullPolicy -}}
{{- end -}}
{{- end -}}

{{/*
Create group priviliged serviceAccountName
*/}}
{{- define "pulsar.serviceAccount" -}}
{{-  $localParams := include "need.msg.apd.params" .root | fromYaml -}}
{{- if $localParams.dp.serviceAccount -}}
{{- printf "%s" $localParams.dp.serviceAccount -}}
{{- else -}}
{{- printf "%s-%s-acct" (include "pulsar.fullname" .root ) .component -}}
{{- end -}}
{{- end -}}
