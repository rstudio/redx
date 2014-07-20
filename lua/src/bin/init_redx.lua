print('fooo')
redis = require('redis')
config = require('config')
return print('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
