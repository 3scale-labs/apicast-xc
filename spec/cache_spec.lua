describe('cache', function()
  local cache
  local redis_client
  local redis_pool
  local storage_keys = require 'xc/storage_keys'

  -- Use a spy to ensure that Redis connections are not leaked
  local spy_redis_release

  -- Use a spy to ensure that warning are logged as expected
  local spy_logger

  -- The redis client used in testing. It uses lua-redis instead of resty.redis
  local function test_redis_client()
    local redis = require 'redis'

    local redis_cfg = {
      host = 'localhost',
      port = 6379
    }

    local client = redis.connect(redis_cfg.host, redis_cfg.port)

    -- redis-lua and resty.redis use a different syntax for pipelining. We do
    -- not need pipeline for testing, but we need to make sure that our client
    -- defines the 2 methods used by resty.redis: init_pipeline() and
    -- commit_pipeline().
    client.init_pipeline = function() return true end
    client.commit_pipeline = function() return true end

    return client
  end

  setup(function()
    redis_client = test_redis_client()

    -- Mock the redis pool to use the test redis client instead of resty.redis
    package.loaded['xc/redis_pool'] = {
      acquire = function() return redis_client, true end,
      release = function() return true end
    }

    redis_pool = package.loaded['xc/redis_pool']
    cache = require 'xc/cache'

    -- assumes redis_pool.release is not changed in any of these tests
    spy_redis_release = spy.on(redis_pool, 'release')

    -- mock ngx and its logger
    _G.ngx = { log = function() end }
    spy_logger = spy.on(_G.ngx, 'log')
  end)

  before_each(function()
    spy_redis_release:clear() -- reset call history
    spy_logger:clear()
  end)

  describe('authorize', function()
    local service_id = 'a_service_id'
    local creds = { app_id = 'an_app_id' }
    local method = 'a_method'
    local auth_key = storage_keys.get_auth_key(service_id, creds)

    describe('when the authorization is cached and it is OK', function()
      setup(function()
        redis_client:hset(auth_key, method, '1')
      end)

      it('returns true', function()
        local ok, cached_auth = cache.authorize(service_id, creds, method)
        assert.is_true(ok)
        assert.is_true(cached_auth)
      end)

      it('releases the Redis connection', function()
        cache.authorize(service_id, creds, method)
        assert.equals(1, #spy_redis_release.calls)
      end)

      teardown(function()
        redis_client:del(auth_key)
      end)
    end)

    describe('when the authorization is cached and it is denied', function()
      describe('and a reason is specified', function()
        local reason = 'a_reason'
        setup(function()
          redis_client:hset(auth_key, method, '0:'..reason)
        end)

        it('returns false', function()
          local ok, cached_auth, cached_reason = cache.authorize(
            service_id, creds, method)
          assert.is_true(ok)
          assert.is_false(cached_auth)
          assert.are.same(reason, cached_reason)
        end)
      end)

      describe('and the reason is not specified', function()
        setup(function()
          redis_client:hset(auth_key, method, '0')
        end)

        it('returns false', function()
          local ok, cached_auth = cache.authorize(service_id, creds, method)
          assert.is_true(ok)
          assert.is_false(cached_auth)
        end)
      end)

      it('releases the Redis connection', function()
        cache.authorize(service_id, creds, method)
        assert.equals(1, #spy_redis_release.calls)
      end)

      teardown(function()
        redis_client:del(auth_key)
      end)
    end)

    describe('when the authorization is not cached', function()
      setup(function()
        redis_client.ngx = { null = 'ngx.null' }
        redis_client.hget = function() return redis_client.ngx.null end
      end)

      it('returns nil', function()
        local ok, cached_auth = cache.authorize(service_id, creds, method)
        assert.is_true(ok)
        assert.is_nil(cached_auth)
      end)

      it('releases the Redis connection', function()
        cache.authorize(service_id, creds, method)
        assert.equals(1, #spy_redis_release.calls)
      end)

      teardown(function()
        redis_client = test_redis_client()
      end)
    end)

    describe('when the authorization is cached and it has an invalid value', function()
      setup(function()
        redis_client:hset(auth_key, method, 'corrupted_value')
      end)

      it('returns nil', function()
        local ok, cached_auth = cache.authorize(service_id, creds, method)
        assert.is_true(ok)
        assert.is_nil(cached_auth)
      end)

      it('releases the Redis connection', function()
        cache.authorize(service_id, creds, method)
        assert.equals(1, #spy_redis_release.calls)
      end)

      teardown(function()
        redis_client:del(auth_key)
      end)
    end)

    describe('when there is an error acquiring a Redis connection', function()
      setup(function()
        redis_pool.acquire = function() return nil, false end
      end)

      it('returns an error', function()
        local ok = cache.authorize(service_id, creds, method)
        assert.is_false(ok)
      end)

      it('logs a warning', function()
        cache.authorize(service_id, creds, method)
        assert.equals(1, #spy_logger.calls)
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)

    describe('when there is an error checking the auth in Redis', function()
      setup(function()
        redis_pool.acquire = function()
          return { hget = function() return nil, true end }, true
        end
      end)

      it('returns an error', function()
        local ok = cache.authorize(service_id, creds, method)
        assert.is_false(ok)
      end)

      it('releases the Redis connection', function()
        cache.authorize(service_id, creds, method)
        assert.equals(1, #spy_redis_release.calls)
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)
  end)

  describe('report', function()
    local service_id = 'a_service_id'
    local creds = { app_id = 'an_app_id' }
    local method = 'a_method'
    local usage_val = 10

    local report_key = storage_keys.get_report_key(service_id, creds)
    local report_keys_set = storage_keys.SET_REPORT_KEYS

    after_each(function()
      redis_client:del(report_key)
      redis_client:del(report_keys_set)
    end)

    describe('when the usage is cached and there are no DB connection errors', function()
      local current_usage = 5

      before_each(function()
        redis_client:hset(report_key, method, current_usage)
      end)

      it('increases the cached value by the one reported', function()
        cache.report(service_id, creds, method, usage_val)

        local cached_val = redis_client:hget(report_key, method)
        assert.are_equals(current_usage + usage_val, tonumber(cached_val))
      end)

      it('returns true', function()
        assert.is_true(cache.report(service_id, creds, method, usage_val))
      end)

      it('releases the Redis connection', function()
        cache.report(service_id, creds, method, usage_val)
        assert.equals(1, #spy_redis_release.calls)
      end)
    end)

    describe('when the usage is not cached and there are no DB connection errors', function()
      it('caches the reported value', function()
        cache.report(service_id, creds, method, usage_val)

        local cached_val = redis_client:hget(report_key, method)
        assert.are_equals(usage_val, tonumber(cached_val))
      end)

      it('adds the report hash key to the set of modified keys', function()
        cache.report(service_id, creds, method, usage_val)
        assert.are_equals(report_key, redis_client:smembers(report_keys_set)[1])
      end)

      it('returns true', function()
        assert.is_true(cache.report(service_id, creds, method, usage_val))
      end)

      it('releases the Redis connection', function()
        cache.report(service_id, creds, method, usage_val)
        assert.equals(1, #spy_redis_release.calls)
      end)
    end)

    describe('when there is an error acquiring a Redis connection', function()
      setup(function()
        redis_pool.acquire = function() return nil, false end
      end)

      it('returns false', function()
        assert.is_false(cache.report(service_id, creds, method, usage_val))
      end)

      it('logs a warning', function()
        cache.report(service_id, creds, method, usage_val)
        assert.equals(1, #spy_logger.calls)
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)

    describe('when there is an error reporting to Redis', function()
      setup(function()
        -- we need to create a Redis client that accepts all the commands used
        -- in the code and that returns an error when commiting the pipeline.
        redis_pool.acquire = function()
          return { init_pipeline = function() return true end,
                   hincrby = function() return true end,
                   sadd = function() return true end,
                   commit_pipeline = function() return nil end }, true
        end
      end)

      it('returns false', function()
        assert.is_false(cache.report(service_id, creds, method, usage_val))
      end)

      it('does not cache the usage', function()
        cache.report(service_id, creds, method, usage_val)
        assert.is_nil(redis_client:hget(report_key, method))
      end)

      it('does not update the set of updated keys', function()
        cache.report(service_id, creds, method, usage_val)
        assert.are.same({}, redis_client:smembers(report_keys_set))
      end)

      it('releases the Redis connection', function()
        cache.report(service_id, creds, method, usage_val)
        assert.equals(1, #spy_redis_release.calls)
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)
  end)
end)
