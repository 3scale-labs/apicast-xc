local redis_pool = require 'redis_pool'

local _M = {
  error = {
    db_connection_failed = 'DB connection failed'
  }
}

local function get_auth_hash_key(service_id, app_id)
  return 'auth:'..service_id..':'..app_id
end

function _M.authorize(service_id, app_id, usage_method)
  local redis, ok = redis_pool.acquire()

  if not ok then
    return nil, false, _M.error.db_connection_failed
  end

  local auth_hash_key = get_auth_hash_key(service_id, app_id)
  local cached_auth, err = redis:hget(auth_hash_key, usage_method)

  if err then
    return nil, false, _M.error.db_connection_failed
  end

  redis_pool.release(redis)

  local auth
  if cached_auth == '0' then
    auth = false
  elseif cached_auth == '1' then
    auth = true
  end

  return auth, true
end

return _M
