#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="
$cmd -- Periodically update gateway DP status info
"

# TODO: Add stale ops-shell cli subdir cleanup to Gateway refresh script

fmtTime="--rfc-3339=ns"
LOG_CLEANUP_DAYS="${LOG_CLEANUP_DAYS:-7}"
freqLogCleanup="${LOG_CLEANUP_INTERVAL:-86400}"
freqASwatch="${AS_WATCH_INTERVAL:-10}"
export iter=0


# Set signal traps
function log
{ echo "$(date "$fmtTime"): $*" ; }

function do_shutdown
{ log "-- Shutdown received (SIGTERM): host=$HOSTNAME" && exit 0 ; }
trap do_shutdown SIGINT
trap do_shutdown SIGTERM

# Add AS Registration watcher support
asList=./as-list.out
> $asList
asConfDir=/data/as-conf
function refreshAS {
    # Refresh K8DP AS Registration information
    kubectl get secret -l=app.kubernetes.io/component=msg-activespaces \
            | egrep -v NAME | cut -d' ' -f1 | sort > $asList
    count=$(wc -l < $asList)
    [ ! -d "$asConfDir" ] && [ "$count" -eq 0 ] && return 0
    rm -rf $asConfDir.tmp 
    mkdir -p $asConfDir
    mkdir -p $asConfDir.tmp
    cat $asList | while read conf ; do
        echo "... Downloading AS config from $conf"
        kubectl get -o yaml secret $conf | yq '.data' | while read line ; do
            key=$(echo $line | cut -d':' -f1)
            val=$(echo $line | cut -d':' -f2 | tr -d ' ')
            echo "$val" | base64 --decode > $asConfDir.tmp/$key
        done 
        # useful once -c <confjson> really works, but ...
        echo "... Update \$AS_DATA_DIR paths"
        for x in $asConfDir.tmp/*.args $asConfDir.tmp/*.conf.json ; do
            [ ! -f "$x" ] && continue      ; # No files matched glob
            sed -i "s;/conf/;$AS_DATA_DIR/;g" $x
        done
    done
    diff -s -r $asConfDir.tmp/ $asConfDir/ > /dev/null 2>&1
    if [ $? -ne 0 ] ; then
        echo "... AS config changed, updating $asConfDir"
        mv $asConfDir $asConfDir.del
        mv $asConfDir.tmp $asConfDir
        rm -rf $asConfDir.del
    else
        echo "... AS config unchanged, skipping update"
        rm -rf $asConfDir.tmp
    fi
}

echo "# ===== $cmd ====="
echo "#+: Watching for gateway sync events ..."
while true
do
    # JWKS refresh and RESTD refresh + restart moved to cloudshell

    if [ 0 -eq $(( $iter % $freqASwatch )) ] ; then
        echo "#+: Refreshing AS Registration information ..."
        refreshAS
    fi

    if [ 0 -eq $(( $iter % $freqLogCleanup )) ] ; then
        echo >&2 "#+: Removing stale log rotations older than $LOG_CLEANUP_DAYS days"
        find /logs -type f -name '*.log.*' -mtime +$LOG_CLEANUP_DAYS -delete
    fi

    sleep 1
    iter=$((iter + 1))
done
