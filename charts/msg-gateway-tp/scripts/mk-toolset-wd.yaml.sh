#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export MY_POD_NAME="${MY_POD_NAME:-$(hostname)}"
outfile=${1:-toolset.wd.yaml}
cat - <<EOF > $outfile
services:
  - name: main
    config:
      cmd: /app/cloudshell
      # cmd: wait-for-shutdown.sh
      cwd: /app
      ctl: /logs
      log:
        size: 200
        num: 50
        rotateonfirststart: true
  - name: tibemsrestd
    config:
      cmd: bash /logs/boot/start-multi-restd.sh
      cwd: ${EMS_RESTD_DIR}
      log:
        size: 10
        num: 50
        debugfile: ${EMS_RESTD_DIR}/register-debug.log
        rotateonfirststart: true
  - name: gateway-refresh
    config:
      cmd: bash /logs/boot/gateway-refresh.sh
      cwd: /logs/gateway-refresh
      log:
        size: 10
        num: 10
EOF
