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
    config_value, @msg = red\zscore('backend:' .. asset_name, '_' .. config)
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
    library.log(asset_name)
    library.log(config)
    library.log(value)
    ok, err = red\zadd('backend:' .. asset_name, value, '_' .. config)
    library.log(ok)
    library.log(err)
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
            @resp, @msg = red\get('frontend:' .. asset_name)
            @status = 500 unless @resp
            if getmetatable(@resp) == nil
                @resp = nil
        when 'backends'
            rawdata, @msg = red\zrangebyscore('backend:' .. asset_name, '-inf', '+inf', 'withscores')
            data = {}
            @resp = {}
            data = {item,rawdata[i+1] for i, item in ipairs rawdata when i % 2 > 0}
            @resp = [ k for k,v in pairs data when k\sub(1,1) != "_"]
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
        library.log(@msg)
    M.finish(red)

M.save_data = (@, asset_type, asset_name, asset_value, connections=0, overwrite=false) ->
    red = M.connect(@)
    return nil if red == nil
    switch asset_type
        when 'frontends'
            ok, err = red\set('frontend:' .. asset_name, asset_value)
        when 'backends'
            red = M.connect(@)
            red\init_pipeline() if overwrite
            red\del('backend:' .. asset_name) if overwrite
            ok, err = red\zadd('backend:' .. asset_name, connections, asset_value)
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
                resp, @msg = red\zrem('backend:' .. asset_name, asset_value)
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
            backend['servers'] = {backend['servers']} unless type(backend['servers']) == 'table'
            for server in *backend['servers']
                unless server == nil
                    library.log('adding backend: ' .. backend["name"] .. ' ' .. server)
                    red\zadd('backend:' .. backend["name"], 0, server)
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
            red\del('backend:' .. backend["name"]) if backend['servers'] == nil
            if backend['servers']
                -- ensure servers are a table
                backend['servers'] = {backend['servers']} unless type(backend['servers']) == 'table'
                for server in *backend['servers']
                    unless server == nil
                        library.log('deleting backend: ' .. backend["name"] .. ' ' .. server)
                        red\zrem('backend:' .. backend["name"], server)
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

M.fetch_server = (@, backend_key) ->
    if config.stickiness > 0
        export backend_cookie = @session.backend
    export upstream = nil
    red = M.connect(@)
    return nil if red == nil
    if config.stickiness > 0 and backend_cookie != nil and backend_cookie != ''
        resp, err = red\zscore('backend:' .. backend_key, backend_cookie)
        if resp == nil
            -- clear cookie by setting to nil
            @session.backend = nil
            export upstream = nil
        else
            export upstream = backend_cookie
    if upstream == nil
        rawdata, err = red\zrangebyscore('backend:' .. backend_key, '-inf', '+inf', 'withscores')
        data = {}
        data = {item,rawdata[i+1] for i, item in ipairs rawdata when i % 2 > 0}
        --split backends from config data
        upstreams = {}
        upstreams = [{ backend:k, connections: tonumber(v)} for k,v in pairs data when k\sub(1,1) != "_"]
        backend_config = {}
        backend_config = {k,v for k,v in pairs data when k\sub(1,1) == "_"}
        if #upstreams == 1
            -- only one backend available
            library.log_err('Only one backend, choosing it')
            upstream = upstreams[1]['backend']
        else
            if config.balance_algorithm == 'least-connections'
                -- get least connection probability
                if #upstreams == 2
                    -- get least connection probability relative to max connections
                    max_connections = tonumber(backend_config['_max_connections'])
                    unless max_connections == nil
                        -- get total number of available connections
                        available_connections = 0
                        for x in *upstreams
                            available_connections += (max_connections - x['connections'])
                        -- pick random number within total available connections
                        rand = math.random( 1, available_connections )
                        if rand <= (max_connections - upstreams[1]['connections'])
                            upstream = upstreams[1]['backend']
                        else
                            upstream = upstreams[2]['backend']
                else
                    -- get least connection probability relative to larger connections
                    -- get largest and least number of connections
                    most_connections = nil
                    least_connections = nil
                    for up in *upstreams
                        if most_connections == nil or up['connections'] > most_connections
                            most_connections = up['connections']
                        if least_connections == nil or up['connections'] < least_connections
                            least_connections = up['connections']
                    available_upstreams = [ up for up in *upstreams when up['connections'] < most_connections]
                    if #available_upstreams > 0
                        available_connections = 0 -- available connections to match highest connection count
                        for x in *available_upstreams
                            available_connections += (most_connections - x['connections'])
                        rand = math.random( available_connections )
                        offset = 0
                        for up in *available_upstreams
                            if rand <= (most_connections - up['connections'] + offset)
                                upstream = up['backend']
                                break
                            offset += (most_connections - up['connections'])
                if upstream == nil and #upstreams > 0
                    -- if least-connections fails to find a backend, fallback to pick one randomly
                    upstream = upstreams[ math.random( #upstreams ) ]['backend']
            else
                -- choose random upstream
                upstream = upstreams[ math.random( #upstreams ) ]['backend']
    M.finish(red)
    if type(upstream) == 'string'
        if config.stickiness > 0
            -- update cookie
            @session.backend = upstream
        return upstream
    else
        library.log_err("Backend Cache miss: " .. backend_key)
        return nil

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
