-- This module defines the interface of XC with Redis.
-- Specifically, it defines the format of all the keys that contain cached
-- authorizations and reports, and also, the format of the keys used in the
-- pubsub mechanism.
-- If the flusher used changes the format of the storage keys that it needs to
-- work properly, this is the only module that should require changes.

local _M = { AUTH_REQUESTS_CHANNEL = 'xc_channel_auth_requests',
             SET_REPORT_KEYS = 'report_keys' }

local AUTH_RESPONSES_CHANNEL_PREFIX = 'xc_channel_auth_response:'

local REPORT_CREDS_IN_KEY = { 'app_id',
                              'user_key',
                              'access_token',
                              'user_id',
                              'app_key' }

-- Escapes ':' and ','.
local function escape(string)
  return string:gsub(':', '\\:'):gsub(',', '\\,')
end

local function sort_table(t)
  local res = {}
  for elem in pairs(t) do table.insert(res, elem) end
  table.sort(res)
  return res
end

local function encode(credentials)
  local res = {}

  for i, cred in ipairs(sort_table(credentials)) do
      res[i] = escape(cred) .. ':' .. escape(credentials[cred])
  end

  return table.concat(res, ',')
end

local function filter_creds_for_report_key(creds)
  local res = {}

  for _, cred in pairs(REPORT_CREDS_IN_KEY) do
    res[cred] = creds[cred]
  end

  return res
end

local function get_key(key_type, service_id, credentials)
  return key_type .. ',' ..
      'service_id:' .. escape(service_id) .. ',' ..
      encode(credentials)
end

-- Returns an auth key for a { service_id, credentials } pair.
-- Format of the key:
--     auth,service_id:<service_id>,<credentials> where:
--     <service_id>: service ID.
--     <credentials>: credentials needed for authentication separated by ','.
--                    For example: app_id:my_app_id,user_key:my_user_key.
--                    The credentials appear sorted, to avoid creating 2
--                    different keys for the same report/auth.
--     ':' and ',' in the values are escaped.
--
-- Params:
-- service_id: String. Service ID.
-- credentials: Table. credentials needed to authenticate an app.
function _M.get_auth_key(service_id, credentials)
  return get_key('auth', service_id, credentials)
end

-- Returns a report key for a { service_id, credentials } pair.
-- Format of the key:
--     report,service_id:<service_id>,<credentials> where:
--     <service_id>: service ID.
--     <credentials>: credentials needed for authentication separated by ','.
--                    For example: app_id:my_app_id,user_key:my_user_key.
--                    The credentials appear sorted, to avoid creating 2
--                    different keys for the same report/auth.
--     ':' and ',' in the values are escaped.
--
-- There are some credentials that are needed for authenticating and not for
-- reporting. For example, a referrer.
-- If all the credentials are equal, but the referrer is different, the auth
-- status might change, and that means we need to store them in 2 different
-- keys. However, for reporting, we do not care about the referrer, because
-- the app is still the same. That's why the referrer is not included in
-- 'report' keys. The credentials that can be used for reporting are: 'app_id',
-- 'user_key', 'access_token', 'user_id', 'app_key'.
--
-- Params:
-- service_id: String. Service ID.
-- credentials: Table. credentials needed to authenticate an app.
function _M.get_report_key(service_id, credentials)
  return get_key('report', service_id, filter_creds_for_report_key(credentials))
end

-- Returns the message that needs to be published in the pubsub mechanism to
-- ask for an authorization.
-- Format of the message:
--     service_id:<service_id>,<credentials>,metric:<metric> where:
--     <service_id>: service ID.
--     <credentials>: credentials needed for authentication separated by ','.
--                    For example: app_id:my_app_id,user_key:my_user_key.
--                    The credentials appear sorted.
--     <metric>: metric name.
--     ':' and ',' in the values are escaped.
--
-- Params:
-- service_id: String. Service ID.
-- credentials: Table. credentials needed to authenticate an app.
-- metric: String. Metric name.
function _M.get_pubsub_req_msg(service_id, credentials, metric)
  return 'service_id:' .. escape(service_id) .. ',' ..
      encode(credentials) .. ',' ..
      'metric:' .. escape(metric)
end

-- Returns the pubsub channel to which the client needs to be subscribed after
-- asking for an authorization to receive the response.
-- The format is the same as the message that needs to be published prefixed
-- by 'xc_channel_auth_response:'.
--
-- Params:
-- service_id: String. Service ID.
-- credentials: Table. credentials needed to authenticate an app.
-- metric: String. Metric name.
function _M.get_pubsub_auths_resp_channel(service_id, credentials, metric)
  return AUTH_RESPONSES_CHANNEL_PREFIX ..
      _M.get_pubsub_req_msg(service_id, credentials, metric)
end

return _M
