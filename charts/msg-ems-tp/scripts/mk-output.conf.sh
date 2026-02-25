#!/bin/bash
#
# Copyright (c) 2023-2026. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-output.conf}

cat - <<EOF > $outfile
[OUTPUT]
    Name stdout
    Match dp.routable*
    format json_lines
EOF

# Append opentelemetry output if Fluent Bit is enabled
if [ "$DP_LOGGING_FLUENTBIT_ENABLED" = "true" ] ; then
    cat - <<EOF >> $outfile
[OUTPUT]
    Name                 opentelemetry
    Match                dp.routable*
    Host                 otel-userapp.${MY_NAMESPACE}.svc.cluster.local
    Port                 4318
    Logs_uri             /v1/logs
    Log_response_payload True
    Tls                  Off
    Tls.verify           Off
EOF
fi
