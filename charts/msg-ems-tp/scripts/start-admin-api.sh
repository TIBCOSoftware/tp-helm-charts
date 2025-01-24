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
$cmd -- Start the tibemsrestd REST ADMIN API server
"
## more portable, but no milliseconds:  
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"
podBase="${HOSTNAME%-*}"
export STS_NAME="${STS_NAME:-$podBase}"
namespace=$MY_NAMESPACE
headlessSvc="${MY_HEADLESS:-$STS_NAME}"
export MY_POD_DOMAIN="${MY_POD_DOMAIN:-$headlessSvc.$namespace.svc}"
realmPort="${FTL_REALM_PORT-9013}"
emsTcpPort="${EMS_TCP_PORT:-9011}"
emsSslPort="${EMS_SSL_PORT:-9012}"
emsAdminPort="${EMS_ADMIN_PORT:-9014}"
export insideSvcHostPort="${STS_NAME}.${namespace}.svc:${emsTcpPort}"
export insideActiveHostPort="${STS_NAME}active.${namespace}.svc:${emsTcpPort}"

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
# Generate config file
# set LD_LIBRARY_PATH
# start tibemsrestd
# Strategy:
# .. run a tibemsresetd in each pod (to keep it simple)
# .. use same certs as server-group
# .. connect to server TLS listen
# .. open a TLS listen for msg-gems and future apps

cat - <<! > ./emsrest.config.yaml
loglevel: info
proxy:
  name: "$STS_NAME-rest"
  listeners:
    - ":$emsAdminPort"
  session_timeout: 86400
  session_inactivity_timeout: 3600
  page_limit: 0
  disable_tls: true
  certificate: /opt/tibco/ems/current-version/samples/certs/server.cert.pem
  private_key: /opt/tibco/ems/current-version/samples/certs/server.key.p8
  private_key_password: password
  require_client_certificate: false
ems:
  servers:
    - tcp://$insideActiveHostPort,tcp://$insideSvcHostPort
  client_id: "emsrest"
  certificate: /opt/tibco/ems/current-version/samples/certs/server_root.cert.pem
  verify_hostname: false
  client_certificate: /opt/tibco/ems/current-version/samples/certs/client.cert.pem
  client_private_key: /opt/tibco/ems/current-version/samples/certs/client.key.p8
  client_private_key_password: password

!

export LD_LIBRARY_PATH="/opt/tibco/ems/current-version/lib:$LD_LIBRARY_PATH"
tibemsrestd --config ./emsrest.config.yaml
