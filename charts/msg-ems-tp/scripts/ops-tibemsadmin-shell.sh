#!/bin/bash

#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export TIBEMS_OAUTH2_ACCESS_TOKEN=$MSG_ADMIN_BEARER
emsactive=$(echo "$EMS_TCP_URL" | cut -d',' -f1)
/opt/tibco/ems/current-version/bin/tibemsadmin -server "$emsactive"
