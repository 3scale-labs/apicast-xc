local redis = require 'resty.redis'
local threescale_utils = require 'threescale_utils'

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
  timeout   = tonumber(os.getenv("REDIS_TIMEOUT")) or 3000,  -- 3 seconds
  keepalive = tonumber(os.getenv("REDIS_KEEPALIVE")) or 10000, -- milliseconds
  poolsize  = tonumber(os.getenv("REDIS_CONN_POOL")) or 10000 -- # connections
}

-- @return table with a redis connection from the pool
function _M.acquire()
  local conn = redis:new()

  conn:set_timeout(_M.timeout)

  local resolved_ok, ip, port = pcall(threescale_utils.resolve, _M.host, _M.port)

  local res_ok, err
  if resolved_ok then
    res_ok, err = conn:connect(ip, port)
  else
    res_ok = false
    err = 'Failed to resolve redis hostname'
  end

  return conn, res_ok, err
end

-- return ownership of this connection to the pool
function _M.release(conn)
  conn:set_keepalive(_M.keepalive, _M.poolsize)
end

return _M
