local _M = { }

-- The Apicast method that extracts the credentials from a request returns a
-- table that includes the credential values, and also key - values where the
-- keys represent credentials. So for example, a table that contains both
-- an app_id and an app_key looks like this:
-- { 'my_app_id', 'my_app_key', app_id = 'my_app_id', app_key = 'my_app_key' }
-- For XC, we are only interested in the key values, and that's what this
-- method returns.
function _M.parse_apicast_creds(creds)
  for i = 1, #creds do
    creds[i] = nil
  end

  return creds
end

return _M
