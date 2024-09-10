#!/bin/bash
#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
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
    LOG_ALERT_PORT      - Port for fluentbits alerting (default 8099)
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

# SUPPORT SENDING FLUENTBITS ALERT MESSAGES
#curl -i -d '{"message":"hello","level":"warn","caller":"alert"}' -XPOST -H "content-type: application/json" http://localhost:8099/dp.routable
curl_h="content-type: application/json"
curl_opts="-Ss -XPOST http://localhost:${LOG_ALERT_PORT-8099}/dp.routable"
function alert
{ 
    log "ALERT: $*" 
    payload="$(printf '{"message":"%s","level":"alert","caller":"%s"}' "$*" "health-watcher.sh" )"
    if [ -n "$LOG_ALERT_PORT" ] ; then
        curl -d "$payload" -H "$curl_h" $curl_opts || true
    fi
}

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
    lastReplicas=$replicas
    isLeader="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/leader-endpoint"]' )"
    [ "$isLeader" = "null" ] && isLeader=""
    quorumMin="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/quorum-min"]' )"
    replicaMin="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/replica-min"]' )"
    replicaMax="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/replica-max"]' )"
    if [ "$quorumMin" = "null" ] || [ -z "$quorumMin" ] ; then 
        quorumMin="1"
    fi
    if [ "$replicaMin" = "null" ] || [ -z "$replicaMin" ] ; then 
        replicaMin="1"
    fi
    if [ "$replicaMin" -gt "$replicas" ] ; then
        alert "spec-alert $STS_NAME: replicas = $replicas, min=$replicaMin"
        replicas="$replicaMin"
    fi
    if [ "$replicaMax" = "null" ] || [ -z "$replicaMax" ] ; then 
        replicaMax="$replicas"
    fi
    if [ "$replicas" -gt "$replicaMax" ] ; then
        alert "spec-alert $STS_NAME: replicas = $replicas, max=$replicaMax"
    fi
    stsNamespace="$(cat $stsdata | jq -r '.metadata.namespace' )"
    # isInQuorum="http://localhost:9013/api/v1/available"
    isInQuorum="$(cat $stsdata | jq -r '.metadata.annotations["platform.tibco.com/is-in-quorum"]' )"
    [ "$isInQuorum" = "null" ] && isInQuorum=""
    [ "$quorumStrategy" = "quorum-based" ] && quorumMin=$(( $replicas / 2 + 1 ))
    podhost="$STS_NAME-0.$STS_NAME.$stsNamespace"
    leaderUrl=$(echo "$isLeader" | sed -e "s;localhost;$podhost;")
    quorumUrl=$(echo "$isInQuorum" | sed -e "s;localhost;$podhost;")
    cat - <<!
--------------------------
replicaMin=$replicaMin
replicaMax=$replicaMax
quorumStrategy=$quorumStrategy
quorumMin=$quorumMin
isLeader=$isLeader
isInQuorum=$isInQuorum
replicas=$replicas
podhost="$STS_NAME-0.$STS_NAME.$stsNamespace"
leaderUrl=$leaderUrl
quorumUrl=$quorumUrl
--------------------------
!
}

