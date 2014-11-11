export redis = require 'redis'
export config = require 'config'
export library = require 'library'
export inspect = require 'inspect'
export socket = require 'socket'

export plugins = {}

-- load plugins
for i, plugin in ipairs config.plugins
    name, param = nil, nil
    if type(plugin) == 'string'
        name = plugin
    else
        name, param = plugin[1], plugin[2]
    require_string = "return require('" .. name .. "')"
    library.log("Loading plugin: " .. name)
    plugins[i] = {
        name: name,
        param: param,
        plugin: loadstring(require_string)
    }

-- seed math.random
math.randomseed(socket.gettime! * 1000)

library.log('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
