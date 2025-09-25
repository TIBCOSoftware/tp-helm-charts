#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export MY_POD_NAME="${MY_POD_NAME:-$(hostname)}"
outfile=${1:-watchdog.yml}
cat - <<EOF > $outfile
services:
  - name: ftl
    config:
      cmd: tibftlserver -n ${MY_POD_NAME} -c /data/boot/ftlserver.yml
      # cmd: wait-for-shutdown.sh
      cwd: /logs/${MY_POD_NAME}
      log:
        size: 200
        num: 50
        # debugfile: /logs/${MY_POD_NAME}/ftlserver.log
        rotateonfirststart: true
  - name: pod-stats
    config:
      cmd: bash /boot/pod-stats.sh
      cwd: /logs/${MY_POD_NAME}/pod-stats
      log:
        size: 10
        num: 50
        debugfile: /logs/${MY_POD_NAME}/pod-stats/pod-mon.csv
        rotateonfirststart: true
  - name: health-watcher
    config:
      cmd: bash /boot/health-watcher.sh
      cwd: /logs/${MY_POD_NAME}/health-watcher
      log:
        size: 10
        num: 50
        debugfile: /logs/${MY_POD_NAME}/health-watcher/health.csv
        rotateonfirststart: true
  - name: fluentbit
    config:
      cmd: /opt/fluent-bit/bin/fluent-bit -c /data/boot/fluentbit.conf
      cwd: /logs/${MY_POD_NAME}/fluentbits
      logger: stdout
      log:
        size: 200
        num: 25
        rotateonfirststart: true
EOF
