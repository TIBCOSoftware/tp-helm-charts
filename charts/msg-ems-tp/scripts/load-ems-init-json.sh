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

function wait_for_active {
    for try in $(seq 300) ; do
        kubectl get pods -n=$MY_NAMESPACE -l=tib-msg-stsname=$EMS_SERVICE,tib-msg-stsrole=leader | egrep $EMS_SERVICE  && break
        echo -n "."
        sleep 3
    done
}

outfile=${1:-tibemsd-ftl.json}
ftlport="443"
emsport="9010"
initDir="${EMS_INIT_DIR:-/data}"
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

echo "Waiting for EMS-Active Service ... "
wait_for_active
# 1.3.0 tibadmin init: Use admin user to fix tibadmin users
emsData='{"name": "tibadmin", "description": "msgdp-update", "password": "'"$EMS_ADMIN_PASSWORD"'" }' || true
export EMS_ADMIN_USER=""
export EMS_ADMIN_PASSWORD=""
/boot/emsadmin-curl.sh -a /users/tibadmin -X POST \
   --data "$emsData" || true
cat curl.debug

exit $rtc
