local redis_pool = require 'redis_pool'

local _M = {
  error = {
    db_connection_failed = 'DB connection failed'
  }
}

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
    return nil, false, _M.error.db_connection_failed
  end

  local auth_hash_key = get_auth_hash_key(service_id, app_id)
  local cached_auth, err = redis:hget(auth_hash_key, usage_method)

  redis_pool.release(redis)

  if err then
    return nil, false, _M.error.db_connection_failed
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
  local _, err_hincrby = redis:hincrby(report_hash_key, usage_method, usage_val)

  local _, err_sadd = redis:sadd(SET_REPORT_KEYS, report_hash_key)

  redis_pool.release(redis)

  return not (err_hincrby or err_sadd)
end

return _M
