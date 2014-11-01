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
local response
response = function(t)
  if t['redis'] then
    redis.finish(t['redis'])
  end
  response = {
    status = 500,
    json = {
      message = "Unknown failure"
    }
  }
  if t['status'] then
    response['status'] = t['status']
  end
  if t['msg'] then
    response['json']['message'] = t['msg']
  end
  if t['data'] then
    response['json']['data'] = t['data']
  end
  if t['msg'] == nil and response['status'] < 300 then
    response['json']['message'] = "OK"
  end
  if t['msg'] == nil and response['status'] == 404 then
    response['json']['message'] = "Entry does not exist"
  end
  if response['status'] >= 300 then
    library.log_err(response)
  end
  return response
end
local webserver
do
  local _parent_0 = lapis.Application
  local _base_0 = {
    ['/health'] = respond_to({
      GET = function(self)
        return response(redis.test())
      end
    }),
    ['/flush'] = respond_to({
      DELETE = function(self)
        return response(redis.flush())
      end
    }),
    ['/orphans'] = respond_to({
      GET = function(self)
        return response(redis.orphans())
      end,
      DELETE = function(self)
        return response(redis.delete_batch_data(redis.orphans()['data']))
      end
    }),
    ['/batch'] = respond_to({
      before = function(self)
        for k, v in pairs(self.req.params_post) do
          self.json_body = from_json(k)
        end
      end,
      POST = function(self)
        if not (self.json_body) then
          return response({
            status = 400,
            msg = "Missing json body"
          })
        end
        return response(redis.save_batch_data(self.json_body, false))
      end,
      PUT = function(self)
        if not (self.json_body) then
          return response({
            status = 400,
            msg = "Missing json body"
          })
        end
        return response(redis.save_batch_data(self.json_body, true))
      end,
      DELETE = function(self)
        if not (self.json_body) then
          return response({
            status = 400,
            msg = "Missing json body"
          })
        end
        return response(redis.delete_batch_data(self.json_body))
      end
    }),
    ['/frontends'] = respond_to({
      GET = function(self)
        return response(redis.get_data('frontends', nil))
      end
    }),
    ['/backends'] = respond_to({
      GET = function(self)
        return response(redis.get_data('backends', nil))
      end
    }),
    ['/:type/:name'] = respond_to({
      GET = function(self)
        return response(redis.get_data(self.params.type, unescape(self.params.name)))
      end,
      DELETE = function(self)
        return response(redis.delete_data(self.params.type, unescape(self.params.name)))
      end
    }),
    ['/backends/:name/config/:config'] = respond_to({
      GET = function(self)
        return response(redis.get_config(unescape(self.params.name), unescape(self.params.config)))
      end
    }),
    ['/backends/:name/config/:config/:value'] = respond_to({
      PUT = function(self)
        return response(redis.set_config(unescape(self.params.name), unescape(self.params.config), unescape(self.params.value)))
      end
    }),
    ['/backends/:name/:value/score/:score'] = respond_to({
      PUT = function(self)
        return response(redis.save_data('backends', unescape(self.params.name), unescape(self.params.value), unescape(self.params.score), false))
      end
    }),
    ['/:type/:name/:value'] = respond_to({
      POST = function(self)
        return response(redis.save_data(self.params.type, unescape(self.params.name), unescape(self.params.value), 0, false))
      end,
      PUT = function(self)
        return response(redis.save_data(self.params.type, unescape(self.params.name), unescape(self.params.value), 0, true))
      end,
      DELETE = function(self)
        return response(redis.delete_data(self.params.type, unescape(self.params.name), unescape(self.params.value)))
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
