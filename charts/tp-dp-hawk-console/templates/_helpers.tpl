{{/*

Copyright © 2023 - 2024. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.

*/}}

{{/*
    Certificate material for the hawkconsole service, as a dict of base64 values.
    Reuses the existing Secret on upgrade; the result is cached on .Values so every
    template in the same render (Secret and ConfigMap) sees the identical CA.
*/}}

{{- define "tp-dp-hawk-console.certs" -}}
{{- $cached := index .Values "_hawkConsoleCerts" -}}
{{- if not $cached -}}
{{- $fullname := include "tp-dp-hawk-console.consts.appName" . -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (printf "%s-certs" $fullname) -}}
{{- if and $existing $existing.data (index $existing.data "ca.crt") -}}
{{- $cached = $existing.data -}}
{{- else -}}
{{- $altNames := list ( printf "%s.%s" $fullname .Release.Namespace ) ( printf "%s.%s.svc" $fullname .Release.Namespace ) -}}
{{- $ca := genCA "tp-dp-hawk-console-ca" 1825 -}}
{{- $cert := genSignedCert $fullname nil $altNames 1825 $ca -}}
{{- $cached = dict "ca.crt" ($ca.Cert | b64enc) "tls.crt" ($cert.Cert | b64enc) "tls.key" ($cert.Key | b64enc) -}}
{{- end -}}
{{- $_ := set .Values "_hawkConsoleCerts" $cached -}}
{{- end -}}
{{- toYaml $cached -}}
{{- end -}}

{{/*
    Generate certificates for hawkconsole service
*/}}

{{- define "tp-dp-hawk-console.gencerts" -}}
{{- include "tp-dp-hawk-console.certs" . -}}
{{- end -}}

{{/*
    Non-empty when the traefik Ingress path is active. The Service annotations and the
    ServersTransport they reference are in different files, so both must gate on this.
*/}}

{{- define "tp-dp-hawk-console.traefikIngressActive" -}}
{{- $rr := .Values.global.cp.routeResources -}}
{{- $en := default dict .Values.dp.routing.enabled -}}
{{- if and .Values.enableIngress (eq $rr.ingress.ingressController "traefik") (empty $rr.gatewayapi.gatewayAPIControllerName) $en.traefik -}}
true
{{- end -}}
{{- end -}}

{{/*
    PEM-decoded CA certificate, taken from the same material as the certs Secret.
*/}}

{{- define "tp-dp-hawk-console.getSecretCa" -}}
{{- $ctx := .context | required "context is required" -}}
{{- $key := .key | required "Secret key is required" -}}
{{- $certs := include "tp-dp-hawk-console.certs" $ctx | fromYaml -}}
{{- index $certs $key | b64dec -}}
{{- end -}}
