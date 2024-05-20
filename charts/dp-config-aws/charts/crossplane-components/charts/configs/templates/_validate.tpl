{{/* 
Copyright © 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
================================================================
                  SECTION VALIDATION
================================================================   
*/}}

{{- define "configs.validate" -}}
{{- required (printf "crossplane-components.configs.iamRoleName is required to be passed as halm values\nPlease ensure the role has the required capabilities to create AWS resources") .Values.iamRoleName -}}
{{- end }}