local _M = { }

-- Receives an auth value as represented in the storage and extracts the auth
-- status(authorized, denied, unknown) and the deny reason (when specified).
-- @return true if authorized, false if denied, nil if unknown
-- @return reason why the authorization is denied (optional, required only when denied)
function _M.authorization(storage_value)
  -- We need to check the type, storage_value can be ngx.null. lua-resty-redis
  -- returns ngx.null when the key does not exist. It returns nil in case of
  -- error. Either way, the authorization status is unknown.

  if type(storage_value) ~= 'string' then
    return nil, nil
  end

  local auth, reason

  -- auth is nil. We only need to set it if the authorization is cached and
  -- it has a valid value.

  local first_char = storage_value:sub(1, 1)

  if first_char == '0' then
    auth = false
    if storage_value:len() >= 3 then
      reason = storage_value:sub(3, -1)
    end
  elseif first_char == '1' then
    auth = true
  end

  return auth, reason
end

return _M
