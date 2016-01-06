M = {}

M.connect = () ->
    -- connect to redis
    redis = require "resty.redis"
    red = redis\new()
    red\set_timeout(config.redis_timeout)
    ok, err = red\connect(config.redis_host, config.redis_port)
    unless ok
        return connection_error: "Error connecting to redis: " .. err
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
            library.log_err("Failed to set keepalive: ", err)

-- used for when the response is pass/fail and no data
M.boolean_response = (red, err) ->
    if err
        return status: 500, msg: err, redis: red
    else
        return status: 200, redis: red

M.test = () ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    rand_value = tostring(math.random!)
    key = "healthcheck:" .. rand_value
    ok , err = red\set(key, rand_value)
    unless ok
        return status: 500, msg: "Failed to write to redis", redis: red
    ok, err = red\get(key)
    unless ok
        return status: 500, msg: "Failed to read redis", redis: red
    unless ok == rand_value
        return status: 500, msg: "Healthcheck failed to write and read from redis", redis: red
    ok, err = red\del(key)
    if ok
        return status: 200, redis: red
    else
        return status: 500, msg: "Failed to delete key from redis", redis: red

M.commit = (red, error_msg, data=nil) ->
    -- commit the change
    results, err = red\commit_pipeline()
    if err
        return status: 500, msg:  error_msg .. err, redis: red
    else
        return status: 200, redis: red

M.flush = () ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    ok, err = red\flushdb()
    return M.boolean_response(red, err)

M.get_config = (asset_name, config) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    config_value, err = red\hget('backend:' .. asset_name, '_' .. config)
    if type(config_value) != 'string'
        return status: 404, redis: red
    elseif err
        return status: 500, msg: err
    else
        return status: 200, data: config_value, redis: red

M.delete_config = (asset_name, config) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    ok, err = red\hdel('backend:' .. asset_name, '_' .. config)
    return M.boolean_response(red, err)

M.set_config = (asset_name, config, value) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    ok, err = red\hset('backend:' .. asset_name, '_' .. config, value)
    if ok >= 0
        return status: 200, redis: red
    else
        return status: 500, msg: "Failed to save backend config: " .. err, redis: red

M.get_data = (asset_type, asset_name) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    data = {}
    switch asset_type
        when 'frontends'
            if asset_name == nil
                keys, err = red\keys('frontend:*')
                if err
                    return status: 500, msg: err, redis: red
                else
                    for key in *keys
                        url = library.split(key, ':')
                        url = url[ #url ]
                        backend_name = red\get(key)
                        table.insert(data, 1, {url: url, backend_name: backend_name})
                    return status: 200, data: data, redis: red
            else
                data, err = red\get('frontend:' .. asset_name)
                if err
                    return status: 500, msg: err, redis: red
                else
                    if getmetatable(data) == nil
                        return status: 404, redis: red
                    else
                        return status: 200, data: data, redis: red
        when 'backends'
            if asset_name == nil
                keys, err = red\keys('backend:*')
                if err
                    return status: 500, msg: err, redis: red
                else
                    for key in *keys
                        name = library.split(key, ':')
                        name = name[ #name ]
                        rawdata = red\hgetall(key)
                        servers = [item for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) != '_']
                        configs = { string.sub(item, 2, -1), rawdata[i+1] for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) == '_'}
                        table.insert(data, 1, {name: name, servers: servers, config: configs})
                    return status: 200, data: data, redis: red
            else
                rawdata, err = red\hgetall('backend:' .. asset_name)
                if err
                    return status: 500, msg: err, redis: red
                else
                    servers = [item for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) != '_']
                    configs = { string.sub(item, 2, -1), rawdata[i+1] for i, item in ipairs rawdata when i % 2 > 0 and item\sub(1,1) == '_'}
                    if #rawdata == 0
                        return status: 404, redis: red
                    else
                        return status: 200, data: { servers: servers, config: configs }, redis: red
        else
            return status: 400, msg: 'Bad asset type. Must be "frontends" or "backends"', redis: red

