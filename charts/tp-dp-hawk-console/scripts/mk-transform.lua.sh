#!/bin/bash
#
# Copyright (c) 2023-2025. Cloud Software Group, Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
#

outfile=${1:-transform_ems_to_otel.lua}
cat - <<EOF > $outfile
-- transform EMS logs to OpenTelemetry format
function transform_ems_to_otel(tag, timestamp, record)
    local new_record = {}

-- basic log info
    new_record["log"] = {}
    local log_level = "info"  -- default log level
    local message = record["msg"]
    local message_lower = string.lower(message)

    -- List of warning log level keywords
    local warning_keywords = {"warn", "warning"}

    -- List of error log level keywords
    local error_keywords = {"error", "failed", "exception"}

    -- List of alert log level keywords
    local alert_keywords = {"alert"}


    -- Check for warning keywords at the start of the message
    for _, keyword in ipairs(warning_keywords) do
        if string.sub(message_lower, 1, #keyword) == keyword then
            log_level = "warn"
            break
        end
    end
    
    -- Check for error keywords at the start of the message
    for _, keyword in ipairs(error_keywords) do
        if string.sub(message_lower, 1, #keyword) == keyword then
            log_level = "error"
            break
        end
    end

    -- Check for alert keywords at the start of the message
    for _, keyword in ipairs(alert_keywords) do
        if string.sub(message_lower, 1, #keyword) == keyword then
            log_level = "alert"
            break
        end
    end

    new_record["log"]["log_level"] = log_level
    new_record["log"]["message"] = record["msg"]
    new_record["log"]["log_time"] = record["time"]
    new_record["log"]["caller"] = "tibemsd"

-- bmdp unique info
    new_record["log"]["app_id"] = record["app_id"]
    new_record["log"]["group"] = record["group"]
    new_record["log"]["groupName"] = record["groupName"]
    new_record["log"]["instance"] = record["instance"]
    new_record["log"]["server_name"] = record["server_name"]
    new_record["log"]["host_cloud_type"] = "control-tower"

    return 1, timestamp, new_record
end
EOF
