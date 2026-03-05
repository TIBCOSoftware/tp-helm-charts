#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
echo "cmd=$cmd, base=$base"
usage="
$cmd -- Start the tibemsrestd REST ADMIN API server
"
## more portable, but no milliseconds:  
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"
podBase="${HOSTNAME%-*}"
namespace=$MY_NAMESPACE
export MY_POD_DOMAIN="${MY_POD_DOMAIN:-$headlessSvc.$namespace.svc}"
realmPort="${FTL_REALM_PORT-9013}"
emsTcpPort="${EMS_TCP_PORT:-9011}"
emsSslPort="${EMS_SSL_PORT:-9012}"
emsAdminPort="${EMS_ADMIN_PORT:-9014}"
dataplaneID="${DATAPLANE_ID:-$MY_NAMESPACE}"
loggerDir="${EMS_LOGGER_DIR:-/run/logs/emslogger}"
restdDir="${EMS_RESTD_DIR:-/run/logs/restd}"
gatewayDir="${CLOUDSHELL_CTL:-/data/msg/gateway}"

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

function waitForConfig {
  MYCONFIG=${1:?"missing config file arg"}
  log "waitForConfig: waiting for $MYCONFIG"
  while true ; do
    flist=()
    flist+=($MYCONFIG)
    [ -f ${flist[0]} ] && break
    sleep 3
    echo -n "."
  done
  log "waitForConfig: $MYCONFIG found"
}

# OUTLINE
# > for now only BMDP DPs
# Migration strategy:
# .. for each registerd BMDP server
# .. Validate $DP_ADMIN_USER setup
# .. Add logger topic + durable + permissions
# Basic Strategy:
# .. Convert restd server configs to logger configs
# .. Cat all the header + logger configs together
# .. start the logger client

# Wait for a registered EMS server config file
EMSCONFIG=${restdDir}/ems.*.restd.yaml
waitForConfig $EMSCONFIG
serverlist=()
serverlist+=($EMSCONFIG)

# Generate logger config files
# TODO: Uses a changes list ? 
dpLoggerFile="${loggerDir}/dp.$MY_DATAPLANE.logger.yaml"
/app/ems-registration generate-log-header -header ${loggerDir}/logHeader.yaml
# refresh all, since we do not have an add-delete list (yet)
rm -f ${loggerDir}/ems.*.logger.yaml
for server in "${serverlist[@]}"; do
  export groupName="$(echo $(basename $server) | cut -d. -f2 )"
  export capabilityId="$(echo $(basename $server) | cut -d. -f3 )"
  # Migration: 1.13.0:  Upgrade existing registrations for logging
  /app/ems-registration enable-log-monitor -group "$groupName"
  loggerFile="${loggerDir}/ems.$groupName.$capabilityId.logger.yaml"
  /app/ems-registration generate-log-config -restd "$server" -log $loggerFile
done
cat ${loggerDir}/logHeader.yaml ${loggerDir}/ems.*.logger.yaml  > "$dpLoggerFile"

exec emslog -rotate.bytes 10MiB -config $dpLoggerFile
