#!/bin/bash

#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export TIBEMS_LICENSE
if  [ -z "$TIBEMS_LICENSE" ]; then
  licenseSize=$( cat /boot-activation/license-file.bin 2>/dev/null | wc -c )
  if [ "$licenseSize" -gt 0 ] ; then
    export TIBEMS_LICENSE="file:///boot-activation/license-file.bin"
  else
    export TIBEMS_LICENSE="https://tib-activate:7070"
  fi
fi
[ -z "$TIBFTL_LICENSE" ] && TIBFTL_LICENSE="$TIBEMS_LICENSE"

tibftlserver -n ${MY_POD_NAME} -c /data/boot/ftlserver.yml
