#!/bin/bash

#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

function createOldCredentials {
    _creds=${1:?filename-required.}
    echo "=== Retrying with old style credentials - for legacy installs"
    cat $EMS_DP_CREDENTIALS | egrep -v view > $_creds
    cat $EMS_DP_CREDENTIALS | egrep admin | sed -e 's/admin/view/' >> $_creds
}

# export TIBEMS_OAUTH2_ACCESS_TOKEN=$MSG_ADMIN_BEARER
# expect initially MSG_CLI_APPNAME=ems-ct
export cliDir="/logs/cli/$RANDOM"
checkAuth=$(/app/ems-registration check-dp-admin 2>&1)
rtc=$?
[ $rtc -ne 0 ] && echo "Manage Dataplane permission required, exiting." && exit $rtc
mkdir -p $cliDir && pushd $cliDir
if [[ "$MSG_CLI_APPNAME" =~ ^ems ]]; then
    echo "Using app = $MSG_CLI_APPNAME"
    /app/ems-registration tibemsadmin "$MSG_CLI_RIID"
    if [ $? -ne 0 ] ; then
        # RETRY in case this is a pre 1.21.0 EMS instance without a viewUser
        createOldCredentials tmp.credentials.yaml
        EMS_DP_CREDENTIALS="$PWD/tmp.credentials.yaml" /app/ems-registration tibemsadmin "$MSG_CLI_RIID"
        # rm -f tmp.credentials.yaml
    fi
elif [[ "$MSG_CLI_APPNAME" =~ ^as ]]; then
    echo "Using app = $MSG_CLI_APPNAME"
    /app/ems-registration tibdg "$MSG_CLI_RIID"
elif [[ "$MSG_CLI_APPNAME" =~ ^support ]]; then
    if [[ "$DP_SUPPORT_SHELL_ENABLED" =~ ^[FfNn0] ]]; then
        echo "Support shell has been disabled, exiting."
        exit 0
    fi
    echo "Using app = $MSG_CLI_APPNAME"
    bash
else
    echo "Unknown app = $MSG_CLI_APPNAME"
fi
rm -rf $cliDir
