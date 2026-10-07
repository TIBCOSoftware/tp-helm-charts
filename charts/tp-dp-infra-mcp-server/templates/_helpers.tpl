{{/*
Copyright © 2026. Cloud Software Group, Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
*/}}

{{/*
Chart name and version for labels.
*/}}
{{- define "tp-infra-mcp-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname — hardcoded, matching provisioner pattern.
*/}}
{{- define "tp-infra-mcp-server.fullname" }}tp-dp-infra-mcp-server{{ end -}}

{{/*
Common labels.
*/}}
{{- define "tp-infra-mcp-server.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "tp-infra-mcp-server.chart" . }}
platform.tibco.com/capability: infra-mcp-server
{{ include "tp-infra-mcp-server.selectorLabels" . }}
{{- end }}

{{/*
Selector labels — includes platform-specific labels matching provisioner pattern.
*/}}
{{- define "tp-infra-mcp-server.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: "infra-mcp"
platform.tibco.com/workload-type: "capability-service"
platform.tibco.com/dataplane-id: {{ .Values.global.cp.dataplaneId }}
platform.tibco.com/capability-instance-id: {{ .Values.global.cp.instanceId }}
{{- end }}

{{/*
ServiceAccount name — supports BYOSA (bring your own service account).
*/}}
{{- define "tp-infra-mcp-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
  {{- .Values.serviceAccount.name -}}
{{- else -}}
  {{- include "tp-infra-mcp-server.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
CP domain — cp-proxy service in the DP namespace.
*/}}
{{- define "tp-infra-mcp-server.cp.domain" }}cp-proxy.{{ .Values.global.cp.resources.serviceaccount.namespace }}.svc.cluster.local{{ end -}}

{{/*
Image pull Secret name. Resolves imagePullSecret > global.cp.containerRegistry.secret >
global.tibco.containerRegistry.secret > global.tibco username+password, and returns empty when
none match so the caller omits the imagePullSecrets key. See README.md, "Container registry pull
secret", for what each arm is for and why arms 3-4 cannot fire on a data plane.

Two traps, both of which fire ONLY in the no-secret case and so survive any hand test that sets
one. Keep the traversals parenthesised: this chart declares no global.tibco key, so a bare
.Values.global.tibco.containerRegistry.username aborts the render on a nil pointer. And never
close with a bare {{- else -}} printing the traversal: nil renders as "<no value>", which Helm strips
from the file but which is TRUTHY to the caller, so the guard would always fire on an empty name.
*/}}
{{- define "tp-infra-mcp-server.container-registry.secret" -}}
{{- if .Values.imagePullSecret -}}
  {{- .Values.imagePullSecret -}}
{{- else if (((.Values.global).cp).containerRegistry).secret -}}
  {{- (((.Values.global).cp).containerRegistry).secret -}}
{{- else if (((.Values.global).tibco).containerRegistry).secret -}}
  {{- (((.Values.global).tibco).containerRegistry).secret -}}
{{- else if and (((.Values.global).tibco).containerRegistry).username (((.Values.global).tibco).containerRegistry).password -}}
  {{- "tibco-container-registry-credentials" -}}
{{- end -}}
{{- end -}}

{{/*
Image registry host.

Deliberately cp-only: across this repo global.cp and global.tibco are a hard fork for
url/repository, not a fallback chain -- no chart resolves one from the other, and inventing that
order here would silently change the registry on any control-plane values tree.

`default ""` coerces a nil traversal before it can reach the join as the truthy "<no value>"
sentinel. trimAll strips trailing slashes on a customer-supplied url, which would otherwise
produce an empty path component in the middle of the reference. It is trimAll rather than
trimSuffix because trimSuffix removes only one, so a url ending "//" would still reach the join
and reintroduce exactly the empty component this helper exists to prevent. A leading slash on a
registry host is never legitimate either, so trimming both ends costs nothing -- and it matches
the repository helper below.
*/}}
{{- define "tp-infra-mcp-server.image.registry" -}}
  {{- (((.Values.global).cp).containerRegistry).url | default "" | trimAll "/" -}}
{{- end -}}

{{/*
Image repository -- the path segment beneath the registry host. Same fork, same coercion.
*/}}
{{- define "tp-infra-mcp-server.image.repository" -}}
  {{- (((.Values.global).cp).containerRegistry).repository | default "" | trimAll "/" -}}
{{- end -}}

{{/*
Fully qualified image reference. Joins ONLY the non-empty segments.

`compact` is the whole point. Interpolating a literal "/" between the parts renders a LEADING
SLASH whenever the registry url is empty (/tibco-platform-docker-prod/tp-infra-mcp-server:70).
An empty first path component is not a valid image reference, so the kubelet reports
InvalidImageName and never attempts a pull -- a permanently non-converging pod rather than a
retryable ImagePullBackOff.

Failing the render on an empty url is not an option: chart linting templates this chart with its
default values, where the url is empty by design and there is no ci/ values directory.

compact is applied ONLY to the registry/repository prefix, because only those two segments are
legitimately optional. The name and the tag are deliberately left outside it. Dropping an empty
name would turn an obviously broken reference into a well-formed one pointing at a DIFFERENT
repository, and dropping an empty tag would hide the omission -- both trade a loud failure for a
silent wrong pull. Left in place, a missing name or tag renders an unparseable reference and the
render fails immediately, which is the behaviour we want.

`default ""` on both is what keeps that failure loud: a nil reaching toString renders the literal
four-character string <nil>, which -- unlike <no value> -- Helm does NOT strip, so it would land
in the manifest as a syntactically valid but nonexistent tag.

Usage: include "tp-infra-mcp-server.image" (dict "ctx" . "name" "<image>" "tag" "<tag>")
*/}}
{{- define "tp-infra-mcp-server.image" -}}
{{- $ctx := .ctx -}}
{{- $reg  := include "tp-infra-mcp-server.image.registry"   $ctx -}}
{{- $repo := include "tp-infra-mcp-server.image.repository" $ctx -}}
{{- $name := .name | default "" | toString -}}
{{- $tag := .tag | default "" | toString -}}
{{- $prefix := compact (list $reg $repo) | join "/" -}}
{{- if $prefix -}}
  {{- printf "%s/%s:%s" $prefix $name $tag -}}
{{- else -}}
  {{- printf "%s:%s" $name $tag -}}
{{- end -}}
{{- end -}}
