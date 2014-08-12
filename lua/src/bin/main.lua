local lapis = require("lapis")
local lapis_config = require("lapis.config")
lapis_config.config("production", function()
  session_name("redx_session")
  return secret(config.cookie_secret)
end)
lapis_config.config("development", function()
  session_name("redx_session")
  return secret(config.cookie_secret)
end)
local process_request
process_request = function(self)
  local frontend = redis.fetch_frontend(self, config.max_path_length)
  if frontend == nil then
    return ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "false")
  else
    ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "true")
    ngx.req.set_header("X-Redx-Frontend-Name", frontend['frontend_key'])
    ngx.req.set_header("X-Redx-Backend-Name", frontend['backend_key'])
    local server = redis.fetch_server(self, frontend['backend_key'], false)
    if server == nil then
      return ngx.req.set_header("X-Redx-Backend-Cache-Hit", "false")
    else
      ngx.req.set_header("X-Redx-Backend-Cache-Hit", "true")
      ngx.req.set_header("X-Redx-Backend-Server", server)
      library.log("SERVER: " .. server)
      ngx.var.upstream = server
    end
  end
end
local webserver
do
  local _parent_0 = lapis.Application
  local _base_0 = {
    cookie_attributes = function(self, name, value)
      local path = self.req.parsed_url['path']
      local path_parts = library.split(path, '/')
      local p = ''
      local count = 0
      for k, v in pairs(path_parts) do
        if not (v == nil or v == '') then
          if count < (config.max_path_length) then
            count = count + 1
            p = p .. "/" .. tostring(v)
          end
        end
      end
      if p == '' then
        p = '/'
      end
      return "Max-Age=" .. tostring(config.stickiness) .. "; Path=" .. tostring(p) .. "; HttpOnly"
    end,
    ['/'] = function(self)
      process_request(self)
      return {
        layout = false
      }
    end,
    ['/set-cookie'] = function(self)
      library.log("setting cookie")
      self.cookies.foo = "bar"
      return {
        layout = false
      }
    end,
    ['/get-cookie'] = function(self)
      library.log("getting cookie")
      local _ = self.cookies.foo
      for k, v in pairs(getmetatable(self.cookies).__index) do
        print(k, v)
      end
      return {
        layout = false
      }
    end,
    default_route = function(self)
      process_request(self)
      return {
        layout = false
      }
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "webserver",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        return _parent_0[name]
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  webserver = _class_0
end
return lapis.serve(webserver)
