#---------------------------------------------------------------------------------------------
# BUILD AWSCLI V2 offical doc:
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-source-install.html#source-getting-started-install-workflows-alpine

FROM python:3.12.9-alpine3.20 AS builder-aws
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
    && curl https://awscli.amazonaws.com/awscli-${AWS_CLI_VERSION:-2.24.21}.tar.gz | tar -xz \
    && cd awscli-${AWS_CLI_VERSION:-2.24.21} \
    && ./configure --prefix=/opt/aws-cli/ --with-download-deps \
    && make \
    && make install

#---------------------------------------------------------------------------------------------
# install Azure CLI
# https://github.com/Azure/azure-cli/issues/19591

FROM python:3.12.9-alpine3.20 AS builder-azure
ARG AZURE_CLI_VERSION
WORKDIR /azure
RUN apk add --no-cache --update python3 py3-pip && \
    apk add --no-cache --update --virtual=build gcc musl-dev python3-dev libffi-dev openssl-dev cargo make && \
    python -m venv .venv && .venv/bin/pip install -U pip && \
    .venv/bin/pip --no-cache-dir install azure-cli==${AZURE_CLI_VERSION:-2.70.0} && \
    find / -name __pycache__ | xargs -r rm -rf

#---------------------------------------------------------------------------------------------
# actual run time docker image
FROM alpine:3.20

ARG EKSCTL_VERSION
ARG KUBECTL_VERSION
ARG TARGETOS TARGETARCH

# base packages
RUN apk add --no-cache --upgrade coreutils util-linux gettext bash gcompat curl wget envsubst jq openssl git python3 yq helm && rm -rf /var/cache/apk/*

# COPY AWSCLI V2 to BASE_IMAGE
COPY --from=builder-aws /opt/aws-cli/ /opt/aws-cli/
RUN ln -s /opt/aws-cli/bin/aws /usr/local/bin/aws

# COPY azure cli to BASE_IMAGE
COPY --from=builder-azure /azure /azure
RUN ln -s /usr/bin/python3 /usr/local/bin/python && ln -s /azure/.venv/bin/az /usr/local/bin/az

RUN { [ -n "${KUBECTL_VERSION}" ] || KUBECTL_VERSION="1.31.5"; } && \
    echo "KUBECTL_VERSION=${KUBECTL_VERSION}" && \
    curl -sLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl && \
    chmod +x ./kubectl && mv -f ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client=true

RUN { [ -n "${EKSCTL_VERSION}" ] || EKSCTL_VERSION="0.201.0"; } && \
    echo "EKSCTL_VERSION=${EKSCTL_VERSION}" && \
    curl --silent --location "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_$(uname -s)_${TARGETARCH}.tar.gz" | tar xz -C /tmp && \
    chmod +x /tmp/eksctl && mv /tmp/eksctl /usr/local/bin/eksctl && \
    eksctl version

# OpenShift CLI
RUN { [ -n "${OC_VERSION}" ] || OC_VERSION="4.18.13"; } && \
    if [ "${TARGETARCH}" == "arm64" ]; then \
        curl --silent --location "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-$(uname -s | awk '{print tolower($0)}')-${TARGETARCH}-${OC_VERSION}.tar.gz" | tar xz -C /tmp; \
    else \
        curl --silent --location "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-$(uname -s | awk '{print tolower($0)}')-${OC_VERSION}.tar.gz" | tar xz -C /tmp; \
    fi && \
    chmod +x /tmp/oc && mv -f /tmp/oc /usr/local/bin/oc && \
    oc version --client=true

# copy directories
COPY ["eks", "/home/workshop/eks/"]
COPY ["aks", "/home/workshop/aks/"]
COPY ["aro (Azure Red Hat OpenShift)", "/home/workshop/aro (Azure Red Hat OpenShift)/"]

WORKDIR /home/workshop

CMD ["/bin/bash"]