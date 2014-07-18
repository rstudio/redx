M = {}

export inspect = require('inspect')
require 'split'

M.connect = (@) ->
    -- connect to redis
    redis = require "resty.redis"
    red = redis\new()
    red\set_timeout(20000)
    red\set_keepalive(20000)
    ok, err = red\connect(config.redis_host, config.redis_port)
    if not ok
        print("Error connecting to redis: " .. err)
        @msg = "error connectiong: " .. err
        @status = 500
    else
        print('Connected to redis')
        return red

M.commit = (@, red, error_msg) ->
    -- commit the change
    results, err = red\commit_pipeline()
    if not results
        @msg = error_msg .. err
        @status = 500
    else
        @msg = "OK"
        @status = 404

M.get_data = (@, asset_type, asset_name) ->
    red = redis.connect(@)
    switch asset_type
        when 'frontends'
            @resp, @msg = red\get('frontend:' .. asset_name)
            @status = 500 unless @resp
        when 'backends'
            @resp, @msg = red\smembers('backend:' .. asset_name)
        else
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if @resp
        @resp = nil if type(@resp) == 'table' and table.getn(@resp) == 0
        @status = 200
        @msg = "OK"
    else
        @status = 500 unless @status
        @msg = 'Unknown failutre' unless @msg

M.save_data = (@, asset_type, asset_name, asset_value, overwrite=false) ->
    red = redis.connect(@)
    switch asset_type
        when 'frontends'
            ok, err = red\set('frontend:' .. asset_name, asset_value)
        when 'backends'
            red = redis.connect(@)
            red\init_pipeline() if overwrite
            red\del('backend:' .. asset_name) if overwrite
            ok, err = red\sadd('backend:' .. asset_name, asset_value)
            redis.commit(@, red, "Failed to save backend: ") if overwrite
        else
            ok = false
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if ok == nil
        @status = 200
        @msg = "OK"
    else
        @status = 500
        err = "unknown" if err == nil
        @msg = "Failed to save backend: " .. err

M.delete_data = (@, asset_type, asset_name, asset_value=nil) ->
    red = redis.connect(@)
    switch asset_type
        when 'frontends'
            resp, @msg = red\del('frontend:' .. asset_name)
            @status = 500 unless @resp
        when 'backends'
            if asset_value == nil
                resp, @msg = red\del('backend:' .. asset_name)
            else
                resp, @msg = red\srem('backend:' .. asset_name, asset_value)
        else
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if resp == nil
        @resp = nil if type(@resp) == 'table' and table.getn(@resp) == 0
        @status = 200
        @msg = "OK" unless @msg
    else
        @status = 500 unless @status
        @msg = 'Unknown failutre' unless @msg

M.save_batch_data = (@, data, overwrite=false) ->
    red = redis.connect(@)
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            print(inspect(frontend))
            red\del('frontend:' .. frontend['url']) if overwrite
            unless frontend['backend_name'] == nil
                print('adding frontend: ' .. frontend['url'] .. ' ' .. frontend['backend_name'])
                red\set('frontend:' .. frontend['url'], frontend['backend_name'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if overwrite
            -- ensure upstreams are a table
            backend['upstreams'] = {backend['upstreams']} unless type(backend['upstreams']) == 'table'
            for upstream in *backend['upstreams']
                unless upstream == nil
                    print('adding backend: ' .. backend["name"] .. ' ' .. upstream)
                    red\sadd('backend:' .. backend["name"], upstream)
    redis.commit(@, red, "failed to save data: ")

M.delete_batch_data = (@, data) ->
    red = redis.connect(@)
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            print('deleting frontend: ' .. frontend['url'])
            red\del('frontend:' .. frontend['url'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if backend['upstreams'] == nil
            if backend['upstreams']
                -- ensure upstreams are a table
                backend['upstreams'] = {backend['upstreams']} unless type(backend['upstreams']) == 'table'
                for upstream in *backend['upstreams']
                    unless upstream == nil
                        print('deleting backend: ' .. backend["name"] .. ' ' .. upstream)
                        red\srem('backend:' .. backend["name"], upstream)
    redis.commit(@, red, "failed to save data: ")

M.fetch_frontend = (@, max_path_length=3) ->
    path = @req.parsed_url['path']
    path_parts = path\split('/')
    keys = {}
    p = ''
    count = 0
    for k,v in pairs path_parts do
        unless v == nil or v == ''
            if count < (max_path_length)
                count += 1
                p = p .. "/#{v}"
                table.insert(keys, 1, @req.parsed_url['host'] .. p)
    red = redis.connect(@)
    for key in *keys do
        resp, err = red\get('frontend:' .. key)
        if type(resp) == 'string'
            return { frontend_key: key, backend_key: resp }
    return nil

M.fetch_upstream = (@, backend_key) ->
    red = redis.connect(@)
    resp, err = red\srandmember('backend:' .. backend_key)
    print('Failed getting backend: ' .. err) unless err == nil
    if type(resp) == 'string'
        return resp
    else
        return nil

return M
