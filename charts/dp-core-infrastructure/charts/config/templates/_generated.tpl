{{/* 

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/* The build number, also used as docker image image tag */}}
{{- define "dp-core-infrastructure-config.generated.buildNumber" }}latest{{end -}}

{{/* The build timestamp, used as a label to force pod upgrade even when deployment.yaml was not changed (dev workflow) */}}
{{- define "dp-core-infrastructure-config.generated.buildTimestamp" }}unknown{{end -}}