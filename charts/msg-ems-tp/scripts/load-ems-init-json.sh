#!/bin/bash
#
# Copyright (c) 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained 
# in the license file that is distributed with this file.  
#

function wait_for_url()  {
    url=$1
    while [[ "$(curl -k -s -o /dev/null -w '%{http_code}' $url )" != "200" ]]; do echo -n "." ; sleep 5 ; done ;
}

outfile=${1:-tibemsd-ftl.json}
ftlport="443"
emsport="9010"
initDir="${EMS_INIT_DIR:-/logs/$MY_POD_NAME}"
initTibemsdJson="${EMS_INIT_JSON:-$initDir/boot/tibemsd-ftl.json}"

echo "Waiting for FTL-Server Quorum ... "
wait_for_url "$FTL_REALM_URL/api/v1/available"

echo "Loading initial tibemsd.json ..."
rtc=1
export LD_LIBRARY_PATH="/opt/tibco/ftl/current-version/lib:$LD_LIBRARY_PATH"
for try in $(seq 5) ; do
    tibemsjson2ftl -url "$FTL_REALM_URL" -json $initTibemsdJson
    rtc=$?
    [ $rtc -eq 0 ] && break
    echo -n "."
    sleep 3
done

exit $rtc
