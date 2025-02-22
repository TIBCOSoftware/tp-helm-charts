#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="$cmd <function> [args] -- Run a CT EMS utility function
.. required arguments vary by function , but generally a registration json is required
.. NOTE: this is a work in progress, TLS and FTL options are not supported yet
    -r=reg-spec:  registration json blob for an EMS group
=== Functions
  mainLauncher:  Generate a groupName directory with files required to remotely start EMS group
  mainEmsdInit:  Generate an emsd.init.json file for a given EMS registration spec
  mainRestdEmsConfig: Generate tibemsrestd server group config yaml
=== Example -- starting EMS FT-pair group named ems-ft
  ./$cmd mainLauncher -r=ems-ft.registration.json
  ./ems-ft/ssh-start.sh
"
# export NFS_TOP="${NFS_TOP:-/rv/msg_share0/msgdp-1.4.0}"
export EMS_HOME="${EMS_HOME:-/opt/tibco/ems/current-version}"
export EMSD=${EMSD:-$EMS_HOME/bin/tibemsd}
export tmpId="tmp.$RANDOM"
export TIBEMSADMIN=${TIBEMSADMIN:-$EMS_HOME/bin/tibemsadmin}
export EMS_RESTD_DIR=${EMS_RESTD_DIR:-/logs/restd-api}
export restartRequest="${EMS_RESTD_DIR}/restart-request"
export namespace=${MY_NAMESPACE:-NS-$RANDOM}
# set EMS_REG_DEBUG=y  For additional debug output
# export EMS_REG_DEBUG=y
export checkingErrors=()

function parseCmdOptions {
  while [ $# -gt 0 ] ; do arg="$1"
    skipShift= val="${2}"
    [[ "$arg" =~ [=] ]] && skipShift=1 && val="${arg#*=}" && arg="${arg%%=*}"
    # echo 2>&1 "val=$val, arg=$arg, skipShift=$skipShift, args: $*"
    case "$arg" in
      -r) export regSpec="${val}" ; [ -n "$skipShift" ] || shift ;;
      -id) export resourceInstanceId="${val}" ; [ -n "$skipShift" ] || shift ;;
      -g) export groupName="${val}" ; [ -n "$skipShift" ] || shift ;;
      -hawk) export hawkToken="${val}" ; [ -n "$skipShift" ] || shift ;;
      -i) export initJson="${val}" ; [ -n "$skipShift" ] || shift ;;
      -debug|--debug)  export EMS_REG_DEBUG=y ; set -x ;;
      -help) echo "$usage" ; exit 1 ;;
      * ) break ;;
    esac ; shift
  done
  if [ -z "$regSpec" ] ; then
     waitingOnSpec=y
  elif [ -n "$EMS_REG_DEBUG" ] ; then
    cp "$regSpec" "$tmpId.reg.json"
    export regSpec="$tmpId.reg.json"
  else
    mv "$regSpec" "$tmpId.reg.json"
    export regSpec="$tmpId.reg.json"
  fi
}

function parseServerSpec {
  #caller:  parseCmdOptions "$@"
  echo >&2 "#+: parseServerSpec: regSpec=$regSpec"
  [ ! -f "$regSpec" ] && echo >&2 "ERROR:  Missing registry spec: $regSpec" && exit 1
  export groupName=$(yq '.groupName' < $regSpec)
  export clientUrl=$(yq '.clientUrl' < $regSpec)
  export monitorUrl=$(yq '.monitorUrl' < $regSpec)
  export dataplaneId=$(yq '.dataplaneId' < $regSpec)
  if [ -z "$hawkToken" ] ; then
    export hawkToken=$(yq '.hawkToken' < $regSpec)
    [ "$hawkToken" == "null" ] && hawkToken=""
  fi
  export regUser=$(yq '.registrationUser' < $regSpec)
  export regPass=$(yq '.registrationPass' < $regSpec)
  export clientMtls="" monitorMtls=""
  export clientCert=$(yq '.clientMtls.certificate' < $regSpec)
  [ -z "$resourceInstanceId" ] && export resourceInstanceId=$(yq '.resourceInstanceId' < $regSpec)
  [ "$resourceInstanceId" == "null" ] && export resourceInstanceId="riid-$RANDOM"
  [ "$dataplaneId" == "null" ] && export dataplaneId="${MY_DATAPLANE:-"dp-$RANDOM"}"
  log "    groupName: $groupName, $resourceInstanceId"
  log "    dataplaneId: $dataplaneId"
  # log "    hawkToken: $hawkToken"
  if [ "$clientCert" != "null" ] ; then
    clientMtls=yes
    export clientKey=$(yq '.clientMtls.privateKey' < $regSpec)
    [ "$clientKey" == "null" ] && export clientKey=""
    export clientPass=$(yq '.clientMtls.pkPassword' < $regSpec)
    [ "$clientPass" == "null" ] && export clientPass=""
    export clientTrusted=$(yq '.clientMtls.trusted' < $regSpec)
    [ "$clientTrusted" == "null" ] && export clientTrusted=""
  else
    export clientCert="" clientKey="" clientPass="" clientTrusted=""
  fi
  export monitorCert=$(yq '.monitorMtls.certificate' < $regSpec)
  if [ "$monitorCert" != "null" ] ; then
    monitorMtls=yes
    export monitorKey=$(yq '.monitorMtls.privateKey' < $regSpec)
    [ "$monitorKey" == "null" ] && export monitorKey=""
    export monitorPass=$(yq '.monitorMtls.pkPassword' < $regSpec)
    [ "$monitorPass" == "null" ] && export monitorPass=""
    export monitorTrusted=$(yq '.monitorMtls.trusted' < $regSpec)
    [ "$monitorTrusted" == "null" ] && export monitorTrusted=""
  else
    export monitorCert="" monitorKey="" monitorPass="" monitorTrusted=""
  fi
  echo >&2 "#+: parseServerSpec: group=$groupName"
  echo >&2 "#+: parseServerSpec: clientUrl=$clientUrl"
  echo >&2 "#+: parseServerSpec: monitorUrl=$monitorUrl"
  echo >&2 "#+: parseServerSpec: clientTLS:$clientMtls,  monitorTLS:$monitorMtls"

}

