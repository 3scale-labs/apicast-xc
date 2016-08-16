local cache = require 'cache'

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

local function do_authrep(service_id, app_id, usage_method, usage_val)
  local cached_auth, ok = cache.authorize(service_id, app_id, usage_method)

  local output = { auth = _M.auth.unknown }

  if not ok then
    output.error = _M.error.db_connection_failed
    goto hell
  end

  if cached_auth then
    output.auth = _M.auth.ok
    cache.report(service_id, app_id, usage_method, usage_val)
  elseif not cached_auth and cached_auth ~= nil then
    output.auth = _M.auth.denied
  end

  -- note: when auth = unknown, we do not report the usage. We might change
  -- this in the future or make it configurable.

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
