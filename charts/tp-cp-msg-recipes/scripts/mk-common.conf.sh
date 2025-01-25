#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-common.conf}
cat - <<EOF > $outfile
[FILTER]
    name             parser
    match            dp.routable
    key_name         message
    parser           msg-parser
    Reserve_Data     False

[FILTER]
    name             parser
    match            dp.routable.watchdog
    key_name         message
    parser           watchdog-parser
    Reserve_Data     False

[FILTER]
    Name modify
    Match dp.routable
    Add caller msg-webserver

[FILTER]
    Name lua
    Match dp.routable.watchdog
    Script datetime.lua
    Call datetime

[FILTER]
    Name record_modifier
    Match dp.routable.watchdog
    Remove_key date
    Remove_key time

[FILTER]
    Name modify
    Alias common.filter
    Match dp.routable.watchdog
    Add level INFO
    Rename message log.msg
    Rename level log.level
    Rename caller log.caller
    Rename datetime time

[FILTER]
    Name nest
    Match dp.routable.watchdog
    Nest_Under log
    Wildcard log.*
    Remove_prefix log.

[FILTER]
    Name modify
    Alias common.filter
    Match dp.routable
    Add level INFO
    Rename message msg
    Rename err error

[FILTER]
    Name nest
    Match dp.routable
    Nest_Under log
    Wildcard *

[FILTER]
    Name lua
    Match *
    Script update_record.lua
    Call update_record

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

outfile=${1:-update_record.lua}
cat - <<EOF > $outfile
-- Function to append all fields under key "msg"
function update_record(tag, timestamp, record)
    local newLog = record["log"]
    local newMsg = newLog["msg"]
     for key, val in pairs(newLog) do
       if(key ~= "level" and key ~= "caller" and key ~= "msg" and key ~= "stacktrace" and key ~= "error" and key ~= "errorVerbose") then
         if(key ~= "time") then
           newMsg = newMsg .. ", " .. key .. ": " .. tostring(val)
         else
           record["time"] = record["log"]["time"]
         end
         newLog[key] = nil
       end
     end
     newLog["msg"] = newMsg
     record["log"] = newLog
     return 2, timestamp, record
end
EOF
