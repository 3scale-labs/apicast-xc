local redis_pool = require 'redis_pool'

local _M = { }

local function get_auth_hash_key(service_id, app_id)
  return 'auth:'..service_id..':'..app_id
end

local function get_report_hash_key(service_id, app_id)
  return 'report:'..service_id..':'..app_id
end

local SET_REPORT_KEYS = 'report_keys'

function _M.authorize(service_id, app_id, usage_method)
  local redis, ok = redis_pool.acquire()

  if not ok then
    return nil, false
  end

  local auth_hash_key = get_auth_hash_key(service_id, app_id)
  local cached_auth, _ = redis:hget(auth_hash_key, usage_method)

  redis_pool.release(redis)

  -- note: cached_auth == nil indicates that an error happened, whereas
  -- cached_auth == ngx.null indicates that the key does not exist.
  if cached_auth == nil then
    return nil, false
  end

  local auth
  if cached_auth == '0' then
    auth = false
  elseif cached_auth == '1' then
    auth = true
  end

  return auth, true
end

-- Returns true if the report succeeds, false otherwise.
function _M.report(service_id, app_id, usage_method, usage_val)
  local redis, ok = redis_pool.acquire()

  if not ok then
    return false
  end

  local report_hash_key = get_report_hash_key(service_id, app_id)

  -- Run the 2 Redis commands in a pipeline to save network round-trip time.
  -- If executing a command in between is problematic, we should use a
  -- transaction with multi instead, but that's not clear yet.
  redis:init_pipeline(2)
  redis:hincrby(report_hash_key, usage_method, usage_val)
  redis:sadd(SET_REPORT_KEYS, report_hash_key)
  local result, _ = redis:commit_pipeline()

  redis_pool.release(redis)

  return result ~= nil
end

return _M
