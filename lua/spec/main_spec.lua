local load_test_server, close_test_server
do
  local _obj_0 = require("lapis.spec.server")
  load_test_server, close_test_server = _obj_0.load_test_server, _obj_0.close_test_server
end
local to_json, from_json, escape
do
  local _obj_0 = require("lapis.util")
  to_json, from_json, escape = _obj_0.to_json, _obj_0.from_json, _obj_0.escape
end
inspect = require("inspect")
http = require("socket.http")
ltn12 = require("ltn12")
json_body = from_json('{\n    "frontends": [\n        {\n            "url": "myserver.com/contact",\n            "backend_name": "12345"\n        }\n    ],\n    "backends": [\n        {\n            "name": "12345",\n            "servers": [\n                "apple.com:80",\n                "rstudio.com:80"\n            ]\n        }\n    ]\n}')
local make_json_request
make_json_request = function(url, method, body, port)
  if method == nil then
    method = "GET"
  end
  if body == nil then
    body = nil
  end
  if port == nil then
    port = 8081
  end
  local respbody = { }
  if body then
    body, code, headers, status = http.request({
      url = "http://localhost:" .. tostring(port) .. tostring(url),
      method = method,
      source = ltn12.source.string(to_json(json_body)),
      sink = ltn12.sink.table(respbody),
      headers = {
        ['Content-Type'] = "application/json",
        ['Content-Length'] = tostring(#to_json(json_body))
      }
    })
  else
    body, code, headers, status = http.request({
      url = "http://localhost:" .. tostring(port) .. tostring(url),
      method = method,
      sink = ltn12.sink.table(respbody),
      headers = {
        ['Content-Type'] = "application/json"
      }
    })
  end
  local response = from_json(table.concat(respbody))
  return response, code, headers
end
local make_request
make_request = function(url, host, method, port)
  if host == nil then
    host = 'myserver.com'
  end
  if method == nil then
    method = "GET"
  end
  if port == nil then
    port = 8080
  end
  local respbody = { }
  local body, code, headers, status = http.request({
    url = "http://localhost:" .. tostring(port) .. tostring(url),
    method = method,
    sink = ltn12.sink.table(respbody),
    headers = {
      ["Host"] = host
    }
  })
  local response = table.concat(respbody)
  return response, code, headers
end
return describe("redx_main", function()
  randomize()
  setup(function()
    return load_test_server()
  end)
  teardown(function()
    make_json_request("/flush", "DELETE")
    return close_test_server()
  end)
  before_each(function()
    local response, code, headers = make_json_request("/batch", "PUT", json_body)
  end)
  it("make regular request", function()
    local response, code, headers = make_request("/contact")
    return assert.are_not.equals(404, code)
  end)
  it("make regular invalid request #invalid_uri", function()
    local response, code, headers = make_request("/bad_url")
    return assert.same(502, code)
  end)
  return it("make request to bad host", function()
    json_body['backends'][1]['servers'] = {
      "rstudiobogus.com:9844"
    }
    local response, code, headers = make_json_request("/batch", "PUT", json_body)
    assert.same(200, code)
    response, code, headers = make_request("/contact")
    return assert.True((code == 502 or code == "closed"))
  end)
end)
