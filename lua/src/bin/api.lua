local lapis = require("lapis")
local respond_to
do
  local _obj_0 = require("lapis.application")
  respond_to = _obj_0.respond_to
end
local from_json, unescape
do
  local _obj_0 = require("lapis.util")
  from_json, unescape = _obj_0.from_json, _obj_0.unescape
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
    ['/health'] = respond_to({
      GET = function(self)
        redis.test(self)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/flush'] = respond_to({
      DELETE = function(self)
        redis.flush(self)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/orphans'] = respond_to({
      GET = function(self)
        redis.orphans(self)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        local orphans = redis.orphans(self)
        redis.delete_batch_data(self, orphans)
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/batch'] = respond_to({
      before = function(self)
        for k, v in pairs(self.req.params_post) do
          self.body = from_json(k)
        end
        if not (self.body) then
          self.status = 400
          self.msg = "Missing json body"
          return library.log_err("Missing json body")
        end
      end,
      POST = function(self)
        if self.body then
          redis.save_batch_data(self, self.body, false)
        end
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      PUT = function(self)
        if self.body then
          redis.save_batch_data(self, self.body, true)
        end
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        if self.body then
          redis.delete_batch_data(self, self.body)
        end
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/:type/:name'] = respond_to({
      GET = function(self)
        redis.get_data(self, self.params.type, unescape(self.params.name))
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        redis.delete_data(self, self.params.type, unescape(self.params.name))
        return {
          status = self.status,
          json = json_response(self)
        }
      end
    }),
    ['/:type/:name/:value'] = respond_to({
      POST = function(self)
        redis.save_data(self, self.params.type, unescape(self.params.name), unescape(self.params.value), false)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      PUT = function(self)
        redis.save_data(self, self.params.type, unescape(self.params.name), unescape(self.params.value), true)
        return {
          status = self.status,
          json = json_response(self)
        }
      end,
      DELETE = function(self)
        redis.delete_data(self, self.params.type, unescape(self.params.name), unescape(self.params.value))
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
