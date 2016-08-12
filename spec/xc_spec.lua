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
    local service_id = 'a_service_id'
    local app_id = 'an_app_id'
    local method = 'a_method'
    local usage = { a_method = 1 } -- just 1 metric for now

    describe('when the call is authorized', function()
      setup(function()
        -- TODO: avoid constructing the hash key here
        redis_client:hset(service_id..':'..app_id, method, '1')
      end)

      it('returns ok', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.ok, res_auth)
      end)

      teardown(function()
        redis_client:del(service_id..':'..app_id)
      end)
    end)

    describe('when the call is not authorized', function()
      setup(function()
        redis_client:hset(service_id..':'..app_id, method, '0')
      end)

      it('returns denied', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.denied, res_auth)
      end)

      teardown(function()
        redis_client:del(service_id..':'..app_id)
      end)
    end)

    describe('when we cannot determine whether the call is authorized', function()
      it('returns unknown', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.unknown, res_auth)
      end)
    end)
  end)
end)
