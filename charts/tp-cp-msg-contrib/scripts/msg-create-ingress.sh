#!/bin/bash

#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

usage() {
    echo "Usage: msg-create-ingress.sh create <dpName> [<svcNS> [<cpNS> [cpDNS]]]"
    echo "Usage: msg-create-ingress.sh delete <dpName> "
    echo "Commands:"
    echo "  create - Create TibcoRoute"
    echo "      Note: cpDNS is only needed for create. If not given, \$MSGDP_DNS_DOMAIN will be used."
    echo "  delete - Delete TibcoRoute"
    echo ""
}

export command=$1
export dpName=${2:?"$(usage), DP required"}
export svcName="dp-$dpName"
export svcNS=${3:-""}
export cpNS=${4:-$MY_NAMESPACE}
export cpDNS=${5:-$MSGDP_DNS_DOMAIN}
if [ -z "$svcNS" ]; then
    svcNS=$cpNS
fi

create_tibcoroute() {

    kubectl apply -f - <<EOF
apiVersion: cloud.tibco.com/v1
kind: TibcoRoute
metadata:
  name: tp-cp-msg-webserver-ops-${svcName}
  namespace: $cpNS
  labels:
    tib-cp-dataplane-id: $dpName
    tib-cp-servicename: $svcName
    tib-cp-servicenamespace: $svcNS
spec:
  endpoints:
  - internalPath: /tibco/agent/msg/ops/shell
    path: /tibco/agent/msg/$dpName/ops/shell
    port: 80
    protocol: http
    proxies:
    - allowClientCache: true
      allowXFrameOptions: true
      config: secure
      configVariables:
        SECURE_REDIRECT_SKIP_ACCTS_CHECK: "true"
        SECURE_REDIRECT_SKIP_EULA_CHECK: "true"
        SECURE_REDIRECT_SKIP_ORG_CHECK: "true"
      enableRedirects: true
      fqdn: "$cpDNS"
      listener: virtual
  serviceName: $svcName
  serviceNamespace: $svcNS
EOF
}

delete_tibcoroute() {
    kubectl delete tibcoroute tp-cp-msg-webserver-"${svcName}" -n "$cpNS"
}

case "$command" in
    create)
        if [ $# -lt 1 ]; then
            usage
            exit 1
        fi
        create_tibcoroute 
        ;;
    delete)
        if [ $# -lt 1 ]; then
            usage
            exit 1
        fi
        delete_tibcoroute
        ;;
    h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac
