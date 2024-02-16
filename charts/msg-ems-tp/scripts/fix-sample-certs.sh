#!/bin/bash
#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

function wait_for_url()  {
    url=$1
    while [[ "$(curl -k -s -o /dev/null -w '%{http_code}' $url )" != "200" ]]; do echo -n "." ; sleep 5 ; done ;
}

ftlport="443"
emsport="9010"
initDir="${EMS_INIT_DIR:-/data}"
initTibemsdJson="${EMS_INIT_JSON:-$initDir/boot/check-tibemsd-ftl.json}"
mkdir -p $initDir/boot

echo "Waiting for FTL-Server Quorum ... "
wait_for_url "$FTL_REALM_URL/api/v1/available"

echo "Checking for 1.0.1 sample certs ..."
rtc=1
export LD_LIBRARY_PATH="/opt/tibco/ftl/current-version/lib:$LD_LIBRARY_PATH"
for try in $(seq 5) ; do
    tibemsjson2ftl -url "$FTL_REALM_URL" -json $initTibemsdJson -download
    rtc=$?
    [ $rtc -eq 0 ] && break
    echo -n "."
    sleep 3
done
if egrep -q "certs/samples" $initTibemsdJson ; then
    echo "Fixing sample certs ..."
    mkdir -p /logs/${MY_POD_NAME}/certs/samples 
    cd /logs/${MY_POD_NAME}/certs/samples  
    for x in server.cert.pem server_root.cert.pem server.key.pem ; do 
        cp /opt/tibco/ems/current-version/samples/certs/$x $x 
        [ $? -ne 0 ] && rtc=1
    done
fi

exit $rtc
