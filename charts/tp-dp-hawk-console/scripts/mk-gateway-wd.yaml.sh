#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export MY_POD_NAME="${MY_POD_NAME:-$(hostname)}"
outfile=${1:-gateway.wd.yaml}
cat - <<EOF > $outfile
services:
  - name: gateway
    config:
      cmd: /app/cloudshell
      # cmd: wait-for-shutdown.sh
      cwd: /app
      ctl: /logs
      log:
        size: 10
        num: 10
        rotateonfirststart: true
  - name: restd
    config:
      cmd: bash /logs/boot/start-multi-restd.sh
      cwd: ${EMS_RESTD_DIR}
      log:
        size: 2
        num: 20
        debugfile: ${EMS_RESTD_DIR}/register-debug.log
        rotateonfirststart: true
  - name: gateway-refresh
    config:
      cmd: bash /logs/boot/gateway-refresh.sh
      env:
        LOG_CLEANUP_DAYS: "14"
      cwd: /logs/jwks
      log:
        size: 1
        num: 7
        rotateonfirststart: true
  - name: emslogger
    config:
      cmd: bash /logs/boot/start-logger.sh
      cwd: /logs/emslogger
      log:
        size: 10
        num: 7
        rotateonfirststart: true
        debugfile: /logs/emslogger/emslogger.log
  - name: pod-stats
    config:
      cmd: bash /logs/boot/pod-stats.sh
      cwd: /logs/pod-stats
      log:
        size: 2
        num: 14
        debugfile: /logs/pod-stats/pod-mon.csv
        rotateonfirststart: true
  - name: fluentbit
    config:
      cmd: /opt/fluent-bit/bin/fluent-bit -c /logs/boot/fluent-bit.conf
      cwd: /logs/fluent-bit
      log:
        size: 10
        num: 10
        rotateonfirststart: true
EOF
