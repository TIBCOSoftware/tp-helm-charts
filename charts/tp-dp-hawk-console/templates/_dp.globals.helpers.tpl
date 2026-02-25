{{/*
MSG DP Globals Helpers
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
*/}}

{{/* Map DP globals
    call as: include "dp.values.global" (toJson . | fromJson)
*/}}

{{- define "dp.values.global" -}}
{{- include "dp.values.global.dig" . -}}
{{- end -}}

{{- define "dp.values.global.dig" -}}
{{- $dpId := dig "Values" "global" "cp" "dataplaneId" "" . | default "no-dpName" -}}
cp:
  dpUrl:
    host: {{ dig "Values" "global" "cp" "dpUrl" "host" "" . | default (printf "dp-%s.platform.local" $dpId) | quote }}
    port: {{ dig "Values" "global" "cp" "dpUrl" "port" "" . | default 443 | int }}
{{- end -}}
