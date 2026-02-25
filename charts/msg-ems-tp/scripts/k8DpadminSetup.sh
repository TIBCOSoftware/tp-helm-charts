#!/bin/bash

#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="$cmd [ems-admin-url|$EMS_ADMIN_URL] -- setup K8 EMS server DP admin user"
EMS_ACTIVE_URL="${1:-$EMS_ACTIVE_URL}"
[ -z "$EMS_ACTIVE_URL" ] && echo "Usage(url): $usage" && exit 1
[ -z "$DP_ADMIN_USER" ] && echo "Usage(user): $usage" && exit 1
tibemsadmin=/opt/tibco/ems/current-version/bin/tibemsadmin
export LD_LIBRARY_PATH=/opt/tibco/ems/current-version/lib:/opt/tibco/ftl/current-version/lib
cmdFile="./up.$$.emscmd"

echo >&2 "#+: Setting up msg-gems-admin permissions"
echo "set password $DP_ADMIN_USER $DP_ADMIN_PASSWORD" > $cmdFile
$tibemsadmin -server $EMS_ACTIVE_URL -script $cmdFile |
    sed -e "s;$DP_ADMIN_PASSWORD;xxxx;g" 
rtc=$?
rm -f $cmdFile
exit 0
