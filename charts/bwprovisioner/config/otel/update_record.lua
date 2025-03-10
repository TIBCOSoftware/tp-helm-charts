--[[
   # Copyright © 2025. Cloud Software Group, Inc.
   # This file is subject to the license terms contained
   # in the license file that is distributed with this file.
]]

function update_record(tag, timestamp, record)
  old_log = record["log"]
  if old_log ~= nil and old_log["@timestamp"] and old_log["level"] and old_log["thread_name"] and old_log["logger_name"] and old_log["message"] then
    old_log["log_time"] = old_log["@timestamp"]
    old_log["log_level"] = old_log["level"]
    old_log["message"] = "[" .. old_log["thread_name"] .. "] " .. old_log["logger_name"] .. " - " .. old_log["message"]
    return 1, timestamp, old_log
  end
  return 1, timestamp, record
end