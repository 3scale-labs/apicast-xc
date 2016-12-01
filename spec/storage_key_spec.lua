describe('storage_keys', function()
  local storage_keys = require 'xc/storage_keys'

  local auth_responses_channel_prefix = 'xc_channel_auth_response:'

  describe('get_auth_key', function()
    local service_id = 'a_service_id'

    describe('when only one credential is specified', function()
      local credential_name = 'user_key'
      local credentials = { [credential_name] = 'a_user_key' }

      it('returns the key with the expected format', function()
        local expected = 'auth,' ..
            'service_id:' .. service_id .. ',' ..
            credential_name .. ':' .. credentials[credential_name]
        local actual = storage_keys.get_auth_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when several credentials are specified', function()
      local credential_1 = 'credential_1'
      local credential_2 = 'credential_2'
      local credential_3 = 'credential_3'
      local credentials = { [credential_2] = 'second',
                            [credential_1] = 'first',
                            [credential_3] = 'third' }

      it('returns the key with the expected format', function()
        local expected = 'auth,' ..
            'service_id:' .. service_id .. ',' ..
            credential_1 .. ':' .. credentials[credential_1] .. ',' ..
            credential_2 .. ':' .. credentials[credential_2] .. ',' ..
            credential_3 .. ':' .. credentials[credential_3]
        local actual = storage_keys.get_auth_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when some field contains characters that need to be escaped', function()
      local cred = 'user_key'

      -- ':' and ',' should be escaped
      local credentials = { [cred] = 'a:user,key' }

      it('returns the key with the expected format', function()
        local expected = 'auth,' ..
            'service_id:' .. service_id .. ',' ..
            cred .. ':' .. credentials[cred]:gsub(':', '\\:'):gsub(',', '\\,')
        local actual = storage_keys.get_auth_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)
  end)

  describe('get_report_key', function()
    local service_id = 'a_service_id'

    describe('when only one credential is specified', function()
      local credential_name = 'user_key'
      local credentials = { [credential_name] = 'a_user_key' }

      it('returns the key with the expected format', function()
        local expected = 'report,' ..
            'service_id:' .. service_id .. ',' ..
            credential_name .. ':' .. credentials[credential_name]
        local actual = storage_keys.get_report_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when several credentials are specified', function()
      local credential_1 = 'app_id'
      local credential_2 = 'user_id'
      local credentials = { [credential_2] = 'an_app_key',
                            [credential_1] = 'a_user_id' }

      it('returns the key with the expected format', function()
        local expected = 'report,' ..
            'service_id:' .. service_id .. ',' ..
            credential_1 .. ':' .. credentials[credential_1] .. ',' ..
            credential_2 .. ':' .. credentials[credential_2]
        local actual = storage_keys.get_report_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when some field contains characters that need to be escaped', function()
      local cred = 'user_key'

      -- ':' and ',' should be escaped
      local credentials = { [cred] = 'a:user,key' }

      it('returns the key with the expected format', function()
        local expected = 'report,' ..
            'service_id:' .. service_id .. ',' ..
            cred .. ':' .. credentials[cred]:gsub(':', '\\:'):gsub(',', '\\,')
        local actual = storage_keys.get_report_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)

    describe('and credentials contains some that are not needed', function()
      local credential_name = 'user_key'
      local not_needed_1 = 'not_needed_1'
      local not_needed_2 = 'not_needed_2'
      local credentials = { [credential_name] = 'a_user_key',
                            [not_needed_1] = 'not_needed_1',
                            [not_needed_2] = 'not_needed_2' }

      it('returns the key with the expected format', function()
        local expected = 'report,' ..
            'service_id:' .. service_id .. ',' ..
            credential_name .. ':' .. credentials[credential_name]
        local actual = storage_keys.get_report_key(service_id, credentials)
        assert.are.same(expected, actual)
      end)
    end)
  end)

  describe('get_pubsub_req_msg', function()
    local service_id = 'a_service_id'
    local metric = 'a_metric'

    describe('when only one credential is specified', function()
      local cred = 'user_key'
      local credentials = { [cred] = 'a_user_key' }

      it('returns the message with the expected format', function()
        local expected = 'service_id:' .. service_id .. ',' ..
            cred .. ':' .. credentials[cred] .. ',' ..
            'metric:' .. metric
        local actual = storage_keys.get_pubsub_req_msg(service_id, credentials, metric)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when several credentials are specified', function()
      local credential_1 = 'credential_1'
      local credential_2 = 'credential_2'
      local credential_3 = 'credential_3'
      local credentials = { [credential_2] = 'second',
                            [credential_1] = 'first',
                            [credential_3] = 'third' }

      it('returns the message with the expected format', function()
        local expected = 'service_id:' .. service_id .. ',' ..
            credential_1 .. ':' .. credentials[credential_1] .. ',' ..
            credential_2 .. ':' .. credentials[credential_2] .. ',' ..
            credential_3 .. ':' .. credentials[credential_3] .. ',' ..
            'metric:' .. metric
        local actual = storage_keys.get_pubsub_req_msg(service_id, credentials, metric)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when some field contains characters that need to be escaped', function()
      local cred = 'user_key'

      -- ':' and ',' should be escaped
      local credentials = { [cred] = 'a:user,key' }

      it('returns the message with the expected format', function()
        local expected = 'service_id:' .. service_id .. ',' ..
            cred .. ':' .. credentials[cred]:gsub(':', '\\:'):gsub(',', '\\,') .. ',' ..
            'metric:' .. metric
        local actual = storage_keys.get_pubsub_req_msg(service_id, credentials, metric)
        assert.are.same(expected, actual)
      end)
    end)
  end)

  describe('get_pubsub_auths_resp_channel', function()
    local service_id = 'a_service_id'
    local metric = 'a_metric'

    describe('when only one credential is specified', function()
      local cred = 'user_key'
      local credentials = { [cred] = 'a_user_key' }

      it('returns the channel with the expected format', function()
        local expected = auth_responses_channel_prefix ..
            'service_id:' .. service_id .. ',' ..
            cred .. ':' .. credentials[cred] .. ',' ..
            'metric:' .. metric
        local actual = storage_keys.get_pubsub_auths_resp_channel(
          service_id, credentials, metric)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when several credentials are specified', function()
      local credential_1 = 'credential_1'
      local credential_2 = 'credential_2'
      local credential_3 = 'credential_3'
      local credentials = { [credential_2] = 'second',
                            [credential_1] = 'first',
                            [credential_3] = 'third' }

      it('returns the channel with the expected format', function()
        local expected = auth_responses_channel_prefix ..
            'service_id:' .. service_id .. ',' ..
            credential_1 .. ':' .. credentials[credential_1] .. ',' ..
            credential_2 .. ':' .. credentials[credential_2] .. ',' ..
            credential_3 .. ':' .. credentials[credential_3] .. ',' ..
            'metric:' .. metric
        local actual = storage_keys.get_pubsub_auths_resp_channel(
          service_id, credentials, metric)
        assert.are.same(expected, actual)
      end)
    end)

    describe('when some field contains characters that need to be escaped', function()
      local cred = 'user_key'

      -- ':' and ',' should be escaped
      local credentials = { [cred] = 'a:user,key' }

      it('returns the channel with the expected format', function()
        local expected = auth_responses_channel_prefix ..
            'service_id:' .. service_id .. ',' ..
            cred .. ':' .. credentials[cred]:gsub(':', '\\:'):gsub(',', '\\,') .. ',' ..
            'metric:' .. metric
        local actual = storage_keys.get_pubsub_auths_resp_channel(
          service_id, credentials, metric)
        assert.are.same(expected, actual)
      end)
    end)
  end)
end)
