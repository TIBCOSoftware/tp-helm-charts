#!/bin/bash

#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-ftlserver.yml}
#use:  MY_STSNAME, MY_HEADLESS, MY_POD_DOMAIN 
podData="/data"
podBase="${HOSTNAME##-}"
srvBase="${EMS_SERVICE:-$podBase}"
svcname="${MY_HEADLESS:-$srvBase}"
namespace=$MY_NAMESPACE
ftlport="${FTL_REALM_PORT:-9013}"
EMS_TCP_PORT="${EMS_TCP_PORT-9011}"
EMS_HTTP_PORT="${EMS_HTTP_PORT-9010}"
# EMS_LISTEN_URLS="tcp://0.0.0.0:${EMS_TCP_PORT}"
EMS_LISTEN_URLS="${EMS_LISTEN_URLS:-tcp://0.0.0.0:${EMS_TCP_PORT}}"
# loglevel=${FTL_LOGLEVEL:-"info;quorum:debug"}
loglevel=${FTL_LOGLEVEL:-"info"}
cat - <<EOF > $outfile
globals:
  loglevel: "$loglevel"
  core.servers:
    ${srvBase}-0: "${srvBase}-0.${svcname}.${namespace}.svc:${ftlport}"
    ${srvBase}-1: "${srvBase}-1.${svcname}.${namespace}.svc:${ftlport}"
    ${srvBase}-2: "${srvBase}-2.${svcname}.${namespace}.svc:${ftlport}"
servers:
  ${srvBase}-0:
    - tibemsd:
        exepath: /opt/tibco/ems/current-version/bin/tibemsd
        -listens: ${EMS_LISTEN_URLS}
        -health_check_listen: http://0.0.0.0:${EMS_HTTP_PORT}
        -store: "$podData/emsdata"
        -config_wait:
    - realm:
        data: "$podData/realm"
    - persistence:
        name: default_${srvBase}-0
        data: "$podData/ftldata"
  ${srvBase}-1:
    - tibemsd:
        exepath: /opt/tibco/ems/current-version/bin/tibemsd
        -listens: ${EMS_LISTEN_URLS}
        -health_check_listen: http://0.0.0.0:${EMS_HTTP_PORT}
        -store: "$podData/emsdata"
        -config_wait:
    - realm:
        data: "$podData/realm"
    - persistence:
        name: default_${srvBase}-1
        data: "$podData/ftldata"
  ${srvBase}-2:
    - tibemsd:
        exepath: /opt/tibco/ems/current-version/bin/tibemsd
        -listens: ${EMS_LISTEN_URLS}
        -health_check_listen: http://0.0.0.0:${EMS_HTTP_PORT}
        -store: "$podData/emsdata"
        -standby_only:
        -config_wait:
    - realm:
        data: "$podData/realm"
    - persistence:
        name: default_${srvBase}-2
        data: "$podData/ftldata"
EOF
