local redis = require 'resty.redis'
local exceptions = require 'exceptions'
local errors = require 'errors'

-- Redis connection parameters
local _M = {
  host      = os.getenv("REDIS_HOST") or 'xc-redis',
  port      = 6379,
  timeout   = 1000,  -- 1 second
  keepalive = 10000, -- milliseconds
  poolsize  = 1000   -- # connections
}

-- @return table with a redis connection from the pool
function _M.acquire()
  if ngx.ctx.redis == nil then
    ngx.ctx.redis = redis
  end
  local conn = ngx.ctx.redis:new()

  conn:set_timeout(_M.timeout)

  local ok, err = conn:connect(_M.host, _M.port)

  if not ok then
    ngx.log(ngx.ERR, "failed to connect to redis: ", err)
    local pthru = exceptions.passthrough_on(exceptions.redis_pool_redis_error)
    if not pthru.allowed then
      errors.respond_with_error(pthru.error_type)
    end
  end

  return conn
end

-- return ownership of this connection to the pool
function _M.release(conn)
  conn:set_keepalive(_M.keepalive, _M.poolsize)
  ngx.ctx.redis = nil
end

return _M
