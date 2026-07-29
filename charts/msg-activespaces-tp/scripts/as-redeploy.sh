#!/bin/bash 

#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#
base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"  

asDebug=y
tmpCoreLeader="/tmp/as.core.leader"
tmpPrimaries="/tmp/as.primaries"
tmpStatus="/tmp/as.status"
tmpMissing="/tmp/as.missing"
function asStatus() {
    > $tmpCoreLeader
    > $tmpPrimaries
    > $tmpMissing
    mapfile -t connectArgs  < /conf/as.*.args
    tibdg "${connectArgs[@]}" status > $tmpStatus
    [ $? -ne 0 ] && echo >&2 "Failed to get ActiveSpaces status" && return 1
    return 0
}

function asAllHealthy() {
    export primaryHosts="" coreHost=""
    asStatus || return 1
    for comp in "core" "node" "proxy" ; do 
        grep " $comp " $tmpStatus | tr '!' ' ' | while read line ; do 
            read -r -a fields <<< "$line"
            if [ "${fields[5]}" != "Running" ] ; then
                echo "${fields[0]}.${fields[1]}.${fields[2]}" >> $tmpMissing
                [ "$asDebug" == "y" ] && echo >&2 "$comp ${fields[1]} is not running (${fields[2]})"
            else
                [ "$asDebug" == "y" ] && echo >&2 "$comp ${fields[1]} is running (${fields[5]})"
            fi
        done
        cat $tmpStatus | grep ' keeper ' | grep ' leader ' > $tmpCoreLeader
        cat $tmpStatus | grep ' node ' | grep ' primary ' > $tmpPrimaries
    done
    [ $(wc -l < $tmpMissing ) -gt 0 ] && echo "Missing $(sort -u $tmpMissing | paste -sd " ")" && return 1
    [ $(wc -l < $tmpCoreLeader ) -ne 1 ] && echo "Expected exactly 1 core leader, found: $(cat $tmpCoreLeader)" && return 1
    [ $(wc -l < $tmpPrimaries ) -ne $numCopysets ] && echo "Expected $numCopysets primaries, found: $(wc -l < $tmpPrimaries)" && return 1
    primaryHosts="$( cat $tmpPrimaries | tr -s ' ' | cut -d' ' -f4 )"
    coreHost="$( cat $tmpCoreLeader | tr -s ' ' | cut -d' ' -f4 )"
    [ "$asDebug" == "y" ] && echo >&2 "CoreLeader: $coreHost, Primaries: $primaryHosts"
    return 0
}

function waitForASHealthy() {
    tries=600
    asDebug=""
    echo "... Waiting for ActiveSpaces to be healthy ..."
    allDone=
    for try in $(seq 1 $tries) ; do
        asAllHealthy && allDone=y && break
        # mv $tmpStatus /tmp/as.status.$try
        echo  "..."
        sleep ${AS_HEALTH_WAIT_INTERVAL:-2}
    done
    [ -z "$allDone" ] && echo >&2 "ActiveSpaces is not healthy after $tries tries" && return 1
    echo "ActiveSpaces is healthy"
    return 0
}

function asCompactRedeploy() {
    echo "Redeploying ActiveSpaces compact configuration"
    waitForASHealthy || return 1
    saveCore="" savePrimary=""
    for replica in 0 1 2 ; do
        pod="$groupName-core-$replica"
        [ "$pod" = "$primaryHosts" ] && savePrimary="$pod" && echo "Saving primary node $pod for last" && continue
        [ "$pod" = "$coreHost" ] && saveCore="$pod" && echo "Saving core leader $pod for later" && continue
        kubectl delete pod $pod 
        waitForASHealthy || return 1
    done
    if [ "$saveCore" != "" ] ; then
        kubectl delete pod $saveCore
        waitForASHealthy || return 1
    fi
    if [ "$savePrimary" != "" ] ; then
        kubectl delete pod $savePrimary
        waitForASHealthy || return 1
    fi
    return 0
}

function asCoreRedeploy() {
    echo "Redeploying core ... "
    waitForASHealthy || return 1
    saveCore=""
    for replica in 0 1 2 ; do
        pod="$groupName-core-$replica"
        [ "$pod" = "$coreHost" ] && saveCore="$pod" && echo "Saving core leader $pod for later" && continue
        kubectl delete pod $pod 
        waitForASHealthy || return 1
    done
    kubectl delete pod $saveCore
    waitForASHealthy || return 1
    return 0
}

function asProxyRedeploy() {
    echo "Redeploying proxies ... "
    waitForASHealthy || return 1
    for replica in $(seq 0 $(( $numProxies - 1 )) ) ; do
        pod="$groupName-proxy-$replica"
        kubectl delete pod $pod 
        waitForASHealthy || return 1
    done
    return 0
}

function asCopysetRedeploy() {
    echo "Redeploying copysets ... "
    waitForASHealthy || return 1
    primaries="$( cat $tmpStatus | grep ' node ' | grep ' primary ' | tr -s ' ' | cut -d' ' -f3 | paste -sd " " )"
    secondaries="$( cat $tmpStatus | grep ' node ' | grep -v ' primary ' | tr -s ' ' | cut -d' ' -f3 | paste -sd " " )"
    echo "... restarting node secondaries: $secondaries ..."
    for pod in $secondaries ; do
        kubectl delete pod $pod 
        waitForASHealthy || return 1
    done
    echo "... restarting node primaries: $primaries ..."
    for pod in $primaries ; do
        kubectl delete pod $pod 
        waitForASHealthy || return 1
    done
    return 0
}

function asRedeploy() {
    if [ "$useCompact" == "true" ] ; then
        asCompactRedeploy || ( echo >&2 "Failed to complete redeploy" && return 1 )
    else
        asCoreRedeploy || ( echo >&2 "Failed to finish core redeploy" && return 1 )
        asProxyRedeploy || ( echo >&2 "Failed to finish proxy redeploy" && return 1 )
        asCopysetRedeploy || ( echo >&2 "Failed to finish copyset redeploy" && return 1 )
    fi
}
