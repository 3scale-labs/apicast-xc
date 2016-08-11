local redis_pool = require 'redis_pool'

local _M = {
  auth = {
    ok = 0,
    denied = 1,
    unknown = 2,
  },
  error = {
    db_connection_failed = 0,
  }
}

local function get_hash_key(service_id, app_id)
  return service_id..':'..app_id
end

local function do_authrep(service_id, app_id, usage_method, usage_val)
  local output = { auth = _M.auth.unknown }
  local hash_key = get_hash_key(service_id, app_id)
  local redis, ok, err = redis_pool.acquire()

  if not ok then
    -- handle exhausted pool or connection error
    -- and exit early with proper output
    output.error = _M.error.db_connection_failed
    output.error_desc = 'db: '..err
    goto hell
  end

  -- [...]
  -- Fill in with proper calls for computing output
  output.auth = _M.auth.ok

  -- finished dealing with the database, release the connection
  -- TODO: handle possible errors returned by this
  redis_pool.release(redis)

::hell::
  return output
end

-- entry point for the module
--
-- service_id: string with the service identifier
-- app_id: string with the application identifier as
--         * "user_key" OR
--         * "app_id:app_key" OR
--         * ...
--         Note: this might become more complex as we discover how to
--         handle different application authentication methods
-- usage:  table containing key-values of the form method-usage
--         Note: this is currently restricted to ONE key-value
function _M.authrep(service_id, app_id, usage)
  local usage_method, usage_val = next(usage)

  return do_authrep(service_id, app_id, usage_method, usage_val)
end

return _M
