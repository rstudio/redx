redis = require('redis')
config = require('config')
library = require('library')
inspect = require('inspect')
socket = require('socket')
plugins = { }
for i, plugin in ipairs(config.plugins) do
  local name, param = nil, nil
  if type(plugin) == 'string' then
    name = plugin
  else
    name, param = plugin[1], plugin[2]
  end
  local require_string = "return require('" .. name .. "')"
  library.log("Loading plugin: " .. name)
  plugins[i] = {
    name = name,
    param = param,
    plugin = loadstring(require_string)
  }
end
math.randomseed(socket.gettime() * 1000)
return library.log('Redis host: ' .. config.redis_host .. ':' .. config.redis_port)
