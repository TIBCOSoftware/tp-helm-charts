#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="
$cmd -- Periodically refresh JWKS from CP
"

# TODO: Add stale ops-shell cli subdir cleanup to Gateway refresh script

fmtTime="--rfc-3339=ns"
jwksFile="${JWKS_FILE:-/logs/jwks/jwks.json}"
freqJwks="${JWKS_REFRESH_INTERVAL:-3600}"
freqTibemsrestdWatch=1
freqK8EmsWatch=30
export iter=0
export repairEmsIter=0
# sampleWait="${JWKS_REFRESH_INTERVAL:-720}"


# Set signal traps
function log
{ echo "$(date "$fmtTime"): $*" ; }

function do_shutdown
{ log "-- Shutdown received (SIGTERM): host=$HOSTNAME" && exit 0 ; }
trap do_shutdown SIGINT
trap do_shutdown SIGTERM

# Add tibemsrestd restart support
export EMS_RESTD_DIR=${EMS_RESTD_DIR:-/logs/restd-api}
export restartRequest="${EMS_RESTD_DIR}/restart-request"
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
function waitForStableRequest {
    # Wait up to 5 seconds for requests to slow down
    last=$(wc -l < "$restartRequest")
    now=0
    for try in $(seq 5) ; do
        sleep 1
        now=$(wc -l < "$restartRequest")
        if [ "$now" -eq "$last" ] ; then
            break
        else
            last="$now"
        fi
        log "#+: Waiting for more restd restart requests..."
    done
    log "#+: Restarting for $now pending requests..."
}
function restartRestd {
  log "    : Restarting tibemsrestd"
  waitForStableRequest
  log "#+: INFO:  restarting tibemsrestd"
  restdPid="$(ps -C tibemsrestd -o pid= | tr -d ' ' )"
  rm -f $restartRequest
  kill -TERM "$restdPid"
  for try in $(seq 60) ; do 
    restdSendCmd /health GET >/dev/null 2>&1 && break
    log "waiting for tibemsrestd to restart..."
    sleep 2
  done
  restdSendCmd /health GET >/dev/null 2>&1 || log "tibemsrestd failed to restart, support required."
  # Allow time for processing before next possible restart
  log "waiting for tibemsrestd to stabilize..."
  sleep 5 
  log "open for business ..."
  return
}

function getJWKS {
    # Setup standard Curl options
    export cOpts=()
    #curlTimeout="--max-time 5 --connect-timeout 3"
    cOpts+=(--max-time)
    cOpts+=(5)
    cOpts+=(--connect-timeout)
    cOpts+=(3)
    cOpts+=(-Ss)
    cOpts+=(--location)
    cOpts+=(--header)
    cOpts+=('Content-Type: application/json')
    cOpts+=(-k)
    # use cp-proxy service to reach CP
    myCPHOST="http://cp-proxy.$MY_NAMESPACE.svc.cluster.local:80"
    # DEBUG: echo >&2 "#+: " curl -i "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwks-uri" 
    curl -i "${cOpts[@]}" "$myCPHOST/idm/v1/oauth2/jwks-uri"  > curl.out 
    tail -1 curl.out
}

function saveJWKS {
    # Use atomic file update, only update if changed.
    jwks="$1"
    check=$(echo "$jwks" | jq '.keys' 2>/dev/null)
    if [  -z "$jwks" ] ; then
        log "No JWKS available"
    elif [  "$check" = "null" ] ; then
        log "invalid JWKS fetched ($jwks)"
    elif [  -f "$jwksFile" ] ; then
        oldmd5="$(cat "$jwksFile" | md5sum)"
        newmd5="$(echo "$jwks" | md5sum)"
        if [ "$oldmd5" != "$newmd5" ] ; then
            log "JWKS update detected"
            tmp="jwks.$RANDOM"
            echo "$jwks" > "$tmp"
            mv "$tmp" "$jwksFile"
            echo '{"dp":{ "jwks": '"$jwks"'}}' > "$tmp"
            mv "$tmp" "mock.params.yaml"
        else
            log "JWKS unchanged"
        fi
        # Also save Params version
    else
        log "saving JWKS"
        echo "$jwks" > "$jwksFile"
        echo '{"dp":{ "jwks": '"$jwks"'}}' > "mock.params.yaml"
    fi
}

