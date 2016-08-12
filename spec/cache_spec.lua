describe('cache', function()
  local cache
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

    cache = require 'cache'
  end)

  describe('authorize', function()
    local service_id = 'a_service_id'
    local app_id = 'an_app_id'
    local method = 'a_method'

    describe('when the authorization is cached and it is OK', function()
      setup(function()
        -- TODO: avoid constructing the hash key here
        redis_client:hset('auth:'..service_id..':'..app_id, method, '1')
      end)

      it('returns true', function()
        local cached_auth, ok = cache.authorize(service_id, app_id, method)
        assert.is_true(ok)
        assert.is_true(cached_auth)
      end)

      teardown(function()
        redis_client:del('auth:'..service_id..':'..app_id)
      end)
    end)

    describe('when the authorization is cached and it is denied', function()
      setup(function()
        redis_client:hset('auth:'..service_id..':'..app_id, method, '0')
      end)

      it('returns false', function()
        local cached_auth, ok = cache.authorize(service_id, app_id, method)
        assert.is_true(ok)
        assert.is_false(cached_auth)
      end)

      teardown(function()
        redis_client:del('auth:'..service_id..':'..app_id)
      end)
    end)

    describe('when the authorization is not cached', function()
      it('returns nil', function()
        local cached_auth, ok = cache.authorize(service_id, app_id, method)
        assert.is_true(ok)
        assert.is_nil(cached_auth)
      end)
    end)
  end)
end)
