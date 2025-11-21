# Copyright © 2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tibcohub-recipes.consts.appName" }}tibcohub-recipe{{ end -}}

{{/* Tenant name. */}}
{{- define "tibcohub-recipes.consts.tenantName" }}tibcohub{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tibcohub-recipes.consts.component" }}tibcohub-recipes{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tibcohub-recipes.consts.team" }}cic-compute{{ end -}}