function parseServerUrls {
  # Uses clientUrl and monitorUrl
  # Sets Primary{Url,Listen,Mon}, Secondary{Url,Listen,Mon}, and StandbyOnly{Url,Listen,Mon}
  # Process clientUrl list
  export PrimaryUrl="$(echo $clientUrl | cut -s -d, -f1)"
  [ -z "$PrimaryUrl" ] && PrimaryUrl="$clientUrl"
  export SecondaryUrl="$(echo $clientUrl | cut -s -d, -f2)"
  export StandbyOnlyUrl="$(echo $clientUrl | cut -s -d, -f3)"
  # NOTE: Max of 2 commas
  scheme="$(echo "$PrimaryUrl" | cut -d: -f1)"
  port="$(echo "$PrimaryUrl" | cut -d: -f3)"
  export PrimaryHost="$(echo "$PrimaryUrl" | cut -d: -f2 | cut -c3- )"
  export PrimaryListen="${scheme}://0.0.0.0:${port}"
  scheme="$(echo "$SecondaryUrl" | cut -d: -f1)"
  port="$(echo "$SecondaryUrl" | cut -d: -f3)"
  export SecondaryHost="$(echo "$SecondaryUrl" | cut -d: -f2 | cut -c3- )"
  export SecondaryListen="${scheme}://0.0.0.0:${port}"
  scheme="$(echo "$StandbyOnlyUrl" | cut -d: -f1)"
  port="$(echo "$StandbyOnlyUrl" | cut -d: -f3)"
  export StandbyOnlyListen="${scheme}://0.0.0.0:${port}"
  export StandbyOnlyHost="$(echo "$StandbyOnlyUrl" | cut -d: -f2 | cut -c3- )"

  # Process monitorUrl list
  export firstMon="$(echo "$monitorUrl" | cut -s -d, -f1)"
  [ -z "$firstMon" ] && firstMon="$monitorUrl"
  export secondMon="$(echo "$monitorUrl" | cut -s -d, -f2)"
  export thirdMon="$(echo "$monitorUrl" | cut -s -d, -f3)"

  scheme="$(echo "$firstMon" | cut -d: -f1)"
  port="$(echo "$firstMon" | cut -d: -f3)"
  export PrimaryMon="${scheme}://0.0.0.0:${port}"
  scheme="$(echo "$secondMon" | cut -d: -f1)"
  port="$(echo "$secondMon" | cut -d: -f3)"
  export SecondaryMon="${scheme}://0.0.0.0:${port}"
  scheme="$(echo "$thirdMon" | cut -d: -f1)"
  port="$(echo "$thirdMon" | cut -d: -f3)"
  export StandbyOnlyMon="${scheme}://0.0.0.0:${port}"

  if [ -z "$SecondaryUrl" ] ; then
    export emsStyle="single"
  elif [ -z "$StandbyOnlyUrl" ] ; then
    export emsStyle="FT"
  else
    export emsStyle="FTL"
  fi
  echo >&2 " NOTE: $emsStyle, $PrimaryUrl, $SecondaryUrl, $StandbyOnlyUrl"
  echo >&2 " Primary: $PrimaryHost, $PrimaryListen, $PrimaryMon"
}

