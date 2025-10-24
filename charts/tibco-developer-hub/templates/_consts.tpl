{{/*
Copyright © 2025. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/* Name of the app secrets */}}
{{- define "backstage.appEnvSecretsName" }}backstage-app-secrets{{ end -}}

{{/* Secret name created as part of client credentials generation */}}
{{- define "tibcohub.consts.outputSecretName"}}tibco-developer-hub-client-credentials{{ end -}}

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tibcohub.consts.appName" }}tibco-developer-hub{{ end -}}