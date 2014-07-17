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

-- save a table of frontends/backends to redis
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
                ngx.log(ngx.ERR, 'adding frontend: ' .. frontend["name"] .. ' ' .. frontend['backend'])
                red:set('frontend:' .. frontend['name'], frontend['backend'])
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
        redis.commit(red, "failed to save data:")
    end
end

-- delete a table of frontends/backends to redis
delete_data = function(red, body)
    if body == nil then
        ngx.say('Must supply a json body')
        ngx.exit(400)
    else
        body = cjson.decode(body)
        red:init_pipeline()
        if body["frontends"] then
            for key1,frontend in pairs(body['frontends']) do
                red:del('frontend:' .. frontend['name'])
            end
        end
        if body["backends"] then
            for key1,backend in pairs(body['backends']) do
                if table.getn(backend["hosts"]) == 0 then
                    ngx.log(ngx.ERR, 'removing backend: ' .. backend["name"])
                    red:del('backend:' .. backend["name"])
                else
                    for key2,host in pairs(backend["hosts"]) do
                        ngx.log(ngx.ERR, 'removing backend: ' .. backend["name"] .. ' ' .. host)
                        red:srem('backend:' .. backend["name"], host)
                    end
                end
            end
        end
        redis.commit(red, "failed to delete data:")
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
    delete_data(red, body)
else
    ngx.log(ngx.ERR, "INVALID REQUEST")
    ngx.say("Invalid request")
    ngx.exit(500)
end
