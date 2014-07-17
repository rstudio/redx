redis = require('redis')
inspect = require('inspect')
local lapis = require("lapis")
local respond_to
do
  local _obj_0 = require("lapis.application")
  respond_to = _obj_0.respond_to
end
local from_json
do
  local _obj_0 = require("lapis.util")
  from_json = _obj_0.from_json
end
local get_data
get_data = function(self, input_data)
  self.resp = { }
  local red = redis.connect(self)
  if input_data["frontends"] then
    self.resp['frontends'] = { }
    local _list_0 = input_data['frontends']
    for _index_0 = 1, #_list_0 do
      local frontend = _list_0[_index_0]
      self.resp['frontends'][tostring(frontend['name'])] = red:get('frontend:' .. frontend['name'])
    end
  end
  if input_data["backends"] then
    self.resp['backends'] = { }
    if not (type(backend['backend']) == 'table') then
      backend['backend'] = {
        backend['backend']
      }
    end
    local _list_0 = input_data['backends']
    for _index_0 = 1, #_list_0 do
      local backend = _list_0[_index_0]
      self.resp['backends'][tostring(backend['name'])] = red:smembers('backend:' .. backend["name"])
    end
  end
  self.msg = "OK"
  self.status = 200
end
local save_data
save_data = function(self, data, overwrite)
  if overwrite == nil then
    overwrite = false
  end
  local red = redis.connect(self)
  red:init_pipeline()
  if data["frontends"] then
    local _list_0 = data['frontends']
    for _index_0 = 1, #_list_0 do
      local frontend = _list_0[_index_0]
      if overwrite then
        red:del('frontend:' .. frontend['name'])
      end
      if not (frontend['backend'] == nil) then
        print('adding frontend: ' .. frontend["name"] .. ' ' .. frontend['backend'])
        red:set('frontend:' .. frontend['name'], frontend['backend'])
      end
    end
  end
  if data["backends"] then
    local _list_0 = data['backends']
    for _index_0 = 1, #_list_0 do
      local backend = _list_0[_index_0]
      if overwrite then
        red:del('backend:' .. backend["name"])
      end
      if not (type(backend['backend']) == 'table') then
        backend['backend'] = {
          backend['backend']
        }
      end
      local _list_1 = backend['backend']
      for _index_1 = 1, #_list_1 do
        local host = _list_1[_index_1]
        if not (host == nil) then
          print('adding backend: ' .. backend["name"] .. ' ' .. host)
          red:sadd('backend:' .. backend["name"], host)
        end
      end
    end
  end
  return redis.commit(self, red, "failed to save data: ")
end
local delete_data
delete_data = function(self, data)
  print('pass delete')
  return nil
end
local format_data
format_data = function(typ, name, value, body)
  if typ == nil then
    typ = nil
  end
  if name == nil then
    name = nil
  end
  if value == nil then
    value = nil
  end
  if body == nil then
    body = nil
  end
  local data = { }
  if typ == nil and name == nil and value == nil then
    if body then
      data = body
    else
      data = { }
    end
  elseif typ and name == nil and value == nil then
    if body then
      data[tostring(typ)] = body
    else
      data[tostring(typ)] = { }
    end
  elseif typ and name and value == nil then
    if body['backend'] then
      data[tostring(typ)] = {
        {
          name = tostring(name),
          backend = body['backend']
        }
      }
    else
      data[tostring(typ)] = {
        {
          name = tostring(name),
          backend = nil
        }
      }
    end
  else
    data[tostring(typ)] = {
      {
        name = tostring(name),
        backend = tostring(value)
      }
    }
  end
  return data
end
local json_response
json_response = function(self)
  local json = { }
  if self.msg then
    json['message'] = self.msg
  end
  if self.resp then
    json['data'] = self.resp
  end
  return json
end
local webserver
do
  local _parent_0 = lapis.Application
  local _base_0 = {
    ['/'] = respond_to({
      before = function(self)
        for k, v in pairs(self.req.params_post) do
          self.body = from_json(k)
        end
        self.input_data = format_data(nil, nil, nil, self.body)
      end,
      GET = function(self)
        get_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      POST = function(self)
        save_data(self, self.input_data, false)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      PUT = function(self)
        save_data(self, self.input_data, true)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        delete_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/:type'] = respond_to({
      before = function(self)
        for k, v in pairs(self.req.params_post) do
          self.body = from_json(k)
        end
        self.input_data = format_data(self.params.type, nil, nil, self.body)
      end,
      GET = function(self)
        get_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      POST = function(self)
        save_data(self, self.input_data, false)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      PUT = function(self)
        save_data(self, self.input_data, true)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        delete_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/:type/:name'] = respond_to({
      before = function(self)
        for k, v in pairs(self.req.params_post) do
          self.body = from_json(k)
        end
        self.input_data = format_data(self.params.type, self.params.name, nil, self.body)
      end,
      GET = function(self)
        get_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      POST = function(self)
        save_data(self, self.input_data, false)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      PUT = function(self)
        save_data(self, self.input_data, true)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        delete_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/:type/:name/:value'] = respond_to({
      before = function(self)
        for k, v in pairs(self.req.params_post) do
          self.body = from_json(k)
        end
        self.input_data = format_data(self.params.type, self.params.name, self.params.value, self.body)
      end,
      POST = function(self)
        save_data(self, self.input_data, false)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      PUT = function(self)
        save_data(self, self.input_data, true)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        delete_data(self, self.input_data)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    })
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
