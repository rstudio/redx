M = {}

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

return M
