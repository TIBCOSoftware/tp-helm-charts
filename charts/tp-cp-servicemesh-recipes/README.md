## Installing the Chart

```console
$ helm install tp-cp-infra-recipes tibco-platform/tp-cp-infra-recipes --version {CHART_VERSION}
```

## Capabilities
If below values are set then it will will override default values for capabilities.

```yaml
capabilities:
  servicemesh:
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Helm chart version for cp proxy, default is latest
    version: ""
    tag: ""
    # Timestamp of capability release
    releaseDate: "2024/02/22"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."
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