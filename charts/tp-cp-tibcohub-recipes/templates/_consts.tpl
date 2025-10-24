# Copyright © 2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

{{/* A fixed short name for the application. Can be different than the chart name */}}
{{- define "tp-cp-tibcohub-recipes.consts.appName" }}tp-dp-tibcohub-recipe{{ end -}}

{{/* Tenant name. */}}
{{- define "tp-cp-tibcohub-recipes.consts.tenantName" }}tibcohub{{ end -}}

{{/* Component we're a part of. */}}
{{- define "tp-cp-tibcohub-recipes.consts.component" }}tp-cp-tibcohub-recipes{{ end -}}

{{/* Team we're a part of. */}}
{{- define "tp-cp-tibcohub-recipes.consts.team" }}cic-compute{{ end -}}

