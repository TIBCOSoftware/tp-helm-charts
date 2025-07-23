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
namespace=$MY_NAMESPACE
export MY_POD_DOMAIN="${MY_POD_DOMAIN:-$headlessSvc.$namespace.svc}"
realmPort="${FTL_REALM_PORT-9013}"
emsTcpPort="${EMS_TCP_PORT:-9011}"
emsSslPort="${EMS_SSL_PORT:-9012}"
emsAdminPort="${EMS_ADMIN_PORT:-9014}"
dataplaneID="${DATAPLANE_ID:-$MY_NAMESPACE}"

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
# .. run a tibemsresetd in a BMDP Toolset pod
# .. Allow K8s /boot-certs import
# .. use same /data/certs mount as Hawk does
# .. connect to server TLS listen
# .. open a TLS listen for msg-gems and future apps

cat - <<! > ./multi.restd.yaml
# UPDATE 1.4.0 Proxy (10.4 pre-release hotfix version)
loglevel: info
proxy:
  name: "$MY_RELEASE-toolset"
  listeners:
    - ":$emsAdminPort"
  session_timeout: 86400
  session_inactivity_timeout: 3600
  page_limit: 0
  disable_tls: true
  require_client_certificate: false
  certificate: /data/certs/samples/server.cert.pem
  private_key: /data/certs/samples/server.key.p8
  private_key_password: password
  default_cache_timeout: 5
  minimum_cache_timeout: 0
  server_check_interval: 5
!
cat - <<! > ./ems.default.restd.yaml
    - name: "default"
      # Alternate \$ENV: EMSRESTD_EMS_SERVER_GROUPS_{GROUP NAME}_TAGS='red,blue'
      tags:
        - $dataplaneID
      servers:
        - role: "primary"
          tags:
          # Optionally: Use *-emsactive URL ? 
          url: tcp://localhost:9011
          monitor_url: http://localhost:9010
          client_id: "$POD_NAME"
          # tls:
          #   verify_hostname: false
          #   verify_certificate: false
          #   expected_hostnames: server
          #   trusted_certificates:
          #     - /data/certs/samples/server_root.cert.pem
          #   client_certificate: /data/certs/samples/client.cert.pem
          #   client_private_key: /data/certs/samples/client.key.p8
          #   client_private_key_password: password
          #   certificate_authority:
          #     certificate: /data/certs/samples/server_root.cert.pem
          #     private_key: /data/certs/samples/server_root.cert.pem
          #     private_key_password: password
!
cat - <<! > ./server-list.restd.yaml
ems:
  default_server_group: "default"
  server_groups:
!
cat ems.*.restd.yaml >> server-list.restd.yaml

export LD_LIBRARY_PATH="/opt/tibco/ems/current-version/lib:$LD_LIBRARY_PATH"
tibemsrestd --config ./multi.restd.yaml,server-list.restd.yaml --loglevel debug
