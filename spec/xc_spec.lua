-- Mock the redis pool. For testing, we'll use redis-lua instead of resty.redis
package.loaded.redis_pool = {
  acquire = function() return nil, true end,
  release = function() return true end
}

local xc = require 'xc'

describe('xc', function()
  describe('authrep', function()
    it('returns auth ok', function()
      local res_auth = xc.authrep('a_service_id', 'an_app_id', { a_method = 1 }).auth
      assert.are.equals(xc.auth.ok, res_auth)
    end)
  end)
end)
