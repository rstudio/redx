export redis = require 'redis'
export config = require 'config'
export library = require 'library'
export inspect = require 'inspect'

library.log('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
