#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

# TODO: MSGDP-316: Comment out redundant OUTPUT=stdout after testing is complete
outfile=${1:-output.conf}
if [[ "$MSGDP_LOGGING_FLUENTBIT_ENABLED" == "true" ]]; then
    cat - <<EOF > $outfile
[OUTPUT]
    Name                 opentelemetry
    Match                dp.routable*
    Host                 ${MSGDP_OTEL_SERVICE}
    Port                 4318
    Logs_uri             /v1/logs
    Log_response_payload True
    Tls                  Off
    Tls.verify           Off
EOF
else
    cat - <<EOF > $outfile
[OUTPUT]
    Name stdout
    Match dp.routable*
EOF
fi