export ALERT_ACTIVE=n
function sts_check_health {
    curlOpts="-k -s -o /dev/null"
    curlTimeout="--max-time 5 --connect-timeout 3"
    inQuorumCount=0 leader="" missingList= health=bad
    # Check for scaling actions
    kubectl get sts "$STS_NAME" -o json > $stsdata
    xreplicas="$(cat $stsdata | jq '.spec.replicas' )"
    [ "$xreplicas" != "$lastReplicas" ] && \
            alert "scaling-alert $STS_NAME: replicas = $xreplicas, was $lastReplicas" &&
            sts_get_config

    # Check health
    maxReplica=$(( $replicas - 1 ))
    for r in $(seq 0 $maxReplica ) ; do
        podname="$STS_NAME-$r"
        podhost="$STS_NAME-$r.$STS_NAME.$stsNamespace"
        if [ -n "$isLeader" ] ; then
            leaderUrl=$(echo "$isLeader" | sed -e "s;localhost;$podhost;")
            # curl -k -s -o /dev/null -w '%{http_code}' $url 
            leaderCode=$( curl $curlOpts $curlTimeout -w '%{http_code}' "$leaderUrl" )
            leaderCode=${leaderCode:-405}
            [ "$leaderCode" -eq 200 ] && leader="$podname"
        fi
        if [ -z "$isInQuorum" ] ; then
            pstatus="$(kubectl get pod $podname -o jsonpath='{.status.phase}' )"
            [ "$pstatus" = "Running" ] && inQuorumCount=$(( $inQuorumCount + 1))
            [ "$pstatus" != "Running" ] && missingList="$missingList $podname($pstatus)"
        else
            quorumUrl=$(echo "$isInQuorum" | sed -e "s;localhost;$podhost;")
            quorumCode=$( curl $curlOpts $curlTimeout -w '%{http_code}' "$quorumUrl" )
            quorumCode=${quorumCode:-405}
            [ "$quorumCode" -eq 200 ] && inQuorumCount=$(( $inQuorumCount + 1))
            [ "$quorumCode" -ne 200 ] && missingList="$missingList $podname($quorumCode)"
        fi
    done
    # Compute health : bad, ok, good, great 
    if [ -n "$isLeader" ] && [ -z "$leader" ] ; then 
        health=bad
    elif [ $inQuorumCount -eq $replicas ] ; then
        health=great
    elif [ $inQuorumCount -gt $quorumMin ] ; then
        health=good
    elif [ $inQuorumCount -eq $quorumMin ] ; then
        health=ok
    else 
        health=bad
    fi
    if [ "$health" != "great" ] ; then
        ALERT_ACTIVE=y
        alert "health-alert $STS_NAME: health = $health"
    elif [ "$ALERT_ACTIVE" = "y" ] ; then
        ALERT_ACTIVE=n
        alert "health-alert $STS_NAME: health = $health , resumed healthy operation"
    fi
    return
}

function watcher {
    echo "# ===== $cmd ====="
    rotate_log "$csvfile"
    oldrole=$(kubectl get pod/$MY_POD_NAME -o jsonpath='{.metadata.labels.tib-msg-stsrole}' )
    log "INFO: Initial role is $oldrole"
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
        if [ "$leader" = "$MY_POD_NAME" ] ; then 
            role=leader
        else 
            role=standby
        fi
        if [ -n "$oldrole" ] && [ "$role" != "$oldrole" ] ; then
            log "INFO: updating role to $role"
            spec=$(printf '{"metadata":{"labels":{"tib-msg-stsrole":"%s"}}}' "$role" )
            echo "#+: " kubectl patch pod/$MY_POD_NAME --type=merge -p="$spec"
            kubectl patch pod/$MY_POD_NAME --type=merge -p="$spec"
            [ $? -eq 0 ] && oldrole="$role"
        fi
    
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
    [ "$hstatus" != 'deployed' ] && alert "$STS_NAME Error: upgrade did not complete successfully, aborting" && return 1
    log "INFO: helm upgrade Complete."
}

function redeploy {
    log "#===== WAITING ON RELEASE ====="
    wait_for_release
    log "#===== REDEPLOY STARTING ====="
    sts_get_config
    sts_check_health 
    [ "$health" != 'great' ] && alert "Warning: STS=$STS_NAME not healthy - aborting ($missingList)." && return 1
    upgLeader="$leader"
    [ -z "$upgLeader" ] && [ "$quorumStrategy" = "quorum-based" ] && \
            alert "Warning: No leader for $STS_NAME - aborting upgrade ($missingList)." && return 1
    podList=()
    for r in $(seq 0 $maxReplica ) ; do
        podname="$STS_NAME-$r"
        [ "$podname" = "$upgLeader" ] && log "INFO: Saving leader $podname - for last" && continue 
        podList+="$podname "
    done
    [ -n "$upgLeader" ] && podList+="$upgLeader "
    for xpod in ${podList[*]} ; do
        startTime=$(date +%s )
        log "Deleting pod=$xpod"
        kubectl delete pod "$xpod"
        health=upgrade
        # Wait for healthy
        for try in $(seq 600 ) ; do
            [ "$health" = 'great' ] && break
            sleep 5 
            sts_check_health
            log  "$dtime,$health,$leader,$inQuorumCount,$missingList" 
        done
        endTime=$(date +%s )
        deltaTime=$(( $endTime - $startTime ))
        [ "$health" != 'great' ] && alert "$STS_NAME: did not recover health ($deltaTime), aborting" && return 1
        log "Rejoined pod=$xpod ($deltaTime s)"
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