M.save_data = (asset_type, asset_name, asset_value, score, overwrite=false) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    switch asset_type
        when 'frontends'
            ok, err = red\set('frontend:' .. asset_name, asset_value)
            return M.boolean_response(red, err)
        when 'backends'
            config.default_score = 0 if config.default_score == nil
            score = config.default_score if score == nil
            red\init_pipeline() if overwrite
            red\del('backend:' .. asset_name) if overwrite
            ok, err = red\hset('backend:' .. asset_name, asset_value, score)
            return M.commit(red, "Failed to save backend: ") if overwrite
            return M.boolean_response(red, err)
        else
            return status: 400, msg: 'Bad asset type. Must be "frontends" or "backends"', redis: red

M.delete_data = (asset_type, asset_name, asset_value=nil) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    switch asset_type
        when 'frontends'
            resp, err = red\del('frontend:' .. asset_name)
            return M.boolean_response(red, err)
        when 'backends'
            if asset_value == nil
                resp, err = red\del('backend:' .. asset_name)
            else
                resp, err = red\hdel('backend:' .. asset_name, asset_value)
            return M.boolean_response(red, err)
        else
            return status: 400, msg: 'Bad asset type. Must be "frontends" or "backends"', redis: red

M.save_batch_data = (data, overwrite=false) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
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
                            config.default_score = 0 if config.default_score == nil
                            red\hset('backend:' .. backend["name"], server, config.default_score)
                        else
                            red\hset('backend:' .. backend["name"], server[1], server[2])
            if backend['config']
                for k,v in pairs backend['config']
                    red\hset('backend:' .. backend["name"], "_" .. k, v)
    M.commit(red, "Failed to batch save data: ")

M.delete_batch_data = (data) ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
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
    M.commit(red, "Failed to batch delete data: ")

M.fetch_frontend = (@, max_path_length=3) ->
    path = @req.parsed_url['path']
    host = @req.parsed_url['host']
    keys, frontends = {'frontend:' .. host}, {host}
    p, count = '', 0
    for k,v in pairs library.split(path, '/')
        unless v == nil or v == ''
            if count < (max_path_length)
                count += 1
                v = library.strip(v, '/') -- remove leading and trailing slashes
                p = p .. "/#{v}"
                frontend = "#{host}#{p}/" -- always include a trailing slash
                table.insert(keys, 1, "frontend:#{frontend}")
                table.insert(frontends, 1, frontend)

    red = M.connect()
    return nil if red['connection_error']
    resp, err = red\mget(unpack(keys))
    M.finish(red)
    return nil if err
    for i, item in pairs resp
        if type(item) == 'string'
            return { frontend: frontends[i], backend: tostring(item) }
    library.log_err("Frontend Cache miss")
    return nil

M.fetch_backend = (backend) ->
    red = M.connect()
    return { nil, nil } if red['connection_error']
    rawdata, err = red\hgetall('backend:' .. backend)
    M.finish(red)
    return status: 500, msg: err if err
    servers, configs = {}, {}
    for i, item in ipairs rawdata
        if i % 2 > 0
            if item\sub(1,1) == '_'
                config_name = string.sub(item, 2, -1)
                configs[config_name] = rawdata[i+1]
            else
                table.insert(servers, { address: item, score: tonumber(rawdata[i+1])})
    return { servers, configs }

M.orphans = () ->
    red = M.connect()
    return status: 500, msg: red['connection_error'] if red['connection_error']
    orphans = { frontends: {}, backends: {} }
    frontends, err = red\keys('frontend:*')
    return status: 500, msg: err, redis: red if err
    backends, err = red\keys('backend:*')
    return status: 500, msg: err, redis: red if err
    rawdata, err = red\mget(unpack(frontends))
    return status: 500, msg: err, redis: red if err
    used_backends = {}
    for i, backend_name in pairs rawdata do
        frontend_url = library.split(frontends[i], 'frontend:')[2]
        if type(backend_name) == 'string'
            match = false
            for backend in *backends
                if backend == 'backend:' .. backend_name
                    table.insert(used_backends, backend_name)
                    match = true
                    break
            table.insert(orphans['frontends'], { url: frontend_url }) unless match
        else
            table.insert(orphans['frontends'], { url: frontend_url })
    used_backends = library.set(used_backends)
    for backend in *backends do
        backend_name = library.split(backend, 'backend:')[2]
        unless used_backends[backend_name]
            table.insert(orphans['backends'], { name: backend_name })
    return status: 200, data: orphans, redis: red
return M
