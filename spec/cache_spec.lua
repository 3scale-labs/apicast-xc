describe('cache', function()
  local cache
  local redis_client
  local redis_pool

  setup(function()
    -- Mock the redis pool. For testing, we'll use redis-lua instead of resty.redis
    local redis = require 'redis'

    local redis_cfg = {
      host = 'xc-redis',
      port = 6379
    }

    redis_client = redis.connect(redis_cfg.host, redis_cfg.port)

    -- redis-lua and resty.redis use a different syntax for pipelines. We do
    -- not need pipelines for testing, but we need to make sure that our client
    -- defines the 2 methods used by resty.redis: init_pipeline() and
    -- commit_pipeline().
    redis_client.init_pipeline = function() end
    redis_client.commit_pipeline = function() return true end

    package.loaded.redis_pool = {
      acquire = function() return redis_client, true end,
      release = function() return true end
    }

    redis_pool = package.loaded.redis_pool
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

    describe('when there is an error acquiring a Redis connection', function()
      setup(function()
        redis_pool.acquire = function() return nil, false end
      end)

      it('returns an error', function()
        local _, ok = cache.authorize(service_id, app_id, method)
        assert.is_false(ok)
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
        local _, ok = cache.authorize(service_id, app_id, method)
        assert.is_false(ok)
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)
  end)

  describe('report', function()
    local service_id = 'a_service_id'
    local app_id = 'an_app_id'
    local method = 'a_method'
    local usage_val = 10

    -- TODO: Try not to hardcode these 2 here
    local report_key = 'report:'..service_id..':'..app_id
    local report_keys_set = 'report_keys'

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
        cache.report(service_id, app_id, method, usage_val)

        local cached_val = redis_client:hget(report_key, method)
        assert.are_equals(current_usage + usage_val, tonumber(cached_val))
      end)

      it('returns true', function()
        assert.is_true(cache.report(service_id, app_id, method, usage_val))
      end)
    end)

    describe('when the usage is not cached and there are no DB connection errors', function()
      it('caches the reported value', function()
        cache.report(service_id, app_id, method, usage_val)

        local cached_val = redis_client:hget(report_key, method)
        assert.are_equals(usage_val, tonumber(cached_val))
      end)

      it('adds the report hash key to the set of modified keys', function()
        cache.report(service_id, app_id, method, usage_val)
        assert.are_equals(report_key, redis_client:smembers(report_keys_set)[1])
      end)

      it('returns true', function()
        assert.is_true(cache.report(service_id, app_id, method, usage_val))
      end)
    end)

    describe('when there is an error acquiring a Redis connection', function()
      setup(function()
        redis_pool.acquire = function() return nil, false end
      end)

      it('returns false', function()
        assert.is_false(cache.report(service_id, app_id, method, usage_val))
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)

    describe('when there is an error reporting to Redis', function()
      setup(function()
        -- we need to create a Redis client that accepts all the commands used
        -- in the code and that returns an error in some step
        redis_pool.acquire = function()
          return { init_pipeline = function() end,
                   hincrby = function() end,
                   sadd = function() end,
                   commit_pipeline = function() return nil, true end }, true
        end
      end)

      it('returns false', function()
        assert.is_false(cache.report(service_id, app_id, method, usage_val))
      end)

      teardown(function()
        redis_pool.acquire = function() return redis_client, true end
      end)
    end)
  end)
end)