function mtlsConfig {
  export certDir="/data/hawk/emscerts"
  # # FIXME: if TLS and not MTLS ...
  #         tls:
  #           verify_hostname: false
  #           verify_certificate: false
  #         monitor_tls:
  #           verify_hostname: false
  #           verify_certificate: false
  if [[ "$clientUrl" =~ ^ssl:// ]] ; then
    echo >&2 "#+: clientUrl is TLS ($clientUrl)"
    if [ -z "$clientMtls" ] ; then
      # TLS, not mTLS
      echo "
          tls:
            verify_hostname: false
            verify_certificate: false
"
    else
      echo >&2 "#+: clientUrl is mTLS"
      echo "
          tls:
            verify_hostname: false
            verify_certificate: false
            # expected_hostnames: server
            client_certificate: $certDir/$clientCert
            client_private_key: $certDir/$clientKey
"
      echo "            client_private_key_password: $clientPass"
      if [ -n "$clientTrusted" ] ; then
        echo "            trusted_certificates:"
        for cert in $(echo "$clientTrusted" | tr ',' ' ' ) ; do
          echo "              - $certDir/$cert"
        done
      fi
    fi
  fi
  if [[ "$monitorUrl" =~ ^https:// ]] ; then
    echo >&2 "#+: monitorUrl is TLS ($monitorUrl)"
    if [ -z "$monitorMtls" ] ; then
      # TLS, not mTLS
      echo "
          monitor_tls:
            verify_hostname: false
            verify_certificate: false
"
    else
      echo >&2 "#+: monitorUrl is mTLS"
      echo "
          monitor_tls:
            verify_hostname: false
            verify_certificate: false
            # expected_hostnames: server
            client_certificate: $certDir/$monitorCert
            client_private_key: $certDir/$monitorKey
"
      echo "            client_private_key_password: $monitorPass"
      if [ -n "$monitorTrusted" ] ; then
        echo "            trusted_certificates:"
        for cert in $(echo "$monitorTrusted" | tr ',' ' ' ) ; do
          echo "              - $certDir/$cert"
        done
      fi
    fi
  fi
}

function primaryConfig {
  echo "
        - role: "primary"
          tags:
            - $groupName
          url: $PrimaryUrl
          monitor_url: $firstMon
          client_id: "$groupName-primary"
"
  mtlsConfig
}

function secondaryConfig {
  [ -z "$SecondaryUrl" ] && return
  echo "
        - role: "secondary"
          tags:
            - $groupName
          url: $SecondaryUrl
          monitor_url: $secondMon
          client_id: "$groupName-secondary"
"
  mtlsConfig
}

function standbyConfig {
  [ -z "$StandbyOnlyUrl" ] && return
  echo "
        - role: "standby"
          tags:
            - $groupName
          url: $StandbyOnlyUrl
          monitor_url: $thirdMon
          client_id: "$groupName-standby"
"
  mtlsConfig
}

function genRestdServerConfig {
  tmpYaml="$tmpId.$groupName.restd.yaml"
  cat - <<EOF > $tmpYaml
    - name: $groupName
      tags:
        - $dataplaneId
        - $resourceInstanceId
        - $groupName
        - $namespace
      servers:
          $(primaryConfig)
          $(secondaryConfig)
          $(standbyConfig)
EOF
# Use atomic updates
mv $tmpYaml "${EMS_RESTD_DIR}/ems.$groupName.$resourceInstanceId.restd.yaml"

}

function checkConnect {
  url=${1:?"checkConnect requires a URL"}
  scheme="$(echo "$url" | cut -d: -f1)"
  port="$(echo "$url" | cut -d: -f3)"
  host="$(echo "$url" | cut -d: -f2 | cut -c3- )"
  res="$(nc -z -v $host $port 2>&1 )"
  rtc=$?
  [ $rtc -ne 0 ] && checkingErrors+=("Error: $host:$port - ($rtc) $res")
  echo >&2 "#+: Check $host:$port -- ($rtc) $res"
}
function checkIsLive {
  url=${1:?"checkConnect requires a URL"}
  curlOpts="-k -s -o /dev/null"
  curlTimeout="--max-time 5 --connect-timeout 3"
  liveCode=$( curl $curlOpts $curlTimeout -w '%{http_code}' "$url/isLive" )
  liveCode=${liveCode:-405}
  [ $liveCode -eq 000 ] && liveCode=406
  [ "$liveCode" -ne 200 ] && checkingErrors+=("($liveCode) $url/isLive")
  echo >&2 "($liveCode) $url/isLive"
}
function checkHasDPAdmin {
  myJWT=${MSG_ADMIN_BEARER:?"No JWT token found.  Use MSG_ADMIN_BEARER=token"}
  rtc=0
  echo >&2 "#+: Checking Dataplane admin permissions"
  cpHostname="cp-proxy:80"
  curlOpts=()
  curlOpts+=(-i)
  curlOpts+=(-Ss)
  curlOpts+=(--max-time)
  curlOpts+=(45)
  curlOpts+=(--connect-timeout)
  curlOpts+=(3)
  curlOpts+=(-H)
  curlOpts+=("Content-Type: application/json")
  curlOpts+=(-H)
  curlOpts+=("X-User-Token: $myJWT")
  api="pengine/v2/enforce-permissions"
  payload=$(printf '{"contributingResource":"CP","resources":{"%s":["*"]},"action":[{"object":"dataplanes","httpMethod":"POST"}]}' $MY_DATAPLANE)

  resp=$( curl "${curlOpts[@]}" "$cpHostname/$api" -d "$payload" )
  # echo >&2 "#+: Auth=$resp"
  jqexp=$(printf '.allowed[] | select(has("action")) | .resources.%s' $MY_DATAPLANE)
  check=$(echo "$resp" | tail -1 | jq "$jqexp" )
  [ "$check" == "null" ] && check=""
  if [ -z "$check" ] ; then
    echo "Missing DP admin permission for $MY_DATAPLANE" 
    rtc=1
  else
    echo "Authorized"
  fi
  return $rtc
}

function checkShowState {
  url=${1:?"checkShowState requires a URL"}
  export certDir="/data/hawk/emscerts"
  scheme="$(echo "$url" | cut -d: -f1)"
  port="$(echo "$url" | cut -d: -f3)"
  host="$(echo "$url" | cut -d: -f2 | cut -c3- )"
  echo "show state" > $tmpId.show-state.cmd
  adminOpts=()
  adminOpts+=(-server)
  adminOpts+=("$url")
  adminOpts+=(-user)
  adminOpts+=("$regUser")
  adminOpts+=(-password)
  adminOpts+=("$regPass")
  adminOpts+=(-script)
  adminOpts+=("$tmpId.show-state.cmd")
  # if scheme=ssl , Add TLS options
  if [ "$scheme" == "ssl" ] ; then
    adminOpts+=(-ssl_noverifyhost)
    adminOpts+=(-ssl_noverifyhostname)
    adminOpts+=(-ssl_trace)
    adminOpts+=(-ssl_debug_trace)
    # if scheme=mtls , Add TLS certs
    if [ -n "$clientMtls" ] ; then 
      # adminOpts+=(-ssl_trusted)
      # adminOpts+=("$certDir/$clientTrusted")
      adminOpts+=(-ssl_identity)
      adminOpts+=("$certDir/$clientCert")
      adminOpts+=(-ssl_key)
      adminOpts+=("$certDir/$clientKey")
      adminOpts+=(-ssl_password)
      adminOpts+=("$clientPass")
    fi
  fi
  res="$($TIBEMSADMIN "${adminOpts[@]}" 2>&1 )"
  rtc=$?
  [ $rtc -ne 0 ] && checkingErrors+=("tibemsadmin show state failed. ($rtc) $res")
  serverState="$(echo "$res" | grep -i " State:" | cut -d: -f2 | tr -d ' ' )"
  echo >&2 "#+: ShowState $url -- ($rtc) $serverState"
  echo "$serverState"
}

function setupTibemsAdmin {
  usage="setupTibemsAdmin <riid|name> -- Set params for tibemsadmin"
  groupId=${1:?"$usage"}
  export EMS_RESTD_DIR=${EMS_RESTD_DIR:-/logs/restd-api}
  restdYaml=$(ls "${EMS_RESTD_DIR}/ems."*"${groupId}"*.restd.yaml)
  export certDir="/data/hawk/emscerts"
  export EMS_HOME="${EMS_HOME:-/opt/tibco/ems/current-version}"
  export TIBEMSADMIN=${TIBEMSADMIN:-$EMS_HOME/bin/tibemsadmin}
  urlList="$(cat $restdYaml | grep ' url: ' | cut -d: -f2-)"
  export clientMtls="$(cat $restdYaml | grep client_certificate: | head -1 | cut -d: -f2 | tr -d ' ')"
  export clientCert="$clientMtls"
  [ -n "$clientCert" ] && clientCert=$(basename $clientCert)
  export clientKey="$(cat $restdYaml | grep client_private_key: | head -1 | cut -d: -f2 | tr -d ' ')"
  [ -n "$clientKey" ] && clientKey=$(basename $clientKey)
  export clientPass="$(cat $restdYaml | grep client_private_key_password: | head -1 | cut -d: -f2 | tr -d ' ')"
  export activeUrl=
  for url in $urlList ; do
    emsState="$(runTibemsAdmin "$url" "show state" 2>/dev/null | grep -i " State:" | cut -d: -f2 | tr -d ' ' )"
    [ "$emsState" == "active" ] && activeUrl="$url"
    # runTibemsAdmin "$url" "show state"
  done
  echo >&2 "activeUrl=$activeUrl"
}

function runTibemsAdmin {
  usage="runTibemsAdmin <url> [cmdline] -- Run a tibemsadmin command"
  url=${1:?"runTibemsAdmin requires a URL"}
  shift
  tibcmd="$*"
  export certDir="/data/hawk/emscerts"
  export EMS_HOME="${EMS_HOME:-/opt/tibco/ems/current-version}"
  export TIBEMSADMIN=${TIBEMSADMIN:-$EMS_HOME/bin/tibemsadmin}
  export cliDir="${cliDir:-.}"
  regUser=${regUser:-$EMS_ADMIN_USER}
  regPass=${regPass:-$EMS_ADMIN_PASSWORD}
  scheme="$(echo "$url" | cut -d: -f1)"
  port="$(echo "$url" | cut -d: -f3)"
  host="$(echo "$url" | cut -d: -f2 | cut -c3- )"
  adminOpts=()
  adminOpts+=(-server)
  adminOpts+=("$url")
  adminOpts+=(-user)
  adminOpts+=("$regUser")
  adminOpts+=(-password)
  adminOpts+=("$regPass")
  # if scheme=ssl , Add TLS options
  if [ "$scheme" == "ssl" ] ; then
    adminOpts+=(-ssl_noverifyhost)
    adminOpts+=(-ssl_noverifyhostname)
    adminOpts+=(-ssl_trace)
    adminOpts+=(-ssl_debug_trace)
    # if scheme=mtls , Add TLS certs
    if [ -n "$clientMtls" ] ; then 
      # adminOpts+=(-ssl_trusted)
      # adminOpts+=("$certDir/$clientTrusted")
      adminOpts+=(-ssl_identity)
      adminOpts+=("$certDir/$clientCert")
      adminOpts+=(-ssl_key)
      adminOpts+=("$certDir/$clientKey")
      adminOpts+=(-ssl_password)
      adminOpts+=("$clientPass")
    fi
  fi
  if [ -n "$tibcmd" ] ; then
    echo "$tibcmd" > $cliDir/cmd
    adminOpts+=(-script)
    adminOpts+=("$cliDir/cmd")
  fi
  $TIBEMSADMIN "${adminOpts[@]}"
}

function mainCliEmsAdmin {
  usage="mainCliEmsAdmin <riid|name> -- Open a tibemsadmin terminal"
  groupId=${1:-"$MSG_CLI_RIID"}
  setupTibemsAdmin "$groupId"
  runTibemsAdmin "$activeUrl"
}

function checkCertFiles {
  # Check that cert files exist
  export certDir="/data/hawk/emscerts"
  echo >&2 "clientMtls: $clientMtls, monitorMtls: $monitorMtls"
  [ -z "$clientCert" ] && [ -z "$monitorCert" ] && return
  echo >&2 "#+: Check that any TLS files exist: $clientCert, $clientKey, $monitorCert, $monitorKey"
  [ -n "$clientCert" ] && [ ! -f "$certDir/$clientCert" ] && checkingErrors+=("Missing client certificate: $clientCert")
  [ -n "$clientKey" ] && [ ! -f "$certDir/$clientKey" ] && checkingErrors+=("Missing client private key: $clientKey")
  [ -n "$monitorCert" ] && [ ! -f "$certDir/$monitorCert" ] && checkingErrors+=("Missing monitor certificate: $monitorCert")
  [ -n "$monitorKey" ] && [ ! -f "$certDir/$monitorKey" ] && checkingErrors+=("Missing monitor private key: $monitorKey")
  if [[ "$clientTrusted" =~ "," ]] ; then
    for cert in $(echo "$clientTrusted" | tr ',' ' ' ) ; do
      [ ! -f "$certDir/$cert" ] && checkingErrors+=("Missing client trusted certificate: $cert")
    done
  elif [ -n "$clientTrusted" ] ; then
    [ ! -f "$certDir/$clientTrusted" ] && checkingErrors+=("Missing client trusted certificate: $clientTrusted")
  fi
}

function checkRestdJson {
  # Check data supplied in JSON input for validity
  echo >&2 "#+: Check client ports"
  clientCount=0
  for url in $(echo "$clientUrl" | tr ',' ' ' ) ; do
    clientCount=$((clientCount+1))
    checkConnect "$url"
  done
  echo >&2 "#+:DEBUG: checkingErr=${#checkingErrors[@]} "
  echo >&2 "#+: Check monitor ports"
  monCount=0
  for url in $(echo "$monitorUrl" | tr ',' ' ' ) ; do
    monCount=$((monCount+1))
    checkConnect "$url"
  done
  echo >&2 "#+:DEBUG: checkingErr=${#checkingErrors[@]} "
  echo >&2 "#+: "Check /isLive endpoints
  for url in $(echo "$monitorUrl" | tr ',' ' ' ) ; do
    checkIsLive "$url"
  done
  echo >&2 "#+:DEBUG: checkingErr=${#checkingErrors[@]} "
  echo >&2 "#+: Check admin 'show state' access"
  activeUrl=
  for url in $(echo "$clientUrl" | tr ',' ' ' ) ; do
    resp=$(checkShowState "$url" )
    [ "$resp" == "active" ] && activeUrl="$url"
  done
  if [ "$monCount" -ne "$clientCount" ] ; then
    msg="Error: Client and Monitor URLs must have same number of hostports."
    echo >&2 "$msg"
    checkingErrors+=("$msg")
  fi
  if [ -z "$activeUrl" ] ; then
    echo >&2 "Error: No active server found."
    checkingErrors+=("No active server found.")
  else
    echo >&2 "#+: Active Server: $activeUrl"
  fi
  [ -z "$activeUrl" ] && checkingErrors+=("No active server found.")
  echo >&2 "#+:DEBUG: checkingErr=${#checkingErrors[@]} "
  checkCertFiles
  echo >&2 "#+:DEBUG: checkingErr=${#checkingErrors[@]} "
  return ${#checkingErrors[@]}
}

function testRestdConfig {
  # TEST button to validate a registration payload
  parseCmdOptions "$@"
  parseServerSpec
  parseServerUrls
  checkRestdJson
  genRestdServerConfig
  mv "${EMS_RESTD_DIR}/ems.$groupName.$resourceInstanceId.restd.yaml" testing.server.restd.yaml
  cat - <<! > testing.restd.yaml
# UPDATE 1.4.0 Proxy (10.4 pre-release hotfix version)
loglevel: info
proxy:
  name: "tp-dp-hawk-console-cudsttbb5orp8lo3tibg-toolset"
  listeners:
    - ":14014"
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
ems:
  # default_server_group: "default"
  server_groups:
!
  cat testing.server.restd.yaml >> testing.restd.yaml
  echo >&2 "DEBUG: testing.restd.yaml"
  LD_LIBRARY_PATH="/opt/tibco/ems/current-version/lib:$LD_LIBRARY_PATH" \
  tibemsrestd --config testing.restd.yaml --loglevel debug &
  echo "$!" > testing.restd.pid
  echo "TESTING: tibemsrestd running as: $(cat testing.restd.pid)"
}

function mainCheckRestdConfig {
  parseCmdOptions "$@"
  parseServerSpec
  # parseServerUrls
  checkRestdJson
  if [ ${#checkingErrors[@]} -ne 0 ] ; then
    log "ERROR:  Errors found in configuration"
    echo >&2 "ERROR:  Errors found in configuration"
    for err in "${checkingErrors[@]}" ; do
      echo >&2 "  $err"
    done
    return ${#checkingErrors[@]} 
  fi
  log "    : Restd Checks passed"
  return 0
}

export restdCurlOpts=()
export restdUrl="${restdUrl:-http://localhost:9014}"

function restdSendCmd {
  apiPath="${1:?"API path required."}"
  action="${2:-GET}"
  data="${3}"
  if [ -n "$data" ] ; then
    [ -n "$EMS_REG_DEBUG" ] && echo >&2 "#+: " curl "[options...]" -X "$action" "${restdUrl}${apiPath}" -d "..data.."
    # echo >&2 "#+:data:$data:"
    resp=$(curl  "${restdCurlOpts[@]}" -X "$action" "${restdUrl}${apiPath}" -d "$data" )
    rtc=$?
  else
    [ -n "$EMS_REG_DEBUG" ] && echo >&2 "#+: " curl "[options...]" -X "$action" "${restdUrl}${apiPath}" 
    resp=$(curl  "${restdCurlOpts[@]}" -X "$action" "${restdUrl}${apiPath}" )
    rtc=$?
  fi
  # [ -n "$EMS_REG_DEBUG" ] && echo "$resp" | tail -1  | jq '.'  >&2 
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "$resp"
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "" ; 
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "=====($rtc)=====" 
  echo "$resp"
  return $rtc
}
function restdConnect {
  # curlOpts="-k -s -o /dev/null"
  # curlTimeout="--max-time 5 --connect-timeout 3"
  # curl -k -s -o /dev/null -w '%{http_code}' $url 
  cookies="$tmpId.cookies.txt"
  restdCurlOpts=()
  restdCurlOpts+=("-i")    # :DEBUG:
  restdCurlOpts+=("-Ss")
  restdCurlOpts+=("-c")
  restdCurlOpts+=("$cookies")
  restdCurlOpts+=("-b")
  restdCurlOpts+=("$cookies")
  restdCurlOpts+=("--header")
  restdCurlOpts+=("Content-Type: application/json")
  restdCurlOpts+=("-u")
  restdCurlOpts+=("$regUser:$regPass")
  # sgParam="server_groups=$groupName&server_tags=active"
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "#+:  curl std options: ${restdCurlOpts[*]}"
  sgParam="server_groups=$groupName"
  myUrl="$restdUrl"
  resp=$(restdSendCmd  "/connect?$sgParam" "POST" )
  rtc=$?
  [ -n "$EMS_REG_DEBUG" ] && echo "$resp" >&2
  return $rtc
}
function restdDisconnect {
  # NOTE: No error-list returned.
  restdSendCmd  "/disconnect" "POST"
}

function mainRestdEmsConfig {
  # TEST button to validate a registration payload
  parseCmdOptions "$@"
  parseServerSpec
  parseServerUrls
  checkRestdJson
  [ $? -ne 0 ] && echo >&2 "ERROR:  Errors found in configuration" && return 1
  genRestdServerConfig
}

function serverIsRegistered {
  nm=${1:-"$groupName"}
  resp=$(restdSendCmd  "/proxy/servers" )
  jexp=$(printf '.server_groups[] | select(.name=="%s")' "$nm" )
  svReg=$( echo "$resp" | tail -1 | jq "$jexp" )
  [ -z "$svReg" ] && return 1
  return 0
}
function waitForConnect {
  for try in $(seq 90) ; do 
    # restdConnect
    [ -n "$EMS_REG_DEBUG" ] && echo >&2 "Waiting for restd ($try)"
    serverIsRegistered && break
    sleep 2
  done
}

function requestRestdRestart {
  echo "$groupName: requesting restart" >> $restartRequest
  echo >&2 "#+: INFO:  requesting tibemsrestd restart"
  # waitForConnect
}

function restartRestd {
  log "    : Restarting tibemsrestd"
  echo >&2 "#+: INFO:  restarting tibemsrestd"
  [ -n "$SKIP_RESTD_RESTART" ] && return
  restdPid="$(ps -C tibemsrestd -o pid= | tr -d ' ' )"
  kill -TERM "$restdPid"
  for try in $(seq 60) ; do 
    restdSendCmd /health GET >/dev/null 2>&1 && break
    echo >&2 "waiting for tibemsrestd to restart..."
    sleep 2
  done
  restdSendCmd /health GET >/dev/null 2>&1 || checkingErrors+=("tibemsrestd failed to restart, support required.")
}
function enableGemsAdmin {
  log "    : Enable DP-admin in msg-gems-admin group"
  echo >&2 "#+: enable Gems Administration via msg-gems-admin group"
  restdConnect

  # --- ADD EMS USER
  data=$(cat - <<EOF
    {
      "name": "$EMS_ADMIN_USER",
      "description": "Dataplane local administration user",
      "password": "$EMS_ADMIN_PASSWORD"
    }
EOF
)
  resp=$(restdSendCmd "/users" "POST" "$data")

  # --- ADD demo USER
  data=$(cat - <<EOF
    {
      "name": "demo",
      "description": "Dataplane local administration user",
      "password": "demo123"
    }
EOF
)
  resp=$(restdSendCmd "/users" "POST" "$data")

  # --- Reset Password (just in case)
  data=$(cat - <<EOF
    {
      "description": "Dataplane local administration user+",
      "password": "$EMS_ADMIN_PASSWORD"
    }
EOF
)
  resp=$(restdSendCmd "/users/$EMS_ADMIN_USER" "POST" "$data")

  # --- ADD GROUP
  data=$(cat - <<EOF
    {
      "description": "Gems dashboard admin group",
      "name": "msg-gems-admin"
    }
EOF
)
  resp=$(restdSendCmd "/groups" "POST" "$data")

  # --- ENABLE ADMIN GROUP
  data=$(cat - <<EOF
    {
    "grant": [{
        "principal": {
            "name": "msg-gems-admin",
            "type": "GROUP"
        },
        "resource": {
            "type": "ADMIN",
            "permissions": ["ALL"]
        }
    }]
    }
EOF
)
  resp=$(restdSendCmd "/acls" "POST" "$data")

  # --- ADD GROUP USER -  POST /groups/msg-gems-admin/users?...
  data=$(cat - <<EOF
    {
      "add_users": ["$EMS_ADMIN_USER"]
    }
EOF
)
  resp=$(restdSendCmd "/groups/msg-gems-admin/users" "POST" "$data")

  # --- GET /groups/msg-gems-admin/users?...
  resp=$(restdSendCmd "/groups/msg-gems-admin/users" "GET" "$data")

  # --- DISCONNECT
  resp=$(restdDisconnect)
  return 0
}

function hawkServer {
  usage="hawkServer <url> <role> -- Generate a Hawk single-server json blob"
  monUrl=${1:?"$usage -- missing URL"}
  role=${2:?"$usage -- missing role"}
  scheme="$(echo "$monUrl" | cut -d: -f1)"
  host="$(echo "$monUrl" | cut -d: -f2 | tr -d '/' )"
  port="$(echo "$monUrl" | cut -d: -f3)"
  useMtls=false
  [ -n "$monitorCert" ] && useMtls=true
  cat - <<EOF
    {
      "host": "$host",
      "port": $port,
      "endPoint": "/metrics",
      "httpScheme": "$scheme",
      "scrapingInterval": 60,
      "labels": {
        "group": "$groupName",
        "resource_instance_id": "$resourceInstanceId",
        "capability_instance_id": "$resourceInstanceId",
        "dataplane_id": "$dataplaneId",
        "role": "$role"
      },
      "certVerificationEnabled": false,
      "cacert": "$monitorCert",
      "privateKey": "$monitorKey",
      "privateKeyPassword": "$monitorPass"
    }
EOF
}

function hawkPrimary {
  export serverUrl="$(echo "$monitorUrl" | cut -s -d, -f1)"
  [ -z "$serverUrl" ] && serverUrl="$monitorUrl"
  hawkServer "$serverUrl" "primary"
}

function hawkSecondary {
  export serverUrl="$(echo "$monitorUrl" | cut -s -d, -f2 )"
  [ -z "$serverUrl" ] && return 
  echo ","
  hawkServer "$serverUrl" "secondary"
}

function hawkStandby {
  export serverUrl="$(echo "$monitorUrl" | cut -s -d, -f3 )"
  [ -z "$serverUrl" ] && return 
  echo ","
  hawkServer "$serverUrl" "standby"
}

function genHawkPayload {
  # Generate a payload for a Hawk registration
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "#+: genHawkPayload - group=$groupName ($tmpId.hawk.json)"
  cat - <<EOF | tee $tmpId.hawk.json
{
  "serverGroup": "$groupName",
  "serverDetails": [
    $(hawkPrimary)
    $(hawkSecondary)
    $(hawkStandby)
  ]
}
EOF
}

function enableHawkScraping {
  # POST https://<hawkconsole-host>:<hawkconsole-port>/hawkconsole/base/exporter/ems/register
  log "    :$groupName: Enable hawk scraping"
  echo >&2 "#+: enableHawkScraping"
  hawkPayload="$(genHawkPayload)"
  hawkHost="${HAWK_HOST:-localhost}"
  hawkPort="${HAWK_PORT:-8080}"
  hawkHost="${HAWK_HOST:-"tp-dp-hawk-console-connect"}"
  hawkPort="${HAWK_PORT:-9687}"
  apiRegister="hawkconsole/base/exporter/ems/register"
  export curlOpts=()
  if [ -n "$hawkToken" ] ; then
    curlOpts+=("-u")
    curlOpts+=("$(echo $hawkToken | base64 -d )")
  fi
  curlOpts+=("-i")
  curlOpts+=("--location")
  curlOpts+=("-Ss")
  curlOpts+=("--header")
  curlOpts+=("Content-Type: application/json")
  curlOpts+=("-k")
  curlOpts+=("-X")
  curlOpts+=("POST")
  curlOpts+=("-d")
  curlOpts+=("$hawkPayload")
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "#+: " curl '"${curlOpts[@]}"' "https://$hawkHost:$hawkPort/$apiRegister"
  resp=$(curl "${curlOpts[@]}" "https://$hawkHost:$hawkPort/$apiRegister" )
  rtc=$?
  [ $rtc -ne 0 ] && echo >&2 "ERROR:  Hawk Register error." && echo >&2 "$resp" && echo >&2 ""
  [ -n "$EMS_REG_DEBUG" ] && echo "$resp" | tail -1 | jq '.'  >&2 
  return 0
}

function hawkUnregister {
  # POST https://<hawkconsole-host>:<hawkconsole-port>/hawkconsole/base/exporter/ems/unregister
  usage='hawkUnregister <server-group-name> -- Unregister EMS with Hawk'
  groupName=${1:?"$usage"}
  log "    : Unregister hawk scraping"
  echo >&2 "DEBUG: Unregister"
  hawkPayload="$(printf '{"serverGroup": "%s"}' "$groupName")"
  hawkHost="${HAWK_HOST:-localhost}"
  hawkPort="${HAWK_PORT:-8080}"
  hawkHost="${HAWK_HOST:-"tp-dp-hawk-console-connect"}"
  hawkPort="${HAWK_PORT:-9687}"
  apiRegister="hawkconsole/base/exporter/ems/unregister"
  export curlOpts=()
  if [ -n "$hawkToken" ] ; then
    curlOpts+=("-u")
    curlOpts+=("$(echo $hawkToken | base64 -d )")
  fi
  curlOpts+=("-i")
  curlOpts+=("--location")
  curlOpts+=("-Ss")
  curlOpts+=("--header")
  curlOpts+=("Content-Type: application/json")
  curlOpts+=("-k")
  curlOpts+=("-X")
  curlOpts+=("POST")
  curlOpts+=("-d")
  curlOpts+=("$hawkPayload")
  [ -n "$EMS_REG_DEBUG" ] && echo >&2 "#+: " curl '"${curlOpts[@]}"' "https://$hawkHost:$hawkPort/$apiRegister"
  resp=$(curl "${curlOpts[@]}" "https://$hawkHost:$hawkPort/$apiRegister" )
  rtc=$?
  [ $rtc -ne 0 ] && echo >&2 "ERROR:  Hawk Unregister error." && echo >&2 "$resp" && echo >&2 ""
  [ -n "$EMS_REG_DEBUG" ] && echo "$resp" | tail -1 | jq '.'  >&2 
  return 0
}

function testHawkPayload {
  parseCmdOptions "$@"
  parseServerSpec
  parseServerUrls
  genHawkPayload
}

function mainRegisterEms {
  # Register an EMS group via JSON payload file
  mainRestdEmsConfig "$@"
  [ $? -ne 0 ] && echo >&2 "ERROR:  Errors found in configuration" && return 1
  # restartRestd
  requestRestdRestart
  waitForConnect
  [ $? -ne 0 ] && echo >&2 "ERROR:  Errors found on restart" && return 1
  enableGemsAdmin
  [ $? -ne 0 ] && echo >&2 "ERROR:  Error during EMS Gems configuration" && return 1
  enableHawkScraping
  [ $? -ne 0 ] && echo >&2 "ERROR:  Hawk config failed." && return 1
  log "    :$groupName: Registration complete"
  return ${#checkingErrors[@]}
}

function mainUnregisterEms {
  usage="mainUnregisterEms [-hawk=token] <-id=Riid | -g=groupName> -- Unregister an EMS group via name or riid"
  # ems.ems-single.riid-9170.restd.yaml
  rtc=0
  parseCmdOptions "$@"
  if [ -n "$resourceInstanceId" ] ; then
    restRiidFile="$(echo $EMS_RESTD_DIR/ems.*."$resourceInstanceId".restd.yaml )"
    [ -f "$restRiidFile" ] && export restFile="$restRiidFile"
    export groupName="$(cat "$restFile" | yq '.[0].name' )"
    [ "$groupName" == "null" ] && echo >&2 "ERROR:  Missing groupName in $restRiidFile" && groupName=""
  elif [ -n "$groupName" ] ; then
    restGroupFile="$(echo $EMS_RESTD_DIR/ems."$groupName".*.restd.yaml )"
    [ -f "$restGroupFile" ] && export restFile="$restGroupFile"
  else
    echo >&2 "ERROR: Missing unregister target ; $usage"
    rtc=1
  fi
  # Unregister with tibemsrestd
  [ ! -f "$restFile" ] && echo >&2 "ERROR:  Missing restd file: $restRiidFile" 
  if [ -f "$restFile" ] ; then
    rm "$restFile"
    echo >&2 "INFO: Unregistered $restFile"
    # restartRestd
    requestRestdRestart
  fi
  # Unregister with hawkConsole Scraping
  hawkUnregister "$groupName"
  [ $? -ne 0 ] && echo >&2 "ERROR:  Hawk Unregister error." && rtc=1
  return $rtc
}

export REGISTER_DEBUG_LOG="${REGISTER_DEBUG_LOG:-/$EMS_RESTD_DIR/register-debug.log}"
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"
function log
{ echo "$(date "$fmtTime"): $*" >> $REGISTER_DEBUG_LOG ; }

# MAIN OPTION: RUN A FUNCTION IF ASKED
# .. do nothing if sourced / -z "$1"
if [[ "$1" =~ help ]] ; then
  echo "=== Available main functions are: "
  egrep "^function main" $0 | sed -e 's/function //' -e 's/ {$//'
elif [ -n "$*" ] ; then
  # Run something
  mkdir -p "$EMS_RESTD_DIR"   # just in case ;)
  main="${1}"
  log "===== main: $main "
  shift 
  for arg in "$@" ; do
    log "    arg: $arg"
  done
    log "    tmp: $tmpId"
  $main "$@"
  rtc=$?
  [ -z "$EMS_REG_DEBUG" ] && rm -rf "$tmpId".*
  exit $rtc
fi
