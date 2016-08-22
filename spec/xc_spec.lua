describe('xc', function()
  describe('authrep', function()
    local xc
    local cache
    local service_id = 'a_service_id'
    local app_id = 'an_app_id'
    local method = 'a_method'
    local usage_val = 1
    local usage = { [method] = usage_val } -- just 1 metric for now

    setup(function()
      -- Use a mocked cache.
      package.loaded['xc/cache'] = { authorize = nil, report = nil }
      cache = package.loaded['xc/cache']
      xc = require 'xc/xc'
    end)

    describe('when the call is authorized', function()
      setup(function()
        cache.authorize = function() return true, true end
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

    describe('when the call is not authorized', function()
      setup(function()
        cache.authorize = function() return false, true end
        cache.report = spy.new(function() return true end)
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

    describe('when we cannot determine whether the call is authorized', function()
      setup(function()
        cache.authorize = function() return nil, true end
        cache.report = spy.new(function() return true end)
      end)

      it('returns unknown', function()
        local res = xc.authrep(service_id, app_id, usage)
        assert.are.same(xc.auth.unknown, res.auth)
        assert.is_nil(res.error)
      end)

      it('does not cache the reported usage', function()
        xc.authrep(service_id, app_id, usage)
        assert.spy(cache.report).was.not_called()
      end)
    end)

    describe('when checking the authorization in the cache fails', function()
      setup(function()
        cache.authorize = function() return nil, false end
      end)

      it('returns auth unknown and a cache auth error', function()
        local res = xc.authrep(service_id, app_id, usage)
        assert.are.same(xc.auth.unknown, res.auth)
        assert.are.same(xc.error.cache_auth_failed, res.error)
      end)
    end)

    describe('when checking auth in the cache succeeds but reporting the usage fails', function()
      setup(function()
        cache.authorize = function() return true, true end
        cache.report = function() return false end
      end)

      it('returns auth OK and a cache report error', function()
        local res = xc.authrep(service_id, app_id, usage)
        assert.are.same(xc.auth.ok, res.auth)
        assert.are.same(xc.error.cache_report_failed, res.error)
      end)
    end)
  end)
end)