# TODO: MSGDP-1291: Remove after 1.9.0 GA, when legacy repairs are no longer needed
function repairEmsSecret {
    x=${1:?Secret name required}
    dpb64Pass=$(echo -n "$DP_ADMIN_PASSWORD" | base64 -w 0)
    dpPostData="$(printf '{"name":"%s","description":"user-update","password":"%s"}' $DP_ADMIN_USER $DP_ADMIN_PASSWORD )"
    dpAddGroup="$(printf '{"add_users":["%s"]}' $DP_ADMIN_USER )"
    dpK8patch=$(printf '{"data":{"EMS_ADMIN_PASSWORD":"%s"}}' "$dpb64Pass" )
    echo >&2 "Updating legacy EMS admin secret: $x"
    groupName=${x/-tibadmin/} 
    emsServer="tcp://$groupName-emsactive:9011"
    emsAdmin="http://$groupName-emsactive:9014"
    # Update EMS password
    /boot/emsadmin-curl.sh -u 'admin' -p '' -s $emsAdmin -a /users/$DP_ADMIN_USER -X POST \
        --data "$dpPostData"
    /boot/emsadmin-curl.sh -u 'admin' -p '' -s $emsAdmin  --data "$dpAddGroup" \
        -X POST -a "/groups/msg-gems-admin/users" 
    # Patch legacy EMS secret
    echo "#+: " kubectl patch secret/$x --type=merge -p='"$dpK8patch"'
    kubectl patch secret/$x --type=merge -p="$dpK8patch"
}

function repairEmsSecrets {
echo "Checking for legacy EMS admin secrets ... "
kubectl get -o wide secrets | egrep '[-]tibadmin\>' | egrep -v tp-msg-gateway-tibadmin | while read x o ; do 
    repairEmsSecret $x
done
}

# Add EMS Registration watcher support
emsList=/logs/ems-list.out
> $emsList
function refreshEms {
    kubectl get sts -l=app.kubernetes.io/name=ems | egrep -v NAME | cut -d' ' -f1 | sort > $emsList.tmp
    if ! diff -q $emsList $emsList.tmp > $emsList.diff 2>&1 ; then
        # Update the registration
        newEms=$(cat $emsList.diff | egrep '^> ' | cut -d' ' -f2- )
        deletedEms=$(cat $emsList.diff | egrep '^< ' | cut -d' ' -f2- )
        log "#+: EMS list changed, new: $newEms, deleted: $deletedEms"
        /logs/boot/ems-registration.sh mainK8RegisterEms
        mv $emsList.tmp $emsList
        # TODO: MSGDP-1291: Remove after 1.9.0 GA, when legacy repairs are no longer needed
        export repairEmsIter=3
    fi

}

echo "# ===== $cmd ====="
echo "#+: Watching for tibemsrestd restart requests..."
while true
do

    if [ 0 -eq $(( $iter % $freqJwks )) ] ; then
        echo >&2 "#+: Refreshing JWKS from CP"
        jwks="$(getJWKS)"
        saveJWKS "$jwks"
    fi

    if [ 0 -eq $(( $iter % $freqK8EmsWatch )) ] ; then
        refreshEms
        # TODO: 1.7.0 compatibility
        # TODO: MSGDP-1291: Remove after 1.9.0 GA, when legacy repairs are no longer needed
        if [ 0 -lt  $repairEmsIter ] ; then
            repairEmsSecrets
            repairEmsIter=$((repairEmsIter - 1))
        fi
    fi

    if [ 0 -eq $(( $iter % $freqTibemsrestdWatch )) ] ; then
        [ -f "$restartRequest" ] && echo >&2 "#+: Restart Request detected." && restartRestd
    fi
    sleep 1
    iter=$((iter + 1))
done
