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

-- define response function
M.response = (t) ->
    -- close redis connection
    redis.finish(t['redis']) if t['redis']

    -- setup defaults
    response = status: 500, json: { message: "Unknown failure" }

    response['status'] = t['status'] if t['status']
    response['json']['message'] = t['msg'] if t['msg']
    response['json']['data'] = t['data'] if t['data']

    -- if a msg wasn't given and the status code is successful (ie 200's), assume msg is "OK"
    response['json']['message'] = "OK" if t['msg'] == nil and response['status'] < 300
    response['json']['message'] = "Entry does not exist" if t['msg'] == nil and response['status'] == 404

    -- log if theres a failure
    library.log_err(response) if response['status'] >= 300
    return response

return M
