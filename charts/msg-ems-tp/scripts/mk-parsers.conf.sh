#
# Copyright (c) 2023. Cloud Software Group, Inc.
# This file is subject to the license terms contained 
# in the license file that is distributed with this file.  
#

outfile=${1:-parsers.conf}
cat - <<EOF > $outfile

[MULTILINE_PARSER]
    name multiline-ems
    type regex
    flush_Timeout 1000
    key_content message
    #
    # Regex rules for multiline parsing
    # ---------------------------------
    #
    # configuration hints:
    #
    #  - first state always has the name: start_state
    #  - every field in the rule must be inside double quotes
    #
    # rules |   state name  | regex pattern                  | next state
    # ------|---------------|--------------------------------------------
    rule     "start_state"   "/^[\S]+\s+[0-9-]+\s[0-9:.]+\s+[\S]+.*/" "cont"
    rule     "cont"          "/^[\S]+\s+(?![0-9-]+\s)\S+/"            "cont"

[PARSER]
    Name ems
    Format regex
    # level, caller, msg, stacktrace, error, errorVerbose
    Regex   /^(?<caller>\S+)\s+(?<date>[0-9-]+)\s(?<time>[0-9:.]+)\s+(?:(?<level>[a-z]+|[A-Z]+):?\s+)?(?<message>(?:\s+\w+?:\s+)?.*)/m

EOF
