#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

function wait_for_url()  {
    url=$1
    while [[ "$(curl -k -s -o /dev/null -w '%{http_code}' $url )" != "200" ]]; do echo -n "." ; sleep 5 ; done ;
}

function wait_for_active {
    for try in $(seq 300) ; do
        kubectl get pods -n=$MY_NAMESPACE -l=tib-msg-stsname=$EMS_SERVICE,tib-msg-stsrole=leader | egrep $EMS_SERVICE  && break
        echo -n "."
        sleep 3
    done
}
function get_leader_pod {
    leader_pod=$(kubectl get pods -n=$MY_NAMESPACE -l=tib-msg-stsname=$EMS_SERVICE,tib-msg-stsrole=leader -o jsonpath="{.items[0].metadata.name}" 2>/dev/null )
    rtc=$?
    echo $leader_pod
    return $rtc
}

outfile=${1:-tibemsd-ftl.json}
ftlport="443"
emsport="9010"
initDir="${EMS_INIT_DIR:-/data}"
initTibemsdJson="${EMS_INIT_JSON:-$initDir/boot/tibemsd-ftl.json}"
loadedTibemsdJson="$initDir/tibemsd-ftl.json.loaded"

echo "Waiting for FTL-Server Quorum ... "
wait_for_url "$FTL_REALM_URL/api/v1/available"

leader=$(get_leader_pod) || echo "No leader, initializing configuration ... "
if [ -n "$leader" ] ; then
    echo "Found leader=$leader, upgrading ..."
    # UPGRADING
    echo "Upgrading pods ..." ; 
    kubectl get pods -l=tib-msg-stsname=${STS_NAME} | egrep -v NAME | while read x o ; do 
      echo "POD=$x"; done ; 
    bash < /boot/health-watcher.sh ;
    rtc=$?
else
    # INITIALIZING
    echo "Loading initial tibemsd.json ..."
    export LD_LIBRARY_PATH="/opt/tibco/ftl/current-version/lib:$LD_LIBRARY_PATH"
    rtc=1
    for try in $(seq 30) ; do
        tibemsjson2ftl -url "$FTL_REALM_URL" -json $initTibemsdJson
        rtc=$?
        [ $rtc -eq 0 ] && mv $initTibemsdJson $loadedTibemsdJson && break
        echo -n "."
        sleep 3
    done

    echo "Waiting for EMS-Active Service ... "
    wait_for_active
    sleep 2  ; # wait DNS resolver
    
    # Set Password for GEMS user
    bash < /boot/k8DpadminSetup.sh
    rtc=$?
fi

exit $rtc
