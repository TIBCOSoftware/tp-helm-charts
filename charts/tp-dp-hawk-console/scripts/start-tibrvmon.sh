#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
echo "cmd=$cmd, base=$base"
usage="
$cmd -- Start the tibrvmon gateway server
"
## more portable, but no milliseconds:  
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"

podBase="${HOSTNAME%-*}"
namespace=$MY_NAMESPACE
dataplaneID="${DATAPLANE_ID:-$MY_NAMESPACE}"
RVMON=${RVMON:-"/opt/tibco/tibrv/current-version/bin/tibrvmon"}
RVCONFIG=${RVCONFIG:-"running.rvmon.json"}

# Set signal traps
function log
{ echo "$(date "$fmtTime"): $*" ; }
function do_shutdown
{ log "-- Shutdown received (SIGTERM): host=$HOSTNAME" && exit 0 ; }
function do_sighup
{ log "-- Got SIGHUP: host=$HOSTNAME" ; }
trap do_shutdown SIGINT
trap do_shutdown SIGTERM
trap do_sighup SIGHUP

# OUTLINE
# Wait for config-file
function waitForConfig {
  log "waitForConfig: waiting for $RVCONFIG"
  while [ ! -f $RVCONFIG ]; do
    sleep 3
    echo -n "."
  done
  log "waitForConfig: RVCONFIG found"
}

log "waitForConfig: host=$HOSTNAME, namespace=$namespace, dataplaneID=$dataplaneID, cwd=$(pwd)"
waitForConfig
$RVMON --config $RVCONFIG
