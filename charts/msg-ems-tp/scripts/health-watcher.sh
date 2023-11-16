#!/bin/bash
#
# Copyright (c) 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained 
# in the license file that is distributed with this file.  
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="
$cmd [stsname] -- DP STS health actions based on health monitoring annotations
ENV OPTIONS:
    STS_NAME            - Set name to watch
    HEALTH_INTERVAL     - override default collection interval of 20s
    HEALTH_CSV          - override ./health.csv summary filename
    HEALTH_ACTION       - Choose action (watcher, redeploy )
"
csvfile="${HEALTH_CSV:-./health.csv}"
stsdata="my-sts.json"
interval="${HEALTH_INTERVAL:-20}"
action="${HEALTH_ACTION:-watcher}"
STS_NAME="${STS_NAME:-$MY_SVC_NAME}"
STS_NAME="${1:-$STS_NAME}"
## more portable, but no milliseconds:  
## fmtTime="+%y%m%dT%H:%M:%S"
## Ubuntu preferred: 
fmtTime="--rfc-3339=ns"

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

function rotate_log() {
    usage="rotate_log <file> -- move versions 0>1>2>..."
    file=${1:?"$usage - filename required."}
    [ ! -f "$file" ] &&  return 0
    vmax="${2:-20}"
    for ver in $(seq $vmax -1 0) ; do
        [ -f "$file.$ver" ] && mv "$file.$ver" "$file.$(($ver + 1))"
    done
    mv "$file" "$file.0"
}

function sts_get_config {
    quorumStrategy="" replicas="" isLeader="" quorumMin="1" 
    kubectl get sts "$STS_NAME" -o json > $stsdata
    [ $? -ne 0 ] && log " No STS data, not watching health ..." && return 1
    quorumStrategy="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/quorum-strategy"]' )"
    replicas="$(cat $stsdata | jq '.spec.replicas' )"
    isLeader="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/leader-endpoint"]' )"
    quorumMin="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/quorum-min"]' )"
    stsNamespace="$(cat $stsdata | jq -r '.metadata.namespace' )"
    isInQuorum="http://localhost:9013/api/v1/available"
    [ "$quorumStrategy" = "quorum-based" ] && quorumMin=$(( $replicas / 2 + 1 ))
}

function sts_check_health {
    inQuorumCount=0 leader="" missingList= health=bad
    maxReplica=$(( $replicas - 1 ))
    for r in $(seq 0 $maxReplica ) ; do
        podname="$STS_NAME-$r"
        podhost="$STS_NAME-$r.$STS_NAME.$stsNamespace"
        leaderUrl=$(echo "$isLeader" | sed -e "s;localhost;$podhost;")
        # curl -k -s -o /dev/null -w '%{http_code}' $url 
        leaderCode=$( curl -k -s -o /dev/null -w '%{http_code}' "$leaderUrl" )
        leaderCode=${leaderCode:-405}
        [ "$leaderCode" -eq 200 ] && leader="$podname"
        quorumUrl=$(echo "$isInQuorum" | sed -e "s;localhost;$podhost;")
        quorumCode=$( curl -k -s -o /dev/null -w '%{http_code}' "$quorumUrl" )
        quorumCode=${quorumCode:-405}
        [ "$quorumCode" -eq 200 ] && inQuorumCount=$(( $inQuorumCount + 1))
        [ "$quorumCode" -ne 200 ] && missingList="$missingList $podname($quorumCode)"
    done
    # Compute health : bad, ok, good, great 
    [ -n "isLeader" ] && [ -z "$leader" ] && health=bad && return
    [ $inQuorumCount -eq $replicas ] && health=great && return
    [ $inQuorumCount -gt $quorumMin ] && health=good && return
    [ $inQuorumCount -eq $quorumMin ] && health=ok && return
    health=bad
    return
}

function watcher {
    echo "# ===== $cmd ====="
    rotate_log "$csvfile"
    # timestamp,health,quorum-strategy,replicas,leader,inquorum-count,missing-list
    echo  "datetime,health,quorum-strategy,replicas,qMin,leader,inquorum-count,missing-list" > $csvfile
    sts_get_config
    
    while true
    do
        dtime="$(date "$fmtTime" )"
        #  "datetime,health,quorum-strategy,replicas,leader,inquorum-count,missing-list" >> $csvfile
        health="" leader="" inQuorumCount=0 missingList=
        sts_check_health
        echo  "$dtime,$health,$quorumStrategy,$replicas,$quorumMin,$leader,$inQuorumCount,$missingList" >> $csvfile
    
        # Do not delay pod restarts!
        for x in $(seq $interval) ; do 
            sleep 1
        done
    done
}

function wait_for_release {
    # Expects $MY_RELEASE to be set as helm release name
    relname=${1:-$MY_RELEASE}
    for try in $(seq 600 ) ; do
        hstatus=$(helm status $relname 2>/dev/null | egrep '^STATUS: ' | cut -f2 -d: | tr -d ' ' )
        [ "$hstatus" = "deployed" ] && break
        log ".. Waiting ($hstatus : $relname)"
        sleep 3
    done
    [ "$hstatus" != 'deployed' ] && log "Error: upgrade did not complete successfully, aborting" && return 1
    log "INFO: helm upgrade Complete."
}

function redeploy {
    log "#===== WAITING ON RELEASE ====="
    wait_for_release
    log "#===== REDEPLOY STARTING ====="
    sts_get_config
    sts_check_health 
    [ "$health" != 'great' ] && log "Warning: STS=$STS_NAME not healthy - aborting ($missingList)." && return 1
    upgLeader="$leader"
    [ -z "$upgLeader" ] && log "Warning: No leader for $STS_NAME - aborting upgrade ($missingList)." && return 1
    podList=()
    for r in $(seq 0 $maxReplica ) ; do
        podname="$STS_NAME-$r"
        [ "$podname" = "$upgLeader" ] && log "INFO: Saving leader $podname - for last" && continue 
        podList+="$podname "
    done
    podList+="$upgLeader "
    for podname in ${podList[*]} ; do
        log "Deleting pod=$podname"
        kubectl delete pod "$podname"
        health=upgrade
        # Wait for healthy
        for try in $(seq 600 ) ; do
            [ "$health" = 'great' ] && break
            sleep 5 
            sts_check_health
            log  "$dtime,$health,$leader,$inQuorumCount,$missingList" 
        done
        [ "$health" != 'great' ] && log "Warning: did not recover health, aborting" && return 1
    done
    log "INFO: Success - Redeploy of $STS_NAME Complete."
    return 0
}

case "$action" in
    "watcher") watcher ;;
    "redeploy") redeploy ;;
    "skip-redeploy") echo "Skipping pod restarts as requested. " ;;
    *) echo "$usage" ; echo "Invalid action = $action" ; exit 1 ;;
esac
