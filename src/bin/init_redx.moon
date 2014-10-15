export redis = require 'redis'
export config = require 'config'
export library = require 'library'
export inspect = require 'inspect'
export socket = require 'socket'

-- seed math.random
math.randomseed(socket.gettime! * 1000)

library.log('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
