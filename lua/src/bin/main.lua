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
ngx.req.read_body()
local request_body = ngx.req.get_body_data()
local process_request
process_request = function(request)
  local frontend = redis.fetch_frontend(request, config.max_path_length)
  if frontend == nil then
    ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "false")
  else
    ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "true")
    ngx.req.set_header("X-Redx-Frontend-Name", frontend['frontend'])
    ngx.req.set_header("X-Redx-Backend-Name", frontend['backend'])
    local backend = redis.fetch_backend(frontend['backend'])
    local session = {
      frontend = frontend['frontend'],
      backend = frontend['backend'],
      servers = backend[1],
      config = backend[2],
      server = nil
    }
    if session['servers'] == nil then
      ngx.req.set_header("X-Redx-Backend-Cache-Hit", "false")
    else
      local _list_0 = plugins
      for _index_0 = 1, #_list_0 do
        local plugin = _list_0[_index_0]
        if (plugin['plugin']().pre) then
          local response = plugin['plugin']().pre(request, session, plugin['param'])
          if response ~= nil then
            return response
          end
        end
      end
      local _list_1 = plugins
      for _index_0 = 1, #_list_1 do
        local plugin = _list_1[_index_0]
        if (plugin['plugin']().balance) then
          session['servers'] = plugin['plugin']().balance(request, session, plugin['param'])
          if type(session['servers']) == 'string' then
            session['server'] = session['servers']
            break
          elseif type(session['servers']['address']) == 'string' then
            session['server'] = session['servers']['address']
            break
          elseif #session['servers'] == 1 then
            session['server'] = session['servers'][1]['address']
            break
          elseif session['servers'] == nil or #session['servers'] == 0 then
            session['server'] = nil
            break
          end
        end
      end
      local _list_2 = plugins
      for _index_0 = 1, #_list_2 do
        local plugin = _list_2[_index_0]
        if (plugin['plugin']().post) then
          local response = plugin['plugin']().post(request, session, plugin['param'])
          if response ~= nil then
            return response
          end
        end
      end
      if session['server'] ~= nil then
        ngx.req.set_header("X-Redx-Backend-Cache-Hit", "true")
        ngx.req.set_header("X-Redx-Backend-Server", session['server'])
        library.log("SERVER: " .. session['server'])
        ngx.req.set_body_data = request_body
        request_body = nil
        ngx.var.upstream = session['server']
      end
    end
  end
  return nil
end
local process_response
process_response = function(response)
  if response then
    if not (type(response) == 'table') then
      response = { }
    end
    if not (response['status']) then
      response['status'] = 500
    end
    if not (response['message']) then
      response['message'] = "Unknown failure."
    end
    ngx.status = response['status']
    ngx.say(response['message'])
    return ngx.exit(response['status'])
  else
    return {
      layout = false
    }
  end
end
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
      return "Max-Age=" .. tostring(config.session_length) .. "; Path=" .. tostring(p) .. "; HttpOnly"
    end,
    ['/'] = function(self)
      return process_response(process_request(self))
    end,
    default_route = function(self)
      return process_response(process_request(self))
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = nil,
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
  return _class_0
end
