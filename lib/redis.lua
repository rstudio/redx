local M = {}

M.connect = function()
    local redis = require "resty.redis"
    local red = redis:new()
    red:set_timeout(1000)
    local ok, err = red:connect(config.redis_host, config.redis_port)
    if not ok then
        ngx.say("Failed to connect to Redis: ", err)
        ngx.exit(500)
    else
        return red
    end
end

M.commit = function(red, error_msg)
    -- commit the change
    local results, err = red:commit_pipeline()
    if not results then
        ngx.say(error_msg, err)
        ngx.exit(500)
    else
        ngx.say("OK")
        ngx.exit(200)
    end
end

return M
