# Artifact Manager Helm Chart

This repository hosts the official **Artifact Manager Helm Charts** for deploying **Artifact Manager** products to [Kubernetes](https://kubernetes.io/)

## Install Helm (only V3 is supported)

Get the latest [Helm release](https://github.com/helm/helm#install).

## Install Charts

### Add Artifact Manager Helm repository

Before installing Artifact Manager helm charts, you need to add the Artifact Manager helm repository to your helm client.

### Install locally with override values

```bash
helm upgrade --install artifactmanager [--namespace <namespace>] --values <new file name>.yaml
Or
helm upgrade --install artifactmanager [--namespace <namespace>] -f <new file name>.yaml
```

**Note:** For instructions on how to install a chart follow the instructions in _README.md_.

## Contributing to Artifact Manager Charts

Fork the `repo`, make changes and then please run `helm lint` to lint charts locally, and at least install the chart to see if it is working. :)

On success make a [pull request](https://help.github.com/articles/using-pull-requests) (PR) on to the `master` branch.

We will take these PR changes internally, review and test them.

Upon successful review , someone will give the PR an __LGTM__ (_looks good to me_) in the review thread.

We will add PR changes in upcoming releases and credit the contributor with the PR link in the changelog (and also close the PR raised by the contributor).


