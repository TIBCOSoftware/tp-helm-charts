#!/bin/bash

#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

base="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
cmd="${0##*/}"
usage="$cmd  -- configure K8 EMS server gems users"

tmpdir=/logs/tmp/ems-reg
rm -rf $tmpdir
mkdir -p $tmpdir
cd $tmpdir
export EMS_REG_USER=${EMS_REG_USER:-admin}
export EMS_REG_PASS=${EMS_REG_PASS:-""}
export EMS_RESTD_DIR=$tmpdir
export EMS_CERT_DIR=
export MSG_DP_TYPE=k8s

cat - <<! > $tmpdir/reg.yaml
groupName: $EMS_CAP_NAME
groupType: ems
dataplaneId: $MY_DATAPLANE_ID
resourceInstanceId: $MY_INSTANCE_ID
registrationUser: "$EMS_REG_USER"
registrationPass: "$EMS_REG_PASS"
clientUrl: "$EMS_PODS_URL"
monitorUrl: "$EMS_PODS_MONURL"
!
# TODO: MSGDP-2378: Remove audit copy before release
cat $tmpdir/reg.yaml  | sed -e 's;^registrationPass:.*;registrationPass: XXXX;' > $tmpdir/../audit.reg.yaml

echo >&2 "#+: Setting / Updating Gems permissions"
ems-registration register -spec reg.yaml
rtc=$?
rm -rf $tmpdir
exit $rtc
