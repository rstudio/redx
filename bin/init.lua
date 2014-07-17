-- init.lua

require 'split'
redis = require 'redis'
config = require 'config'

ngx.log(ngx.ERR, 'Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
