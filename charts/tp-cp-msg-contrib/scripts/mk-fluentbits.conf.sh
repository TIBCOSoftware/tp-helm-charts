#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-fluentbit.conf}
cat - <<EOF > $outfile
[SERVICE]
    # Flush
    # =====
    # Set an interval of seconds before to flush records to a destination
    Flush        5

    # Daemon
    # ======
    # Instruct Fluent Bit to run in foreground or background mode.
    Daemon       Off

    # Log_Level
    # =========
    # Set the verbosity level of the service, values can be:
    #
    # - error
    # - warning
    # - info
    # - debug
    # - trace
    #
    # By default 'info' is set, that means it includes 'error' and 'warning'.
    Log_Level    info

    # Parsers_File
    # ============
    # Specify an optional 'Parsers' configuration file
    Parsers_File /data/boot/parsers.conf

    # HTTP Server
    # ===========
    # Enable/Disable the built-in HTTP Server for metrics
    #HTTP_Server  On
    #HTTP_Listen  0.0.0.0
    #HTTP_Port    ${TCM_LOGGER_PORT}

[INPUT]
    Name http
    listen 127.0.0.1
    port ${LOG_ALERT_PORT}
    Tag dp.routable
[INPUT]
    Name tail
    Alias srv.stdout
    Tag dp.routable
    Path /logs/msg-webserver/webserver.log
    Key message
    Mem_Buf_Limit 1M
    Parser msg-parser
[INPUT]
    Name tail
    Alias srv.stdout
    Tag dp.routable.watchdog
    Path /logs/msg-webserver/watchdog.log
    Key message
    Mem_Buf_Limit 1M
    Parser watchdog-parser

@INCLUDE /data/boot/output.conf
@INCLUDE common.conf
EOF
