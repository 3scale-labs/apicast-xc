package = "apicast_xc"
version = "1.0.0"
source = {
  url = "https://github.com/3scale/apicast-xc.git",
  dir = "xc",
  branch = "master"
}
description = {
  summary = "XC for APIcast",
  detailed = [[
    This module caches calls to 3scale.
  ]],
  homepage = "https://github.com/3scale/apicast-xc",
  license = "Apache-2.0"
}
dependencies = {
  "lua >= 5.1",
  "redis-lua ~> 2.0.4"
}
build = {
  type = "builtin",
  modules = { ["apicast.xc"] = "apicast_xc.lua" }
}
