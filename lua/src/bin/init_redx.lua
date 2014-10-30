redis = require('redis')
config = require('config')
library = require('library')
inspect = require('inspect')
socket = require('socket')
plugins = { }
for i, plugin in ipairs(config.plugins) do
  local name = nil
  local param = nil
  if type(plugin) == 'string' then
    name = plugin
  else
    name = plugin[1]
    param = plugin[2]
  end
  local str = "return require('" .. name .. "')"
  plugins[i] = {
    name = name,
    param = param,
    plugin = loadstring(str)
  }
end
math.randomseed(socket.gettime() * 1000)
return library.log('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
