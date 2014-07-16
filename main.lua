local redis = require 'redis'

local red = redis.connect()

require 'split'

-- get app name
local app_name = ngx.var.uri:split('/')[2]
ngx.log(ngx.ERR, app_name)
if type(app_name) == 'nil' or app_name == '' then
    ngx.say("Invalid application name")
    ngx.exit(404)
end

-- get account name
local account_name = ngx.var.host:split('%.')[1]
ngx.log(ngx.ERR, account_name)
if type(app_name) == 'nil' or app_name == '' then
    ngx.say("Invalid account name")
    ngx.exit(404)
end

-- get random upstream in key (aka name)
local res, err = red:srandmember(account_name .. ":" .. app_name)
if res then
    if type(res) == 'string' then
        backend = res:split(',')
        backend_name = backend[1]
        backend_host = backend[2]
        backend_port = backend[3]
        ngx.req.set_header("X-Proxy-Cache-Hit", "true")
        ngx.req.set_header("X-Lucid-Account-Name", account_name)
        ngx.req.set_header("X-Lucid-App-Name", app_name)
        ngx.req.set_header("X-Proxy-Backend-Name", backend_name)
        ngx.req.set_header("X-Proxy-Backend-Host", backend_host)
        ngx.req.set_header("X-Proxy-Backend-Port", backend_port)
        ngx.var.upstream = backend_host .. ":" .. backend_port
        ngx.log(ngx.ERR, backend_host .. ":" .. backend_port)
    else
        ngx.req.set_header("X-Proxy-Cache-Hit", "false")
        ngx.req.set_header("X-Lucid-Account-Name", account_name)
        ngx.req.set_header("X-Lucid-App-Name", app_name)
    end
end
