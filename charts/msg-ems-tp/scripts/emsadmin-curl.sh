#!/bin/bash
# Copyright (c) 2023-2025 Cloud Software Group, Inc. All Rights Reserved. Confidential and Proprietary.

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"

usage="
    emsadmin-curl.sh [options] -a <api-path> -- Issue a curl command to tibemsrestd
    -a <api-path>   : REST API path
    -s <server-url> : explicit tibemsrestd URL
    -u <username>   : set username
    -p <password>   : set password
    -b <bear-token> : use a bearer token
    -c              : confirm
    *               : pass everything else to curl
ENV overrides:
    EMS_ADMIN_URL   : http schema://host:port of rest proxy
    EMS_ADMIN_HOST  : load-balancer hostname (assumes http & 9014)
Examples:
    ./emsadmin-curl.sh -a /server
    ./emsadmin-curl.sh -a /users
    EMS_ADMIN_URL=http://my-nlb:10001 ./emsadmin-curl.sh -a /server
For defaults use:
    EMS_TCP_URL, EMS_ADMIN_PORT, EMS_ADMIN_USER, EMS_ADMIN_PASSWORD
"

curl_opts=()
curl_opts+=("-H" "Content-Type: application/json")
curl_opts+=("-i" "-ks")
curl_opts+=("-c" "./cookies.txt")
curl_opts+=("-b" "./cookies.txt")
auth_opts=()
EMS_REST_API=
EMS_ADMIN_USER=${EMS_ADMIN_USER:-admin}
EMS_ADMIN_PORT=${EMS_ADMIN_PORT:-9014}
confirm=
# Allow ENV Overrides for:
# EMS_ADMIN_HOST=
# EMS_ADMIN_URL=
while [ $# -gt 0 ] ; do arg="$1"
  case "$arg" in
    -a) EMS_REST_API="${2}" ; shift ;;
    -h) EMS_ADMIN_HOST="${2}" ; shift ;;
    -s) EMS_ADMIN_URL="${2}" ; shift ;;
    -u) EMS_ADMIN_USER="${2}" ; shift ;;
    -p) EMS_ADMIN_PASSWORD="${2}" ; shift ;;
    -b) EMS_ADMIN_BEARER="${2}" ; shift ;;
    -c) confirm=true ;;
    -debug|--debug)  set -x ;;
    -help) echo "$usage" ; exit 1 ;;
    * ) cmd_opts+=("$1") ;;
  esac ; shift
done

# GET URL
[ -z "$EMS_REST_API" ] && echo "Error: EMS_REST_API required." && echo "$usage" && exit 1 
if [ -n "$EMS_ADMIN_URL" ] ; then
    export EMS_ADMIN_URL="$EMS_ADMIN_URL"
elif [ -n "$EMS_ADMIN_HOST" ] ; then
    export EMS_ADMIN_URL="http://$EMS_ADMIN_HOST:$EMS_ADMIN_PORT"
elif [ -n "$EMS_TCP_URL" ] ; then
    export EMS_ADMIN_HOST=$(echo $EMS_TCP_URL | cut -d: -f2 | cut -d/ -f3)
    export EMS_ADMIN_URL="http://$EMS_ADMIN_HOST:$EMS_ADMIN_PORT"
else
    echo "Error: EMS_TCP_URL or EMS_ADMIN_HOST or EMS_ADMIN_URL required." ; echo "$usage" ; exit 1
fi
# GET AUTH
if [ -n "$EMS_ADMIN_BEARER" ] ; then
    auth_opts+=("-H" "Authorization" "Bearer ${EMS_ADMIN_BEARER}")
else
    auth_opts+=("-u" "$EMS_ADMIN_USER:$EMS_ADMIN_PASSWORD")
fi

# Avoid corrupting curl openssl build
export LD_LIBRARY_PATH= 
> curl.debug
curl "${curl_opts[@]}" "${auth_opts[@]}" -i -X POST  "$EMS_ADMIN_URL"/connect >> curl.debug 2>> curl.debug 

if [ "$confirm" ] ; then
    response=$(curl "${curl_opts[@]}" "${auth_opts[@]}"  "${cmd_opts[@]}" "${EMS_ADMIN_URL}${EMS_REST_API}" 2>> curl.debug)
    response=(${response[@]})
    confirmation_code=$(echo "${response[-1]}" | jq -r '.confirmation')
    if [[ $EMS_REST_API == *'?'* ]]; then
        EMS_REST_API="${EMS_REST_API}&confirmation=${confirmation_code}"
    else
        EMS_REST_API="${EMS_REST_API}?confirmation=${confirmation_code}"
    fi
fi
curl "${curl_opts[@]}" "${auth_opts[@]}"  "${cmd_opts[@]}" "${EMS_ADMIN_URL}${EMS_REST_API}" 2>> curl.debug

curl "${curl_opts[@]}" "${auth_opts[@]}" -i -X POST  "$EMS_ADMIN_URL"/disconnect >> curl.debug 2>> curl.debug
