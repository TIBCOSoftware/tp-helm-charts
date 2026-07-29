#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"

export POD_NAME="${POD_NAME:-$(hostname)}"
export TIBFTL_LICENSE="${TIBFTL_LICENSE:-"file:///boot-activation/license-file.bin"}"
export LD_LIBRARY_PATH="/opt/tibco/as/current-version/lib:/opt/tibco/ftl/current-version/lib:${LD_LIBRARY_PATH}"

replicaID="${POD_NAME##*-}"
mapfile -t connectArgs  < /conf/as.*.args
if [ $AS_USE_COMPACT = "true" ] ; then
    if [ "$replicaID" != 0 ]; then
        proxyID=$((replicaID-1))
        exec tibdgproxy "${connectArgs[@]}" -n "proxy-${proxyID}"
    else
        echo "No Pod=0 proxy in compact mode, skipping proxy startup"
        exec wait-for-shutdown.sh
    fi
else
    exec tibdgproxy "${connectArgs[@]}" --health-server ":9191" -n "proxy-${replicaID}"
fi
