#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-parsers.conf}
cat - <<EOF > $outfile
[PARSER]
    Name        msg-parser
    Format      logfmt
    Time_Key    time
    Time_Keep   On
    Time_Format %Y-%m-%dT%H:%M:%S.%L
[PARSER]
    Name    watchdog-parser
    Format  regex
    Regex   ^(?<caller>\S+)\s+(?<date>[0-9-]+)\s(?<time>[0-9:.]+)\s+(?:(?<level>[a-z]+|[A-Z]+):?\s+)?(?<message>(?:\s+\w+?:\s+)?.*)
EOF
