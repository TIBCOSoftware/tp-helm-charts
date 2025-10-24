#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-common.conf}
cat - <<EOF > $outfile
[FILTER]
    name             parser
    match            *
    key_name         message
    parser           ems

[FILTER]
    Name lua
    Match *
    Script datetime.lua
    Call datetime

[FILTER]
    Name record_modifier
    Match *
    Remove_key date
    Remove_key time

[FILTER]
    Name modify
    Alias common.filter
    Match *
    Add level info
    Rename message log.message
    Rename level log.log_level
    Rename caller log.caller
    Rename datetime log.log_time

# standardize log levels to allowed values INFO,ERROR,WARN,DEBUG
[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level EMERG
    Set log.level ERROR

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level emerg
    Set log.level ERROR

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level alert
    Set log.level ALERT

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level CRIT
    Set log.level ERROR

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level crit
    Set log.level ERROR

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level seve
    Set log.level ERROR

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level error
    Set log.level ERROR

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level WARNING
    Set log.level WARN

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level warn
    Set log.level WARN

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level notice
    Set log.level NOTICE

# [FILTER]
#     Name modify
#     Match *
#     Condition Key_Value_Equals log.level NOTICE
#     Set log.level INFO

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level info
    Set log.level INFO

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level debug
    Set log.level DEBUG

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level VERBOSE
    Set log.level DEBUG

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level verb
    Set log.level DEBUG

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level dbg1
    Set log.level DEBUG

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level dbg2
    Set log.level DEBUG

[FILTER]
    Name modify
    Match *
    Condition Key_Value_Equals log.level dbg3
    Set log.level DEBUG

# rewrite the tag for debug and verbose logs so we can re-route them (nowhere)
[FILTER]
    Name rewrite_tag
    Match dp.routable
    Rule log.level /DEBUG/ dp.non_routable false

[FILTER]
    Name nest
    Match dp.routable
    Nest_Under log
    Wildcard log.*
    Remove_prefix log.

EOF

outfile=${1:-datetime.lua}
cat - <<EOF > $outfile
-- add an ES compliant datetime to fluentbit record
-- Use date and time fields when provided, otherwise generate them as needed
function datetime(tag, timestamp, record)
    new_record = record
    -- new_record['event.created'] = os.date("%Y-%m-%dT%H:%M:%S")
    if record['date'] and record['time'] then
        new_record['datetime'] = record['date'] .. "T" .. record['time']
    elseif record['date'] then
        local time = os.date("%H:%M:%S")
        new_record['datetime'] = record['date'] .. "T" .. time
    elseif record['time'] then
        local date = os.date("%Y-%m-%d")
        new_record['datetime'] = date .. "T" .. record['time']
    else
        new_record['datetime'] = os.date("%Y-%m-%dT%H:%M:%S")
    end
    return 1, timestamp, new_record
end
EOF
