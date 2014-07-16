local redis = require 'redis'

local red = redis.connect()

local name = ngx.var.uri:gsub('/','')
local args = ngx.req.get_uri_args()

-- get backends (enforce backends is always a table)
local backends = {}
if type(args['backend']) == 'table' then
    for key,val in pairs(args['backend']) do
        ngx.log(ngx.ERR, "Add " .. val)
        table.insert(backends, val)
    end
elseif type(args['backend']) == 'nil' then
    -- do nothing
else
    ngx.log(ngx.ERR, "Add " .. args['backend'])
    table.insert(backends, args['backend'])
end

local reqType = ngx.req.get_method()

if reqType == "GET" then
    ngx.log(ngx.ERR, "GET REQUEST")
    -- Test if key exists
    local res, err = red:exists(name)
    if not res then
        ngx.say("failed to get key: ", err)
        ngx.exit(500)
    elseif res == "0" then
        ngx.exit(404)
    end

    if type(args['random']) == 'nil' then
        args['random'] = 'false'
    end
    if args['random']:lower() == 'true' or args['random'] == "1" then
        -- get random upstream in key (aka name)
        local res, err = red:srandmember(name)
        if not res then
            ngx.say("failed to get upstream: ", err)
            ngx.exit(500)
        else
            ngx.say(res)
            ngx.exit(200)
        end
    else
        -- get all upstreams in key (aka name)
        local res, err = red:smembers(name)
        if not res then
            ngx.say("failed to get upstream: ", err)
            ngx.exit(500)
        else
            for i, upstream in ipairs(res) do
                ngx.say(upstream)
            end
            ngx.exit(200)
        end
    end
elseif reqType == "POST" then
    ngx.log(ngx.ERR, "POST REQUEST")
    red:init_pipeline()
    for i,backend in pairs(backends) do
        ngx.log(ngx.ERR, 'adding backend: ' .. backend)
        red:sadd(name, backend)
    end
    local results, err = red:commit_pipeline()
    if not results then
        ngx.say("failed to commit the pipelined requests: ", err)
        ngx.exit(500)
    else
        ngx.say("OK")
        ngx.exit(200)
    end
elseif reqType == "PUT" then
    ngx.log(ngx.ERR, "PUT REQUEST")
    red:init_pipeline()
    red:del(name)
    for i, backend in pairs(backends) do
        ngx.log(ngx.ERR, 'adding backend: ' .. backend)
        red:sadd(name, backend)
    end
    -- commit the change
    local results, err = red:commit_pipeline()
    if not results then
        ngx.say("failed to commit the pipelined requests: ", err)
        ngx.exit(500)
    else
        ngx.say("OK")
        ngx.exit(200)
    end
elseif reqType == "DELETE" then
    ngx.log(ngx.ERR, "DELETE REQUEST")

    -- Test if key exists
    local res, err = red:exists(name)
    if not res then
        ngx.say("failed to get key: ", err)
        ngx.exit(500)
    elseif res == "0" then
        ngx.say("OK")
        ngx.exit(200)
        return
    end

    if next (backends) == nil then
        ngx.log(ngx.ERR, 'deleting ' .. name)
        ok, err = red:del(name)
        if not ok then
            ngx.say("failed to delete redis key: ", err)
            ngx.exit(500)
        else
            ngx.say("OK")
            ngx.exit(200)
        end
    else
        red:init_pipeline()
        for i, backend in pairs(backends) do
            ngx.log(ngx.ERR, 'deleting ' .. backend)
            red:srem(name, backend)
        end
        -- commit the change
        local results, err = red:commit_pipeline()
        if not results then
            ngx.say("failed to commit the pipelined requests: ", err)
            ngx.exit(500)
        else
            ngx.say("OK")
            ngx.exit(200)
        end
    end
else
    ngx.log(ngx.ERR, "INVALID REQUEST")
    ngx.say("Invalid request")
    ngx.exit(500)
end
