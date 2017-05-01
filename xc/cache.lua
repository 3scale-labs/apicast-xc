local redis_pool = require 'xc/redis_pool'
local authorizations_formatter = require 'xc/authorizations_formatter'
local storage_keys = require 'xc/storage_keys'

local _M = { }

-- Returns true when executed correctly. False otherwise.
-- Note: The two commands of this method can be executed in a pipeline.
-- Multi/exec would ensure that the 2 commands are executed atomically, but it
-- would make things considerably slower and increase the CPU usage of the
-- Redis server. In our case we do not really need atomicity:
-- 1) If a flush is triggered between the two commands, the flusher will not
--    report the usage in that cycle, but it will report it in the next one.
--    Also, this would only happen when it is the first time that the method is
--    reported in that cycle. Otherwise, it will be reported anyway.
-- 2) If a flush is triggered between the two commands and the method is not
--    reported in the next cycle, the flusher will find a key in the set of
--    report keys that does not exist. It is a bit counter-intuitive but the
--    flusher needs to treat this as a non-error. This is the only downside of
--    not using multi/exec.
local function report_and_update_reported_set(service_id, creds, usage_method, usage_val, redis)
  redis:init_pipeline(2)

  local report_hash_key = storage_keys.get_report_key(service_id, creds)
  redis:hincrby(report_hash_key, usage_method, usage_val)
  redis:sadd(storage_keys.SET_REPORT_KEYS, report_hash_key)

  return redis:commit_pipeline() ~= nil
end

-- @return true if the authorization could be retrieved, false otherwise
-- @return true if authorized, false if denied, nil if unknown
-- @return reason why the authorization is denied (optional)
function _M.authorize(service_id, credentials, usage_method)
  local redis, ok, err = redis_pool.acquire()

  if not ok then
    ngx.log(ngx.WARN, "[cache] couldn't connect to redis on authorization: ", err)
    return false, nil
  end

  local auth_hash_key = storage_keys.get_auth_key(service_id, credentials)
  local cached_auth, _ = redis:hget(auth_hash_key, usage_method)

  redis_pool.release(redis)

  local auth, reason = authorizations_formatter.authorization(cached_auth)
  return cached_auth ~= nil, auth, reason
end

-- Returns true if the report succeeds, false otherwise.
function _M.report(service_id, app_id, usage_method, usage_val)
  local redis, ok, err = redis_pool.acquire()
  if not ok then
    ngx.log(ngx.WARN, "[cache] couldn't connect to redis on reporting: ", err)
    return false
  end

  local res_report = report_and_update_reported_set(
    service_id, app_id, usage_method, usage_val, redis)

  redis_pool.release(redis)

  return res_report
end

return _M
