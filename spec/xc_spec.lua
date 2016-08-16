describe('xc', function()
  describe('authrep', function()
    local xc
    local service_id = 'a_service_id'
    local app_id = 'an_app_id'
    local usage = { a_method = 1 } -- just 1 metric for now

    before_each(function()
      -- We need to force a require of xc on each test. This is needed because
      -- we want to require a different 'cache' mock depending on the test.
      package.loaded.xc = nil
    end)

    describe('when the call is authorized', function()
      setup(function()
        package.loaded.cache = { authorize = function() return true, true end }
        xc = require 'xc'
      end)

      it('returns ok', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.ok, res_auth)
      end)
    end)

    describe('when the call is not authorized', function()
      setup(function()
        package.loaded.cache = { authorize = function() return false, true end }
        xc = require 'xc'
      end)

      it('returns denied', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.denied, res_auth)
      end)
    end)

    describe('when we cannot determine whether the call is authorized', function()
      setup(function()
        package.loaded.cache = { authorize = function() return nil, true end }
        xc = require 'xc'
      end)

      it('returns unknown', function()
        local res_auth = xc.authrep(service_id, app_id, usage).auth
        assert.are.equals(xc.auth.unknown, res_auth)
      end)
    end)
  end)
end)
