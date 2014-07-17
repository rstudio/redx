local red = redis.connect()

local name = ngx.var.uri:gsub('/','')
local args = ngx.req.get_uri_args()
ngx.req.read_body()
local body = ngx.req.get_body_data()
if type(body) ~= 'nil' then
    local body = cjson.decode(body)
end

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

save_data = function(red, body, overwrite)
    if body == nil then
        ngx.say('Must supply a json body')
        ngx.exit(400)
    else
        body = cjson.decode(body)
        red:init_pipeline()
        if body["frontends"] then
            for key1,frontend in pairs(body['frontends']) do
                if overwrite then
                    red:del('frontend:' .. frontend['name'])
                end
                for key2,backend in pairs(frontend['backends']) do
                    ngx.log(ngx.ERR, 'adding frontend: ' .. frontend["name"] .. ' ' .. backend)
                    red:sadd('frontend:' .. frontend['name'], backend)
                end
            end
        end
        if body["backends"] then
            for key1,backend in pairs(body['backends']) do
                if overwrite then
                    red:del('backend:' .. backend["name"])
                end
                for key2,host in pairs(backend["hosts"]) do
                    ngx.log(ngx.ERR, 'adding backend: ' .. backend["name"] .. ' ' .. host)
                    red:sadd('backend:' .. backend["name"], host)
                end
            end
        end
        redis.commit(red, "failed to commit the pipelined requests:")
    end
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
    save_data(red, body, false)
elseif reqType == "PUT" then
    ngx.log(ngx.ERR, "PUT REQUEST")
    save_data(red, body, true)
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
        redis.commit(red, "failed to commit the pipelined requests:")
    end
else
    ngx.log(ngx.ERR, "INVALID REQUEST")
    ngx.say("Invalid request")
    ngx.exit(500)
end
