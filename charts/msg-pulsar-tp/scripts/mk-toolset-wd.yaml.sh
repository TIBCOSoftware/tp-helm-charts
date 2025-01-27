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
      ctl: /pulsar/logs
      log:
        size: 200
        num: 50
        rotateonfirststart: true
  - name: pod-stats
    config:
      cmd: bash /boot/pod-stats.sh
      cwd: /pulsar/logs/pod-stats
      log:
        size: 10
        num: 50
        debugfile: /pulsar/logs/pod-stats/pod-mon.csv
        rotateonfirststart: true
EOF
