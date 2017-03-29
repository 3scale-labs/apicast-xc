describe('redis_pool', function()
  local redis_pool

  describe('acquire', function()
    describe('when there is an error resolving the redis hostname', function()
      setup(function()
        -- Mock the module that does the resolving and force an error
        package.loaded['threescale_utils'] = {
          resolve = function() error() end
        }

        -- Ignore everything related to resty.redis that is not needed to test
        -- this.
        local fake_redis_client = { set_timeout = function() end,
                                    connect = function() end }
        package.loaded['resty.redis'] = { new = function() return fake_redis_client end }

        redis_pool = require 'xc/redis_pool'
      end)

      it('returns error and the reason', function()
        local _, res_ok, error = redis_pool.acquire()
        assert.is_false(res_ok)
        assert.are.same(error, 'Failed to resolve redis hostname')
      end)
    end)
  end)
end)
