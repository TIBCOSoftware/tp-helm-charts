#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-fluent-bit.conf}
cat - <<EOF > $outfile
[SERVICE]
    Flush        1
    Log_Level    debug
    Daemon       Off
    Parsers_File parsers.conf

[INPUT]
    Name tail
    Parser json_parser
    Path        /logs/emslogger/emslogger.log 
    Path_Key    filename
    Tag         ems.logs

[FILTER]
    Name    lua
    Match   ems.logs
    Script  transform_ems_to_otel.lua
    Call    transform_ems_to_otel

[OUTPUT]
    Name                 opentelemetry
    Match                ems.logs
    Host                 otel-userapp.${MY_NAMESPACE}.svc.cluster.local
    Port                 4318
    Logs_uri             /v1/logs
    Log_response_payload True
    Tls                  Off
    Tls.verify           Off
EOF
