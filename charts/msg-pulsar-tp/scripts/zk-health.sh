#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="
$cmd -- watch local zookkeeper health and expose ControlPlane health API
    /isleader - returns 200 if this pod is the leader
    /inquorum - returns 200 if this pod has rejoined the quorum
ENV OPTIONS:
    ZK_ADMIN_PORT        - override default http admin port of 9990   
    ZK_PROBE_INTERVAL   - override default probe interval of 10s
    LOG_ALERT_PORT      - enable fluentbit alerting to this port

    POD_MON_CSV         - override ./pod-mon.csv summary filename
    POD_DISK_CSV        - override ./pod-disk.csv summary filename
    POD_MAX_THREADS     - override default max threads of 15000
    POD_MON_DISK        - enable low-disk monitoring with a list of directories
    POD_DISK_ALERT_SH   - path to script for low_disk alerts (optional)
"
isleaderFile="./health/isleader"
inquorumFile="./health/inquorum"
shimPid=0
sampleWait="${ZK_PROBE_INTERVAL:-10}"
zkRestPort="${ZK_ADMIN_PORT:-9990}"
## more portable, but no milliseconds:  
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"

# Set signal traps
function log
{ echo "$(date "$fmtTime"): $*" ; }
function do_sighup
{ log "-- Got SIGHUP: host=$HOSTNAME" ; }
function do_shutdown
{ 
    log "-- Shutdown received (SIGTERM): host=$HOSTNAME" 
    echo 'false' > $isleaderFile
    echo 'false' > $inquorumFile
    [ "$shimPid" -gt 0 ] && kill $shimPid
    exit 0 
}
trap do_shutdown SIGINT
trap do_shutdown SIGTERM
trap do_sighup SIGHUP

# Initialize health files
mkdir -p ./health
echo 'false' > $isleaderFile
echo 'false' > $inquorumFile
# /usr/local/watchdog/bin/dp-health-shim &
# shimPid=$!

# SUPPORT SENDING FLUENTBITS ALERT MESSAGES
#curl -i -d '{"message":"hello","level":"warn","caller":"alert"}' -XPOST -H "content-type: application/json" http://localhost:8099/dp.routable
fluent_curl_h="content-type: application/json"
fluent_curl_opts="-Ss -XPOST http://localhost:${LOG_ALERT_PORT:-8099}/dp.routable"
function alert
{ 
    log "ALERT: $*" 
    payload="$(printf '{"message":"%s","level":"alert","caller":"%s"}' "$*" "health-watcher.sh" )"
    if [ -n "$LOG_ALERT_PORT" ] ; then
        curl -d "$payload" -H "$fluent_curl_h" $fluent_curl_opts || true
    fi
}


# Initialize health files
echo "# ===== $cmd : Initializing Health Probes ====="
mkdir -p ./health
echo 'false' > $isleaderFile
echo 'false' > $inquorumFile
/usr/local/watchdog/bin/dp-health-shim &
shimPid=$!

# ..//msg-ems-tp/scripts/health-watcher.sh:81:    curlOpts="-k -s -o /dev/null"
# ..//msg-ems-tp/scripts/health-watcher.sh:82:    curlTimeout="--max-time 5 --connect-timeout 3"
curlOpts="-k -Ss"
curlTimeout="--max-time 5 --connect-timeout 3"
curlUrl="http://localhost:${zkRestPort}/commands/leader"

# Trigger log message on first probe ;) 
isleader="$(cat $isleaderFile)"
inquorum="$(cat $inquorumFile)"
myhost="$(hostname)"
reportInterval=120
nextReport=$(date '+%s')
while true
do
    # Resync disk files periodically (just in case)
    if [ "$(date +%s)" -gt "$nextReport" ] ; then
        nextReport=$(( $(date '+%s') + $reportInterval ))
        echo "$isleader" > $isleaderFile && log "Status: $myhost leader=$isleader"
        echo "$inquorum" > $inquorumFile && log "Status: $myhost quorum=$inquorum"
    fi
    # check zk status & update probes
    leaderStatus="$(curl $curlOpts $curlTimeout "$curlUrl" | jq -r '.is_leader' )"
    if [ -z "$leaderStatus" ] ; then
        [ $isleader == "true" ] && echo 'false' > $isleaderFile && log "Status: $myhost not leader"
        [ $inquorum == "true" ] && echo 'false' > $inquorumFile && log "Status: $myhost not in quorum"
        isleader="false"
        inquorum="false"
    elif [ "$leaderStatus" == "null" ] ; then
        [ $isleader == "true" ] && echo 'false' > $isleaderFile && log "Status: $myhost not leader"
        [ $inquorum == "true" ] && echo 'false' > $inquorumFile && log "Status: $myhost not in quorum"
        isleader="false"
        inquorum="false"
    elif [ "$leaderStatus" == "true" ] ; then
        [ $isleader != "true" ] && echo 'true' > $isleaderFile && log "Status: $myhost is leader"
        [ $inquorum != "true" ] && echo 'true' > $inquorumFile && log "Status: $myhost is in quorum"
        isleader="true"
        inquorum="true"
    elif [ "$leaderStatus" == "standalone" ] ; then
        [ $isleader != "true" ] && echo 'true' > $isleaderFile && log "Status: $myhost is leader"
        [ $inquorum != "true" ] && echo 'true' > $inquorumFile && log "Status: $myhost is in quorum"
        isleader="true"
        inquorum="true"
    else
        # follower or observer
        [ $isleader == "true" ] && echo 'false' > $isleaderFile && log "Status: $myhost no longer leader"
        [ $inquorum != "true" ] && echo 'true' > $inquorumFile && log "Status: $myhost is in quorum"
        isleader="false"
        inquorum="true"
    fi

    # Wait, but do not delay pod restarts!
    for x in $(seq $sampleWait) ; do 
        sleep 1
    done
done

[ "$shimPid" -gt 0 ] && kill $shimPid
