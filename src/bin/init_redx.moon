export redis = require 'redis'
export config = require 'config'
export library = require 'library'
export inspect = require 'inspect'
export socket = require 'socket'

export plugins = {}

-- load plugins
for i, plugin in ipairs config.plugins
    name = nil
    param = nil
    if type(plugin) == 'string'
        name = plugin
    else
        name = plugin[1]
        param = plugin[2]
    str = "return require('" .. name .. "')"
    library.log("Loading plugin: " .. name)
    plugins[i] = {
        name: name,
        param: param,
        plugin: loadstring(str)
    }

-- seed math.random
math.randomseed(socket.gettime! * 1000)

library.log('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
