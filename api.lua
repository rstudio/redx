-- Connect to Redis
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(1000)
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("Failed to connect to Redis: ", err)
    return
end

name = ngx.var.uri:gsub('/','')
ngx.log(ngx.ERR, "Requested Asset: " .. name)
args = ngx.req.get_uri_args()
host = args['host']
port = args['port']

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

    if args['random']:lower() == 'true' or args['random'] == "1" then
        -- get random upstream in key (aka name)
        local res, err = red:srandmember(name)
        if not res then
            ngx.say("failed to get upstream: ", err)
            ngx.exit(500)
        else
            ngx.say(res)
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
        end
    end
elseif reqType == "POST" then
    ngx.log(ngx.ERR, "POST REQUEST")
    red:init_pipeline()
    red:sadd(name, host .. ":" .. port)
    local results, err = red:commit_pipeline()
    if not results then
        ngx.say("failed to commit the pipelined requests: ", err)
        ngx.exit(500)
    else
        ngx.say("OK")
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

    if not host and not port then
        ngx.log(ngx.ERR, 'deleting ' .. name)
        red:init_pipeline()
        red:del(name)
        local results, err = red:commit_pipeline()
        if not results then
            ngx.say("failed to commit the pipelined requests: ", err)
            return
        else
            ngx.say("OK")
        end
    elseif host and port then
        ngx.log(ngx.ERR, 'deleting ' .. name .. "|" .. host .. ":" .. port)

        red:init_pipeline()
        red:srem(name, host .. ":" .. port)
        -- commit the change
        local results, err = red:commit_pipeline()
        if not results then
            ngx.say("failed to commit the pipelined requests: ", err)
            return
        else
            ngx.say("OK")
        end
    end
else
    ngx.log(ngx.ERR, "INVALID REQUEST")
    ngx.say("Invalid request")
end

