#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export MY_POD_NAME="${MY_POD_NAME:-$(hostname)}"
outfile=${1:-zk-watchdog.yml}
cat - <<EOF > $outfile
services:
  - name: main
    config:
      cmd: ${WATCHDOG_MAIN} ${WATCHDOG_MAIN_ARGS}
      # cmd: /usr/local/watchdog/bin/wait-for-shutdown.sh
      cwd: /pulsar/logs
      log:
        size: 200
        num: 30
        rotateonfirststart: true
  - name: zk-health
    # ADD ZK-status.sh, which also starts /usr/local/watchdog/bin/dp-health-shim 
    config:
      cmd: bash /boot/zk-health.sh
      cwd: /pulsar/logs/zk-health
      log:
        size: 10
        num: 30
        # debugfile: /pulsar/logs/pod-stats/pod-mon.csv
        rotateonfirststart: true
  - name: pod-stats
    config:
      cmd: bash /boot/pod-stats.sh
      cwd: /pulsar/logs/pod-stats
      log:
        size: 10
        num: 30
        debugfile: /pulsar/logs/pod-stats/pod-mon.csv
        rotateonfirststart: true
  - name: health-watcher
    config:
      cmd: bash /boot/health-watcher.sh
      cwd: /pulsar/logs/health-watcher
      log:
        size: 10
        num: 30
        debugfile: /pulsar/logs/health-watcher/health.csv
        rotateonfirststart: true
  - name: fluentbit
    config:
      cmd: /opt/fluent-bit/bin/fluent-bit -c ./fluentbit.conf
      cwd: /pulsar/logs/fluentbits
      logger: stdout
      log:
        size: 10
        num: 30
        rotateonfirststart: true
EOF
