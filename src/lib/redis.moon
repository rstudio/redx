M = {}

M.connect = (@) ->
    -- connect to redis
    redis = require "resty.redis"
    red = redis\new()
    red\set_timeout(config.redis_timeout)
    ok, err = red\connect(config.redis_host, config.redis_port)
    unless ok
        library\log_err("Error connecting to redis: " .. err)
        @msg = "error connectiong: " .. err
        @status = 500
    else
        library.log("Connected to redis")
        if type(config.redis_password) == 'string' and #config.redis_password > 0
            library.log("Authenticated with redis")
            red\auth(config.redis_password)
        return red

M.finish = (red) ->
    if config.redis_keepalive_pool_size == 0
        ok, err = red\close!
    else
        ok, err = red\set_keepalive(config.redis_keepalive_max_idle_timeout, config.redis_keepalive_pool_size)
        unless ok
            library.log_err("failed to set keepalive: ", err)
            return

M.test = (@) ->
    red = M.connect(@)
    rand_value = tostring(math.random!)
    key = "healthcheck:" .. rand_value
    ok , err = red\set(key, rand_value)
    unless ok
        @status = 500
        @msg = "Failed to write to redis"
    ok, err = red\get(key)
    unless ok
        @status = 500
        @msg = "Failed to read redis"
    unless ok == rand_value
        @status = 500
        @msg = "Healthcheck failed to write and read from redis"
    ok, err = red\del(key)
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
        library.log_err(error_msg .. err)
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
        library.log_err(err)
    M.finish(red)

M.get_config = (@, asset_name, config) ->
    red = M.connect(@)
    return nil if red == nil
    config_value, @msg = red\hget('backend:' .. asset_name, '_' .. config)
    if config_value == nil
        @resp = nil
    else
        @resp = { [config]: config_value }
    if @resp
        @status = 200
        @msg = "OK"
    if @resp == nil
        @status = 404
        @msg = "Entry does not exist"
    else
        @status = 500 unless @status
        @msg = 'Unknown failutre' unless @msg
        library.log(@msg)
    M.finish(red)

M.set_config = (@, asset_name, config, value) ->
    red = M.connect(@)
    return nil if red == nil
    ok, err = red\hset('backend:' .. asset_name, '_' .. config, value)
    if ok >= 0
        @status = 200
        @msg = "OK"
    else
        @status = 500
        err = "unknown" if err == nil
        @msg = "Failed to save backend config: " .. err
        library.log_err(@msg)
    M.finish(red)

M.get_data = (@, asset_type, asset_name) ->
    red = M.connect(@)
    return nil if red == nil
    switch asset_type
        when 'frontends'
            if asset_name == nil
                @resp = {}
                keys, err = red\keys('frontend:*')
                for key in *keys
                    url = library.split(key, ':')
                    url = url[ #url ]
                    backend_name = red\get(key)
                    table.insert(@resp, 1, {url: url, backend_name: backend_name})
            else
                @resp, @msg = red\get('frontend:' .. asset_name)
                if getmetatable(@resp) == nil
                    @resp = nil
            @status = 500 unless @resp
        when 'backends'
            if asset_name == nil
                keys, err = red\keys('backend:*')
                @resp = {}
                for key in *keys
                    name = library.split(key, ':')
                    name = name[ #name ]
                    rawdata = red\hgetall(key)
                    servers = [item for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) != '_']
                    configs = { string.sub(item, 2, -1), rawdata[i+1] for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) == '_'}
                    table.insert(@resp, 1, {name: name, servers: servers, config: configs})
            else
                rawdata, @msg = red\hgetall('backend:' .. asset_name)
                servers = [item for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) != '_']
                configs = { string.sub(item, 2, -1), rawdata[i+1] for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) == '_'}
                if #rawdata == 0
                    @resp = nil
                else
                    @resp = { servers: servers, config: configs }
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
        library.log(@msg)
    M.finish(red)

