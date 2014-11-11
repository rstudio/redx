M = {}

import escape_pattern from require "lapis.util"

M.log = (msg) ->
    ngx.log ngx.NOTICE, inspect(msg)

M.log_err = (msg) ->
    ngx.log ngx.ERR, inspect(msg)

M.split = (str, delim using nil) ->
  str ..= delim
  [part for part in str\gmatch "(.-)" .. escape_pattern delim]

M.set = (list) ->
  set = {}
  for _, l in ipairs(list) do
    set[l] = true
  return set

return M
