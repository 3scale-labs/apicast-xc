local redis_pool = require 'lib/redis_pool'
local authorizations_formatter = require 'xc/authorizations_formatter'

local AUTH_REQUESTS_CHANNEL = 'xc_channel_auth_requests'
local AUTH_RESPONSES_CHANNEL_PREFIX = 'xc_channel_auth_response:'

local _M = { }

local function request_msg(service_id, user_key, metric)
  return service_id..':'..user_key..':'..metric
end

local function auth_responses_channel(service_id, user_key, metric)
  return AUTH_RESPONSES_CHANNEL_PREFIX..service_id..':'..user_key..':'..metric
end

-- @return true if the authorization could be retrieved, false otherwise
-- @return true if authorized, false if denied, nil if unknown
-- @return reason why the authorization is denied (optional, required only when denied)
function _M.authorize(service_id, user_key, metric)
  local redis_pub, ok_pub = redis_pool.acquire()

  if not ok_pub then
    return false, nil
  end

  local redis_sub, ok_sub = redis_pool.acquire()

  if not ok_sub then
    redis_pool.release(redis_pub)
    return false, nil
  end

  local res_pub = redis_pub:publish(AUTH_REQUESTS_CHANNEL,
                                    request_msg(service_id, user_key, metric))

  redis_pool.release(redis_pub)

  if not res_pub then
    redis_pool.release(redis_sub)
    return false, nil
  end

  local res_sub = redis_sub:subscribe(
    auth_responses_channel(service_id, user_key, metric))

  if not res_sub then
    redis_pool.release(redis_sub)
    return false, nil
  end

  local channel_reply = redis_sub:read_reply()

  if not channel_reply then
    redis_pool.release(redis_sub)
    return false, nil
  end

  local auth_msg = channel_reply[3] -- the value returned is in pos 3

  redis_pool.release(redis_sub)

  if not auth_msg then
    return false, nil
  end

  local auth, reason = authorizations_formatter.authorization(auth_msg)
  return true, auth, reason
end

return _M
