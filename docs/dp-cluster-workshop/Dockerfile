#---------------------------------------------------------------------------------------------
# BUILD AWSCLI V2 offical doc:
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-source-install.html#source-getting-started-install-workflows-alpine

FROM python:3.11.6-alpine3.18 as builder-aws
ARG AWS_CLI_VERSION

# Install build dependencies
RUN apk add --no-cache \
    curl \
    make \
    cmake \
    gcc \
    g++ \
    libc-dev \
    libffi-dev \
    openssl-dev \
    && curl https://awscli.amazonaws.com/awscli-${AWS_CLI_VERSION:-2.13.28}.tar.gz | tar -xz \
    && cd awscli-${AWS_CLI_VERSION:-2.13.28} \
    && ./configure --prefix=/opt/aws-cli/ --with-download-deps \
    && make \
    && make install

#---------------------------------------------------------------------------------------------
# install Azure CLI
# https://github.com/Azure/azure-cli/issues/19591

FROM python:3.11.6-alpine3.18 as builder-azure
ARG AZURE_CLI_VERSION
WORKDIR /azure
RUN apk add --no-cache --update python3 py3-pip && \
    apk add --no-cache --update --virtual=build gcc musl-dev python3-dev libffi-dev openssl-dev cargo make && \
    python -m venv .venv && .venv/bin/pip install -U pip && \
    .venv/bin/pip --no-cache-dir install azure-cli==${AZURE_CLI_VERSION:-2.53.1} && \
    find / -name __pycache__ | xargs -r rm -rf

#---------------------------------------------------------------------------------------------
# actual run time docker image
FROM alpine:3.18

ARG KUBECTL_VERSION
ARG HELM_VERSION
ARG YQ_VERSION
ARG EKSCTL_VERSION
ARG ENVSUBST_VERSION
ARG TARGETOS TARGETARCH

# base packages
RUN apk add --no-cache --upgrade coreutils util-linux gettext bash curl wget envsubst jq openssl git python3 && rm -rf /var/cache/apk/*

# COPY AWSCLI V2 to BASE_IMAGE
COPY --from=builder-aws /opt/aws-cli/ /opt/aws-cli/
RUN ln -s /opt/aws-cli/bin/aws /usr/local/bin/aws

# COPY azure cli to BASE_IMAGE
COPY --from=builder-azure /azure /azure
RUN ln -s /usr/bin/python3 /usr/local/bin/python && ln -s /azure/.venv/bin/az /usr/local/bin/az

# install kubectl
RUN { [ -n "${KUBECTL_VERSION}" ] || KUBECTL_VERSION="v1.28.2"; } && \
    echo "KUBECTL_VERSION=${KUBECTL_VERSION}" && \
    curl -sLO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl && \
    chmod +x ./kubectl && mv -f ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client=true

# install helm
RUN { [ -n "${HELM_VERSION}" ] || HELM_VERSION="v3.13.1"; } && \
    echo "HELM_VERSION=${HELM_VERSION}" && \
    curl -sO https://get.helm.sh/helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz && \
    tar xf ./helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz && \
    mv -f ./${TARGETOS}-${TARGETARCH}/helm /usr/local/bin/helm && \
    helm version && \
    rm -rf ./helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz ./${TARGETOS}-${TARGETARCH}

# install yq
RUN { [ -n "${YQ_VERSION}" ] || YQ_VERSION="v4.35.2"; } && \
    echo "YQ_VERSION=${YQ_VERSION}" && \
    curl -sSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${TARGETOS}_${TARGETARCH}" && \
    chmod +x ./usr/local/bin/yq

# eksctl
RUN { [ -n "${EKSCTL_VERSION}" ] || EKSCTL_VERSION="0.162.0"; } && \
    echo "EKSCTL_VERSION=${EKSCTL_VERSION}" && \
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_${TARGETARCH}.tar.gz" | tar xz -C /tmp && \
    chmod +x /tmp/eksctl && mv /tmp/eksctl /usr/local/bin && \
    eksctl version

# copy directories
COPY ["eks", "/home/workshop/eks/"]
COPY ["aks", "/home/workshop/aks/"]

WORKDIR /home/workshop

CMD ["/bin/bash"]