M.save_data = (@, asset_type, asset_name, asset_value, score, overwrite=false) ->
    red = M.connect(@)
    return nil if red == nil
    switch asset_type
        when 'frontends'
            ok, err = red\set('frontend:' .. asset_name, asset_value)
        when 'backends'
            if config.default_score == nil
                config.default_score = 0
            if score == nil
                score = config.default_score
            red = M.connect(@)
            red\init_pipeline() if overwrite
            red\del('backend:' .. asset_name) if overwrite
            ok, err = red\hset('backend:' .. asset_name, asset_value, score)
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
        library.log_err(@msg)
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
                resp, @msg = red\hdel('backend:' .. asset_name, asset_value)
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
        library.log_err(@msg)
    M.finish(red)

M.save_batch_data = (@, data, overwrite=false) ->
    red = M.connect(@)
    return nil if red == nil
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            red\del('frontend:' .. frontend['url']) if overwrite
            unless frontend['backend_name'] == nil
                library.log('adding frontend: ' .. frontend['url'] .. ' ' .. frontend['backend_name'])
                red\set('frontend:' .. frontend['url'], frontend['backend_name'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if overwrite
            -- ensure servers are a table
            if backend['servers']
                backend['servers'] = {backend['servers']} unless type(backend['servers']) == 'table'
                for server in *backend['servers']
                    unless server == nil
                        if type(server) == 'string'
                            -- supporting just string values so we can be backwards compatible with the API
                            if config.default_score == nil
                                config.default_score = 0
                            red\hset('backend:' .. backend["name"], server, config.default_score)
                        else
                            red\hset('backend:' .. backend["name"], server[1], server[2])
            if backend['config']
                for k,v in pairs backend['config']
                    red\hset('backend:' .. backend["name"], "_" .. k, v)
                        
    M.commit(@, red, "failed to save data: ")
    M.finish(red)

M.delete_batch_data = (@, data) ->
    red = M.connect(@)
    return nil if red == nil
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            library.log('deleting frontend: ' .. frontend['url'])
            red\del('frontend:' .. frontend['url'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if backend['servers'] == nil and backend['config'] == nil
            if backend['servers']
                -- ensure servers are a table
                backend['servers'] = {backend['servers']} unless type(backend['servers']) == 'table'
                for server in *backend['servers']
                    unless server == nil
                        library.log('deleting backend: ' .. backend["name"] .. ' ' .. server)
                        red\hdel('backend:' .. backend["name"], server)
            if backend['config']
                for k,v in ipairs backend['config']
                    library.log('deleting backend config: ' .. backend["name"] .. ' ' .. k)
                    red\hdel('backend:' .. backend["name"], k)
    M.commit(@, red, "failed to save data: ")
    M.finish(red)

M.fetch_frontend = (@, max_path_length=3) ->
    path = @req.parsed_url['path']
    path_parts = library.split path, '/'
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
            M.finish(red)
            return { frontend_key: key, backend_key: resp }
    M.finish(red)
    library.log_err("Frontend Cache miss")
    return nil

M.fetch_backend = (@, backend) ->
    red = M.connect(@)
    return { nil, nil } if red == nil
    rawdata, err = red\hgetall('backend:' .. backend)
    servers = {}
    configs = {}
    for i, item in ipairs rawdata
        if i % 2 > 0
            if item\sub(1,1) == '_'
                config_name = string.sub(item, 2, -1)
                configs[config_name] = rawdata[i+1]
            else
                server = { address: item, score: tonumber(rawdata[i+1])}
                table.insert(servers, server)
    M.finish(red)
    return { servers, configs }

M.orphans = (@) ->
    red = M.connect(@)
    return nil if red == nil
    orphans = { frontends: {}, backends: {} }
    frontends, err = red\keys('frontend:*')
    backends, err = red\keys('backend:*')
    used_backends = {}
    for frontend in *frontends do
        backend_name, err = red\get(frontend)
        frontend_url = library.split(frontend, 'frontend:')[2]
        if type(backend_name) == 'string'
            resp, err = red\exists('backend:' .. backend_name)
            if resp == 0
                table.insert(orphans['frontends'], { url: frontend_url })
            else
                table.insert(used_backends, backend_name)
        else
            table.insert(orphans['frontends'], { url: frontend_url })
    used_backends = library.Set(used_backends)
    for backend in *backends do
        backend_name = library.split(backend, 'backend:')[2]
        unless used_backends[backend_name]
            table.insert(orphans['backends'], { name: backend_name })
    @resp = orphans
    @status = 200
    return orphans
return M
