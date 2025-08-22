## Installing the Chart

```console
$ helm install dp-oauth2proxy-recipes tibco-platform/dp-oauth2proxy-recipes --version {CHART_VERSION}
```

## Capabilities
If below values are set then it will override default values for capabilities.

```yaml
capabilities:
  oauth2proxy:
    # if set to true then existing recipe will be overwritten by latest recipe.
    overwriteRecipe: "false"
    # set to true for latest version of recipe
    isLatest: "true"
    # Helm chart version for oauth2proxy, default is latest
    version: ""
    tag: "107"
    # Timestamp of capability release
    releaseDate: "2025/08/13"
    # Either a link to document or the document itself specifying _what was fixed in this release.
    releaseNotes: "Enhancements, Bug fixes, etc."
```

## Image

```yaml
image:
  name: distroless-base-debian-debug
  registry: ""
  repo: ""
  tag: 12.11
  pullPolicy: IfNotPresent
```