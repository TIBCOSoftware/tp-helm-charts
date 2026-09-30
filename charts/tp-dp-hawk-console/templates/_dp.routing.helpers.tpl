{{/*
DP routing helpers shared by every chart that publishes routes.
*/}}

{{/*
msg.dp.routing.ic - name of the single active ingress controller for this DP.
Fails the render when the selected controller is not enabled, so callers may assume
exactly one controller block applies. Every action is fully trimmed: the only output
is the controller name.
*/}}
{{- define "msg.dp.routing.ic" -}}
{{- $rr := .Values.global.cp.routeResources -}}
{{- $en := default dict .Values.dp.routing.enabled -}}
{{- $ic := $rr.ingress.ingressController | default "haProxy" -}}
{{- if not (empty $rr.gatewayapi.gatewayAPIControllerName) -}}{{- $ic = "gatewayapi" -}}{{- end -}}
{{- $deny := "" -}}
{{- if not (index $en $ic) -}}{{- $deny = $ic -}}{{- end -}}
{{- if and (eq $ic "gatewayapi") (empty $deny) -}}
  {{- $allow := default (list) .Values.dp.routing.gatewayapi.allowedControllers -}}
  {{- if and (not (empty $allow)) (not (has (lower $rr.gatewayapi.gatewayAPIControllerName) $allow)) -}}{{- $deny = $rr.gatewayapi.gatewayAPIControllerName -}}{{- end -}}
{{- end -}}
{{- if $deny -}}{{- fail (printf "ingress controller %q is not enabled yet." $deny) -}}{{- end -}}
{{- $ic -}}
{{- end -}}
