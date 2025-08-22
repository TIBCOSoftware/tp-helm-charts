{{/*
Kubernetes API Version Detection Helpers
*/}}

{{/*
Return the appropriate API version for HPA.
*/}}
{{- define "jaeger.capabilities.hpa.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "autoscaling/v2" -}}
{{- print "autoscaling/v2" -}}
{{- else if .Capabilities.APIVersions.Has "autoscaling/v2beta2" -}}
{{- print "autoscaling/v2beta2" -}}
{{- else -}}
{{- print "autoscaling/v2beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate API version for Deployment.
*/}}
{{- define "jaeger.capabilities.deployment.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "apps/v1" -}}
{{- print "apps/v1" -}}
{{- else -}}
{{- print "apps/v1beta2" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate API version for Ingress.
*/}}
{{- define "jaeger.capabilities.ingress.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1" -}}
{{- print "networking.k8s.io/v1" -}}
{{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "extensions/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate API version for CronJob.
*/}}
{{- define "jaeger.capabilities.cronjob.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "batch/v1" -}}
{{- print "batch/v1" -}}
{{- else -}}
{{- print "batch/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate API version for NetworkPolicy.
*/}}
{{- define "jaeger.capabilities.networkPolicy.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1" -}}
{{- print "networking.k8s.io/v1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Render a template value with context.
Usage: {{ include "jaeger.tplvalues.render" (dict "value" .Values.someValue "context" $) }}
*/}}
{{- define "jaeger.tplvalues.render" -}}
{{- if typeIs "string" .value }}
  {{- tpl .value .context }}
{{- else }}
  {{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end -}}

{{/*
Check if ingress supports IngressClassName.
*/}}
{{- define "jaeger.ingress.supportsIngressClassname" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1" -}}
{{- print "true" -}}
{{- else -}}
{{- print "false" -}}
{{- end -}}
{{- end -}}

{{/*
Generate ingress backend configuration based on API version.
Usage: {{ include "jaeger.ingress.backend" (dict "serviceName" "my-service" "servicePort" 80 "context" $) }}
*/}}
{{- define "jaeger.ingress.backend" -}}
{{- $apiVersion := include "jaeger.capabilities.ingress.apiVersion" .context -}}
{{- if eq $apiVersion "networking.k8s.io/v1" -}}
service:
  name: {{ .serviceName }}
  port:
    {{- if typeIs "string" .servicePort }}
    name: {{ .servicePort }}
    {{- else }}
    number: {{ .servicePort }}
    {{- end }}
{{- else -}}
serviceName: {{ .serviceName }}
servicePort: {{ .servicePort }}
{{- end -}}
{{- end -}}
