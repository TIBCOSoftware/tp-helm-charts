#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

export MY_POD_NAME="${MY_POD_NAME:-$(hostname)}"
outfile=${1:-watchdog.yml}
cat - <<EOF > $outfile
services:
  - name: msg-gems
    config:
      cmd: /contributions/gems/gems
      cwd: /contributions/gems/
      ctl: /logs/msg-webserver/
      log:
        file: /logs/msg-webserver/webserver.log
        size: 200
        num: 50
        rotateonfirststart: true
  - name: fluentbit
    config:
      cmd: /opt/fluent-bit/bin/fluent-bit -c /data/boot/fluentbit.conf
      # cmd: /opt/td-agent-bit/bin/td-agent-bit -c /data/fluentbit.conf
      # cwd must be unique for each service when using shared volumes
      # because services generate lots of metadata (lock files, pid files)
      cwd: /logs/msg-webserver/fluentbits
      logger: stdout
      log:
        size: 200
        num: 25
        rotateonfirststart: true
EOF
