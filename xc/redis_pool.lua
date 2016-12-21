local redis = require 'resty.redis'

local function get_host_and_port(s)
  if s == nil then return { } end

  local res = { }
  local i = 1

  for str in string.gmatch(s, '[^:]+') do
    res[i] = str
    i = i + 1
  end

  return res
end

local host, port = unpack(get_host_and_port(os.getenv("XC_REDIS_HOST")))

-- Redis connection parameters
local _M = {
  host      = host or 'localhost',
  port      = tonumber(port) or 6379,
  timeout   = 3000,  -- 3 seconds
  keepalive = 10000, -- milliseconds
  poolsize  = os.getenv("REDIS_CONN_POOL") or 10000 -- # connections
}

-- @return table with a redis connection from the pool
function _M.acquire()
  local conn = redis:new()

  conn:set_timeout(_M.timeout)

  local ok, err = conn:connect(_M.host, _M.port)

  return conn, ok, err
end

-- return ownership of this connection to the pool
function _M.release(conn)
  conn:set_keepalive(_M.keepalive, _M.poolsize)
end

return _M
