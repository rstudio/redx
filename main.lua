local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(1000)
local ok, err = red:connect('127.0.0.1', 6379)
if not ok then
    ngx.say("Failed to connect to Redis: ", err)
    ngx.exit(500)
end

function string:split(delimiter)
  local result = { }
  local from = 1
  local delim_from, delim_to = string.find( self, delimiter, from )

  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from )
  end

  table.insert( result, string.sub( self, from ) )

  return result
end

-- get app name
local app_name = ngx.var.uri:split('/')[2]
ngx.log(ngx.ERR, app_name)

-- get account name
local account_name = ngx.var.host:split('%.')[1]
ngx.log(ngx.ERR, account_name)

-- get random upstream in key (aka name)
local res, err = red:srandmember(account_name .. "_" .. app_name)
if res then
    if type(res) == 'string' then
        backend = res:split(',')
        backend_name = backend[1]
        backend_host = backend[2]
        backend_port = backend[3]
        ngx.header["X-Proxy-Cache-Hit"] = "true"
        ngx.header["X-Proxy-Backend-Name"] =  backend_name
        ngx.header["X-Proxy-Backend-Host"] =  backend_host
        ngx.header["X-Proxy-Backend-Port"] =  backend_port
        ngx.header["X-Lucid-Account-Name"] = account_name
        ngx.header["X-Proxy-App-Name"] = app_name
        ngx.var.upstream = backend_host .. ":" .. backend_port
    else
        ngx.header["X-Proxy-Cache-Hit"] = "false"
        ngx.header["X-Lucid-Account-Name"] = account_name
        ngx.header["X-Proxy-App-Name"] = app_name
    end
    ngx.print()
end
