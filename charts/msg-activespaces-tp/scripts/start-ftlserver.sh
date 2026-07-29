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
exec tibftlserver \
    -c /data/boot/ftl.yaml \
    -n ${POD_NAME} \
    --license ${TIBFTL_LICENSE} \

# wait-for-shutdown.sh

        #       /opt/tibco/as/current-version/bin/tibftlserver \
        #       -c /config/ftl.yaml \
        #       -n '$(POD_NAME)' \
        #       --license '{{ $.Values.ftlserver.license }}' \
