## Installing the Chart

```console
$ helm install tp-cp-infra-recipes tibco-platform/tp-cp-infra-recipes --version {CHART_VERSION}
```

## Capabilities
If below values are set then it will will override default values for capabilities.

```yaml
capabilities:
  cpproxy:
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Helm chart version for cp proxy, default is latest
    version: ""
    tag: "107"
    # Timestamp of capability release
    releaseDate: "2024/02/22"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."

  integrationcore:
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Timestamp of capability release
    releaseDate: "2024/02/22"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."
    # helm chart and image version for artifact manager, default helm chart version is latest
    artifactmanager:
      version: ""
      tag: "46"
    # helm chart and image version for distributed lock operator, default helm chart version is latest
    distributedLockOperator:
      version: ""
      tag: "72"

  secretcontroller:
    # Timestamp of capability release
    releaseDate: "2024/02/22"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Helm chart version for secret controller, default is latest
    version: ""
    tag: "40"

  o11y:
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Timestamp of capability release
    releaseDate: "2024/02/22"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."
    # helm chart and image version for o11y service, default helm chart version is latest
    o11yservice:
      version: ""
    # helm chart and image version for opentelemetry collector, default helm chart version is latest
    opentelemetryCollector:
      version: ""
    # helm chart and image version for jaeger, default helm chart version is latest
    jaeger:
      version: ""

  o11yExporter:
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Timestamp of capability release
    releaseDate: "2024/02/22"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."
    # helm chart and image version for o11y service, default helm chart version is latest
    o11yservice:
      version: ""
    # helm chart and image version for opentelemetry collector, default helm chart version is latest
    opentelemetryCollector:
      version: ""
    # helm chart and image version for jaeger, default helm chart version is latest
    jaeger:
      version: ""
```

## Image

```yaml
image:
  name: distroless-base-debian-debug
  registry: ""
  repo: ""
  tag: 12
  pullPolicy: IfNotPresent
```