local cache = require 'xc/cache'
local priority_auths = require 'xc/priority_auths'

local _M = {
  auth = {
    ok = 0,
    denied = 1,
    unknown = 2
  },
  error = {
    cache_auth_failed = 0,
    cache_report_failed = 1
  }
}

local function do_authrep(auth_storage, service_id, app_id, usage_method, usage_val)
  local auth_ok, cached_auth, reason = auth_storage.authorize(
    service_id, app_id, usage_method)

  local output = { auth = _M.auth.unknown }

  if not auth_ok then
    output.error = _M.error.cache_auth_failed
    goto hell
  end

  if cached_auth then
    output.auth = _M.auth.ok
    local report_ok = cache.report(service_id, app_id, usage_method, usage_val)

    if not report_ok then
      output.error = _M.error.cache_report_failed
    end
  elseif not cached_auth and cached_auth ~= nil then
    output.auth = _M.auth.denied
    output.reason = reason
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

  -- First, try to retrieve the authorization from the cache. If it's there,
  -- return it, and do the report if it's authorized. If the auth is not in the
  -- cache, use the priority auth renewer based on Redis pubsub to get it.

  local cache_res = do_authrep(cache, service_id, app_id, usage_method, usage_val)

  if cache_res.auth == _M.auth.unknown then
    cache_res = do_authrep(priority_auths, service_id, app_id, usage_method, usage_val)
  end

  return cache_res
end

return _M
