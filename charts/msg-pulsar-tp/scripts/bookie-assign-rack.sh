#!/bin/bash
#!/bin/bash

#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
USAGE=" $cmd -- use kubectl + pulsar-admin to get and set rackid
Required ENV Items:
  BOOKIE_ID : ZK registered id (eg. <pod-fqdn:bookie-port> )
  BOOKIE_GROUP : pulsar-broker group (eg. \$PULSAR_CLUSTER )
Requires correctly configured client.conf file (ala toolset)
.. Refreshes node-info to /pulsar/data/node-info.txt
.. Uses rack={.metadata.labels.failure-domain\.beta\.kubernetes\.io/zone}
"


nodeInfo=/pulsar/logs/bookie-rack/node-info.txt
fmtTime="--rfc-3339=ns"
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

function reportWaiting {
    export reportNext reportInterval reportNow
    reportNow=$(date "+%s")
    [ -z "$reportInterval" ] && reportInterval=30
    [ -z "$reportNext" ] && reportNext=0
    if [ "$reportNow" -gt "$reportNext" ] ; then
        reportNext=$(( $reportNow + $reportInterval ))
        log "$*"
    fi
}

function waitForPid {
    cmdRegex=${1:?"ps grep expression required."}
    while true ; do 
        pid="$( ps -ef | egrep "$cmdRegex" | grep -v grep | head -1 | tr -s ' ' | cut -f2 -d' ')"
        [ -n "$pid" ] && echo "$pid" && return 0
        reportWaiting "Waiting on $cmdRegex pid ..."
        sleep 2
        # ps -ef | grep org.apache.bookkeeper.server.Main | grep -v grep | head -1 | tr -s ' ' | cut -f2 -d' '
    done
}

function refreshNodeZones {
    outfile=$nodeInfo
    outtmp="$outfile.tmp.$RANDOM"
    kubectl get nodes  | egrep -v NAME | while read node other ; do 
        info="$(kubectl get node "$node"  -o jsonpath='{.metadata.name} {.metadata.labels.failure-domain\.beta\.kubernetes\.io/zone}' )"
        echo "$info"
    done >> $outtmp
    mv $outtmp $outfile
    echo ".. Updated zone info for $(wc -l $outfile) nodes to: $outfile"
}

function waitForKnownBookie
{
    bookieName="${1:?"Bookie ID is required."}"
    while true ; do 
        if pulsar-admin bookies list-bookies | egrep -q "$bookieName" ; then
            echo ".. Bookie=$bookieName is registered"
            break
        fi
        reportWaiting "Waiting on bookie $bookieName - to be known ..."
        sleep 2
    done
}

# WAIT on BOOKIE RUNNING
# ps -ef | grep org.apache.bookkeeper.server.Main | grep -v grep | head -1 | tr -s ' ' | cut -f2 -d' '
bookiePid="$(waitForPid org.apache.bookkeeper.server.Main)"
echo ".. Bookie Pid=$bookiePid ( $(date) )"

if [ "$DP_HAS_CLUSTER_ROLE" = "false" ] ; then
    log "WARNING: No Cluster Role available. Bookie node zone-base assignment will not be possible."
    log "CAUTION: Bookie groups > 3 pods require external rack assignment for production quality data placement."
else
    # GET BOOKIE ZONE / RACK ID
    bookieZone="$(egrep "^$MY_NODE_NAME " $nodeInfo | cut -d' ' -f2)"
    bookieID="$(eval echo "$BOOKIE_ID")"
    # REFRESH NODE-ZONE info if missing
    [ -z "$bookieZone" ] && refreshNodeZones && bookieZone="$(egrep "^$MY_NODE_NAME " $nodeInfo | cut -d' ' -f2)"
    echo "Bookie=$bookieID , Pod=$MY_POD_NAME, Zone=$bookieZone"

    # WAIT ON BOOKIE to be Registered
    waitForKnownBookie $bookieID

    # SET BOOKIE RACK
    while true ; do 
        pulsar-admin bookies set-bookie-rack --bookie "$bookieID" \
                                            --hostname "$bookieID" \
                                            --group "$BOOKIE_GROUP" \
                                            --rack "$bookieZone"
        [ $? -eq 0 ] && echo ".. set group/rack : $BOOKIE_GROUP/$bookieZone" && break
        reportWaiting "Waiting on successful set-bookie-rack : $MY_POD_NAME, $bookieZone"
        sleep 5
    done

    # REPORT UPDATED RACK PLACEMENTS
    date
    pulsar-admin bookies racks-placement
fi

# WAIT on BOOKIE EXIT
echo ".. Waiting on shutdown of : $bookiePid"
tail --pid "$bookiePid" -f /dev/null
exit 0
