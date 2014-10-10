M = {}

import escape_pattern from require "lapis.util"

M.log = (msg) ->
    ngx.log ngx.NOTICE, msg

M.log_err = (msg) ->
    ngx.log ngx.ERR, msg

M.split = (str, delim using nil) ->
  str ..= delim
  [part for part in str\gmatch "(.-)" .. escape_pattern delim]

M.length = (dict) ->
    count = 0
    for k,v in pairs dict
        count += 1
    return count

M.Set = (list) ->
  set = {}
  for _, l in ipairs(list) do
    set[l] = true
  return set

M.multirequest = (reqs) ->
  return { ngx.location.capture_multi(reqs) }

return M
