#!/bin/bash

#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

# export TIBEMS_OAUTH2_ACCESS_TOKEN=$MSG_ADMIN_BEARER
# expect initially MSG_CLI_APPNAME=ems-ct
export cliDir="/logs/cli/$RANDOM"
checkAuth=$(/logs/boot/ems-registration.sh checkHasDPAdmin)
rtc=$?
[ $rtc -ne 0 ] && echo "Manage Dataplane permission required, exiting." && exit $rtc
mkdir -p $cliDir && pushd $cliDir
/logs/boot/ems-registration.sh mainCliEmsAdmin
rm -rf $cliDir
