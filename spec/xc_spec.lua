describe('xc', function()
  local xc
  local redis_client

  setup(function()
    -- Mock the redis pool. For testing, we'll use redis-lua instead of resty.redis
    local redis = require 'redis'

    local redis_cfg = {
      host = 'xc-redis',
      port = 6379
    }

    redis_client = redis.connect(redis_cfg.host, redis_cfg.port)

    package.loaded.redis_pool = {
      acquire = function() return redis_client, true end,
      release = function() return true end
    }

    xc = require 'xc'
  end)

  describe('authrep', function()
    it('returns auth ok', function()
      local res_auth = xc.authrep('a_service_id', 'an_app_id', { a_method = 1 }).auth
      assert.are.equals(xc.auth.ok, res_auth)
    end)
  end)
end)
