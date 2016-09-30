describe('xc', function()
  describe('authrep', function()
    local xc
    local cache
    local priority_auths
    local service_id = 'a_service_id'
    local app_id = 'an_app_id'
    local method = 'a_method'
    local usage_val = 1
    local usage = { [method] = usage_val } -- just 1 metric for now

    setup(function()
      -- Use a mocked cache and priority auth rewener
      package.loaded['xc/cache'] = { authorize = nil, report = nil }
      cache = package.loaded['xc/cache']

      package.loaded['xc/priority_auths'] = { authorize = nil }
      priority_auths = package.loaded['xc/priority_auths']

      xc = require 'xc/xc'
    end)

    describe('when the authorization is obtained accessing the cache', function()
      describe('and it is authorized', function()
        setup(function()
          cache.authorize = function() return true, true end
        end)

        describe('and the report is successful', function()
          setup(function()
            cache.report = spy.new(function() return true end)
          end)

          it('returns ok and no errors', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.ok, res.auth)
            assert.is_nil(res.error)
          end)

          it('caches the reported usage', function()
            xc.authrep(service_id, app_id, usage)
            assert.spy(cache.report).was.called_with(
              service_id, app_id, method, usage_val)
          end)
        end)

        describe('and the report fails', function()
          setup(function()
            cache.report = function() return false end
          end)

          it('returns auth OK and a cache report error', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.ok, res.auth)
            assert.are.same(xc.error.cache_report_failed, res.error)
          end)
        end)
      end)

      describe('and it is denied', function()
        setup(function()
          cache.report = spy.new(function() return true end)
        end)

        describe('and a reason is not specified', function()
          setup(function()
            cache.authorize = function() return true, false end
          end)

          it('returns denied', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.denied, res.auth)
            assert.is_nil(res.error)
          end)

          it('does not cache the reported usage', function()
            xc.authrep(service_id, app_id, usage)
            assert.spy(cache.report).was.not_called()
          end)
        end)

        describe('and a reason is specified', function()
          local reason = 'a_deny_reason'

          setup(function()
            cache.authorize = function() return true, false, reason end
          end)

          it('returns denied and a the reason', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.denied, res.auth)
            assert.are.same(reason, res.reason)
            assert.is_nil(res.error)
          end)

          it('does not cache the reported usage', function()
            xc.authrep(service_id, app_id, usage)
            assert.spy(cache.report).was.not_called()
          end)
        end)
      end)
    end)

    describe('when the auth is not in the cache, but is got using the priority channel', function()
      setup(function()
        -- For these tests, the important thing is that the auth is unknown
        -- (nil). It does not matter if it is because the authorization is not
        -- cached or because the cache is not accessible. So the authorize
        -- method could return true, nil or false, nil
        cache.authorize = function() return true, nil end
      end)

      describe('and it is authorized', function()
        setup(function()
          priority_auths.authorize = function() return true, true end
        end)

        describe('and the report is successful', function()
          setup(function()
            cache.report = spy.new(function() return true end)
          end)

          it('returns ok and no errors', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.ok, res.auth)
            assert.is_nil(res.error)
          end)

          it('caches the reported usage', function()
            xc.authrep(service_id, app_id, usage)
            assert.spy(cache.report).was.called_with(
              service_id, app_id, method, usage_val)
          end)
        end)

        describe('and the report fails', function()
          setup(function()
            cache.report = spy.new(function() return false end)
          end)

          it('returns auth OK and a cache report error', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.ok, res.auth)
            assert.are.same(xc.error.cache_report_failed, res.error)
          end)
        end)
      end)

      describe('and it is denied', function()
        setup(function()
          priority_auths.authorize = function() return true, false end
          cache.report = spy.new(function() return true end)
        end)

        describe('and a reason is not specified', function()
          it('returns denied', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.denied, res.auth)
            assert.is_nil(res.error)
          end)

          it('does not cache the reported usage', function()
            xc.authrep(service_id, app_id, usage)
            assert.spy(cache.report).was.not_called()
          end)
        end)

        describe('and a reason is specified', function()
          local reason = 'a_deny_reason'

          setup(function()
            priority_auths.authorize = function() return true, false, reason end
          end)

          it('returns denied and a the reason', function()
            local res = xc.authrep(service_id, app_id, usage)
            assert.are.same(xc.auth.denied, res.auth)
            assert.are.same(reason, res.reason)
            assert.is_nil(res.error)
          end)

          it('does not cache the reported usage', function()
            xc.authrep(service_id, app_id, usage)
            assert.spy(cache.report).was.not_called()
          end)
        end)
      end)
    end)

    -- In this case, we tried to get the auth from the cache and the renewer,
    -- but both failed.
    describe('when we cannot determine whether the call is authorized', function()
      setup(function()
        priority_auths.authorize = function() return false, nil end
        cache.report = spy.new(function() return true end)
      end)

      describe('and the auth was not cached', function()
        setup(function()
          cache.authorize = function() return true, nil end
        end)

        it('returns auth unknown and a cache auth error', function()
          local res = xc.authrep(service_id, app_id, usage)
          assert.are.same(xc.auth.unknown, res.auth)
          assert.are.same(xc.error.cache_auth_failed, res.error)
        end)

        it('does not cache the reported usage', function()
          xc.authrep(service_id, app_id, usage)
          assert.spy(cache.report).was.not_called()
        end)
      end)

      describe('and the cache was not accessible', function()
        setup(function()
          cache.authorize = function() return false, nil end
        end)

        it('returns auth unknown and a cache auth error', function()
          local res = xc.authrep(service_id, app_id, usage)
          assert.are.same(xc.auth.unknown, res.auth)
          assert.are.same(xc.error.cache_auth_failed, res.error)
        end)

        it('does not cache the reported usage', function()
          xc.authrep(service_id, app_id, usage)
          assert.spy(cache.report).was.not_called()
        end)
      end)
    end)
  end)
end)
