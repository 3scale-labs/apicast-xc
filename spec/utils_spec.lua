describe('utils', function()
  local utils = require 'xc/utils'

  describe('parse_apicast_creds', function()
    it('returns a table with keys(3scale creds: app_id, app_key, etc.) and their values',
      function()
        local app_id = 'an_app_id'
        local app_key = 'an_app_key'
        local apicast_creds = { app_id, app_key,
                                app_id = app_id, app_key = app_key }

        assert.are.same({ app_id = app_id, app_key = app_key },
                        utils.parse_apicast_creds(apicast_creds))
      end)
  end)

end)
