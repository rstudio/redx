-- init_redx.lua

require 'split'
export redis = require 'redis'
export config = require 'config'

print('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
