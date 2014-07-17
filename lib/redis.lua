local M = { }
M.connect = function(self)
  local redis = require("resty.redis")
  local red = redis:new()
  red:set_timeout(20000)
  red:set_keepalive(20000)
  local ok, err = red:connect(config.redis_host, config.redis_port)
  if not ok then
    print("Error connecting to redis: " .. err)
    self.msg = "error connectiong: " .. err
    self.status = 500
  else
    print('Connected to redis')
    return red
  end
end
M.commit = function(self, red, error_msg)
  local results, err = red:commit_pipeline()
  if not results then
    self.msg = error_msg .. err
    self.status = 500
  else
    self.msg = "OK"
    self.status = 404
  end
end
return M
