#!/bin/bash
#
# Copyright (c) 2023-2024. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

# TODO: MSGDP-316: Comment out redundant OUTPUT=stdout after testing is complete
outfile=${1:-output.conf}
cat - <<EOF > $outfile
[OUTPUT]
    Name                 opentelemetry
    Match                dp.routable
    Host                 otel-services.${MY_NAMESPACE}.svc.cluster.local
    Port                 4318
    Logs_uri             /v1/logs
    Log_response_payload True
    Tls                  Off
    Tls.verify           Off
EOF

outfile=${1:-output-stdout.conf}
cat - <<EOF > $outfile
[OUTPUT]
    Name stdout
    Match dp.routable
EOF
