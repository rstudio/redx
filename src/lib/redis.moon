M = {}

import escape_pattern from require "lapis.util"

split = (str, delim using nil) ->
  str ..= delim
  [part for part in str\gmatch "(.-)" .. escape_pattern delim]

M.connect = (@) ->
    -- connect to redis
    redis = require "resty.redis"
    red = redis\new()
    red\set_timeout(config.redis_timeout)
    ok, err = red\connect(config.redis_host, config.redis_port)
    unless ok
        print("Error connecting to redis: " .. err)
        @msg = "error connectiong: " .. err
        @status = 500
    else
        if type(config.redis_password) == 'string' and #config.redis_password > 0
            red\auth(config.redis_password)
        return red

M.finish = (red) ->
    if config.redis_keepalive_pool_size == 0
        ok, err = red\close!
    else
        ok, err = red\set_keepalive(config.redis_keepalive_max_idle_timeout, config.redis_keepalive_pool_size)
        unless ok
            print("failed to set keepalive: ", err)
            return

M.test = (@) ->
    red = M.connect(@)
    rand_value = tostring(math.random!)
    ok , err = red\set('healthcheck', rand_value)
    unless ok
        @status = 500
        @msg = "Failed to write to redis"
    ok, err = red\get('healthcheck')
    unless ok
        @status = 500
        @msg = "Failed to read redis"
    unless ok == rand_value
        @status = 500
        @msg = "Healthcheck failed to write and read from redis"
    ok, err = red\del('healthcheck')
    if ok
        @status = 200
        @msg = "OK"
    else
        @status = 500
        @msg = "Failed to delete key from redis"
    M.finish(red)

M.commit = (@, red, error_msg) ->
    -- commit the change
    results, err = red\commit_pipeline()
    if not results
        @msg = error_msg .. err
        @status = 500
    else
        @msg = "OK"
        @status = 200

M.flush = (@) ->
    red = M.connect(@)
    return nil if red == nil
    ok, err = red\flushdb()
    if ok
        @status = 200
        @msg = "OK"
    else
        @status = 500
        @msg = err
    M.finish(red)
 
M.get_data = (@, asset_type, asset_name) ->
    red = M.connect(@)
    return nil if red == nil
    switch asset_type
        when 'frontends'
            @resp, @msg = red\get('frontend:' .. asset_name)
            @status = 500 unless @resp
            if getmetatable(@resp) == nil
                @resp = nil
        when 'backends'
            @resp, @msg = red\smembers('backend:' .. asset_name)
            @resp = nil if type(@resp) == 'table' and table.getn(@resp) == 0
        else
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if @resp
        @status = 200
        @msg = "OK"
    if @resp == nil
        @status = 404
        @msg = "Entry does not exist"
    else
        @status = 500 unless @status
        @msg = 'Unknown failutre' unless @msg
    M.finish(red)

M.save_data = (@, asset_type, asset_name, asset_value, overwrite=false) ->
    red = M.connect(@)
    return nil if red == nil
    switch asset_type
        when 'frontends'
            ok, err = red\set('frontend:' .. asset_name, asset_value)
        when 'backends'
            red = M.connect(@)
            red\init_pipeline() if overwrite
            red\del('backend:' .. asset_name) if overwrite
            ok, err = red\sadd('backend:' .. asset_name, asset_value)
            M.commit(@, red, "Failed to save backend: ") if overwrite
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
    M.finish(red)

M.delete_data = (@, asset_type, asset_name, asset_value=nil) ->
    red = M.connect(@)
    return nil if red == nil
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
    M.finish(red)

M.save_batch_data = (@, data, overwrite=false) ->
    red = M.connect(@)
    return nil if red == nil
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            red\del('frontend:' .. frontend['url']) if overwrite
            unless frontend['backend_name'] == nil
                print('adding frontend: ' .. frontend['url'] .. ' ' .. frontend['backend_name'])
                red\set('frontend:' .. frontend['url'], frontend['backend_name'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if overwrite
            -- ensure servers are a table
            backend['servers'] = {backend['servers']} unless type(backend['servers']) == 'table'
            for server in *backend['servers']
                unless server == nil
                    print('adding backend: ' .. backend["name"] .. ' ' .. server)
                    red\sadd('backend:' .. backend["name"], server)
    M.commit(@, red, "failed to save data: ")
    M.finish(red)

M.delete_batch_data = (@, data) ->
    red = M.connect(@)
    return nil if red == nil
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            print('deleting frontend: ' .. frontend['url'])
            red\del('frontend:' .. frontend['url'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if backend['servers'] == nil
            if backend['servers']
                -- ensure servers are a table
                backend['servers'] = {backend['servers']} unless type(backend['servers']) == 'table'
                for server in *backend['servers']
                    unless server == nil
                        print('deleting backend: ' .. backend["name"] .. ' ' .. server)
                        red\srem('backend:' .. backend["name"], server)
    M.commit(@, red, "failed to save data: ")
    M.finish(red)

M.fetch_frontend = (@, max_path_length=3) ->
    path = @req.parsed_url['path']
    path_parts = split path, '/'
    keys = {}
    p = ''
    count = 0
    for k,v in pairs path_parts do
        unless v == nil or v == ''
            if count < (max_path_length)
                count += 1
                p = p .. "/#{v}"
                table.insert(keys, 1, @req.parsed_url['host'] .. p)
    red = M.connect(@)
    return nil if red == nil
    for key in *keys do
        resp, err = red\get('frontend:' .. key)
        if type(resp) == 'string'
            return { frontend_key: key, backend_key: resp }
    M.finish(red)
    return nil

M.fetch_server = (@, backend_key) ->
    red = M.connect(@)
    return nil if red == nil
    resp, err = red\srandmember('backend:' .. backend_key)
    print('Failed getting backend: ' .. err) unless err == nil
    M.finish(red)
    if type(resp) == 'string'
        return resp
    else
        return nil

return M
