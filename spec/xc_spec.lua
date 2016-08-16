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
      -- Spy on report.cache. It is going to be the same for all the tests.
      package.loaded.cache = {
        report = spy.new(function() return true end)
      }
      cache = package.loaded.cache
    end)

    before_each(function()
      cache.report:clear()
    end)

    describe('when the call is authorized', function()
      setup(function()
        cache.authorize = function() return true, true end
        xc = require 'xc'
      end)

      it('returns ok', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.ok, res_auth)
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
        xc = require 'xc'
      end)

      it('returns denied', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.denied, res_auth)
      end)

      it('does not cache the reported usage', function()
        xc.authrep(service_id, app_id, usage)
        assert.spy(cache.report).was.not_called()
      end)
    end)

    describe('when we cannot determine whether the call is authorized', function()
      setup(function()
        cache.authorize = function() return nil, true end
        xc = require 'xc'
      end)

      it('returns unknown', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.unknown, res_auth)
      end)

      it('does not cache the reported usage', function()
        xc.authrep(service_id, app_id, usage)
        assert.spy(cache.report).was.not_called()
      end)
    end)
  end)
end)
