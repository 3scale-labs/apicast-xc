package = "xc"
version = "0.1.0-1"
source = {
  url = "https://github.com/3scale/apicast-xc.git",
  dir = "xc",
  branch = "master"
}
description = {
  summary = "XC for Apicast",
  detailed = [[
    This module caches calls to 3scale.
  ]],
  homepage = "https://github.com/3scale/apicast-xc"
}
dependencies = {
  "lua >= 5.1",
  "redis-lua ~> 2.0.4"
}
build = {
  type = "builtin"
}
