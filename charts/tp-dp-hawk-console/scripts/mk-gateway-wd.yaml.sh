#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export MY_POD_NAME="${MY_POD_NAME:-$(hostname)}"
outfile=${1:-gateway.wd.yaml}
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
      cwd: /logs/jwks
      log:
        size: 10
        num: 10
        rotateonfirststart: true
  - name: emslogger
    config:
      cmd: bash /logs/boot/start-logger.sh
      cwd: /logs/emslogger
      log:
        size: 10
        num: 5
        rotateonfirststart: true
        debugfile: /logs/emslogger/emslogger.log
  - name: tibrvmon
    config:
      cmd: bash /logs/boot/start-tibrvmon.sh
      cwd: /logs/tibrvmon
      log:
        size: 10
        num: 5
        rotateonfirststart: true
  - name: pod-stats
    config:
      cmd: bash /logs/boot/pod-stats.sh
      cwd: /logs/pod-stats
      log:
        size: 10
        num: 50
        debugfile: /logs/pod-stats/pod-mon.csv
        rotateonfirststart: true
  - name: fluentbit
    config:
      cmd: /opt/fluent-bit/bin/fluent-bit -c /logs/boot/fluent-bit.conf
      cwd: /logs/boot
      logger: stdout
      log:
        size: 200
        num: 25
        rotateonfirststart: true
EOF
