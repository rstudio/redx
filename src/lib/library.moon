M = {}

import escape_pattern from require "lapis.util"

M.log = (msg) ->
    ngx.log ngx.NOTICE, msg

M.log_err = (msg) ->
    ngx.log ngx.ERR, msg

M.split = (str, delim using nil) ->
  str ..= delim
  [part for part in str\gmatch "(.-)" .. escape_pattern delim]

return M
