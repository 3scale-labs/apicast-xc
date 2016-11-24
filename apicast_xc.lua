local xc = require 'xc/xc'

local _M = require 'apicast'

function _M.access()
  local request = ngx.var.request
  local service = ngx.ctx.service
  local credentials = service:extract_credentials(request)
  local usage = service:extract_usage(request)
  local auth_status = xc.authrep(service.id, credentials, usage)

  if auth_status.auth ~= xc.auth.ok then
    ngx.exit(403)
  end

  -- TODO: For now, exiting with 403 is good enough. However, in auth_status we
  -- have some information that can help us to have a more sophisticated error
  -- handling. if the authorization is not ok, it could be denied or unkown
  -- (meaning that there was an error accessing the cache). We could treat
  -- those cases differently.
end

-- Override methods implemented in Apicast that are not needed in XC
_M.header_filter = function() end
_M.body_filter = function() end
_M.post_action = function() end

return _M
