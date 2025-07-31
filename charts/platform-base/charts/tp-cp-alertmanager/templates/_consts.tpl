{{/*
Copyright 2025 Alert Manager Community Charts

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-alertmanager.consts.appName" }}alertmanager{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-alertmanager.consts.team" }}infra{{ end -}}

{{/* Namespace we're going into. */}}
{{- define "tp-cp-alertmanager.consts.namespace" }}{{ .Release.Namespace }}{{ end -}}

{{- define "tp-cp-alertmanager.container-registry.secret" }}tibco-container-registry-credentials{{end}}

{{/* set repository based on the registry url. We will have different repo for each one. */}}
{{- define "tp-cp-alertmanager.image.repository" -}}
  {{- default "tibco-platform-docker-prod" .Values.global.tibco.containerRegistry.repository }}
{{- end -}}

