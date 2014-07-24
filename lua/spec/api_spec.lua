local load_test_server, close_test_server
do
  local _obj_0 = require("lapis.spec.server")
  load_test_server, close_test_server = _obj_0.load_test_server, _obj_0.close_test_server
end
local from_json, to_json, escape
do
  local _obj_0 = require("lapis.util")
  from_json, to_json, escape = _obj_0.from_json, _obj_0.to_json, _obj_0.escape
end
inspect = require("inspect")
http = require("socket.http")
ltn12 = require("ltn12")
json_body = from_json('{\n    "frontends": [\n        {\n            "url": "localhost/search",\n            "backend_name": "12345"\n        },\n        {\n            "url": "test.com/menlo/park",\n            "backend_name": "menlobackend"\n        }\n    ],\n    "backends": [\n        {\n            "name": "12345",\n            "servers": [\n                "google.com:80",\n                "duckduckgo.com:80"\n            ]\n        },\n        {\n            "name": "menlobackend",\n            "servers": [\n                "menloparkmuseum.org",\n                "tesc.edu"\n            ]\n        }\n    ]\n}')
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
return describe("redx_api", function()
  randomize()
  setup(function()
    return load_test_server()
  end)
  teardown(function()
    make_json_request("/flush", "DELETE")
    return close_test_server()
  end)
  before_each(function()
    return make_json_request("/flush", "DELETE")
  end)
  it("create a frontend #frontend_api", function()
    local response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')) .. "/mybackend", "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')))
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = "mybackend"
    })
  end)
  it("get 404 on invalid frontend #frontend_api", function()
    local response, code, headers = make_json_request("/frontends/this_frontend_does_not_exist")
    return assert.same(404, code)
  end)
  it("should delete a frontend #frontend_api", function()
    local response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')) .. "/mybackend", "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')))
    assert.same(200, code)
    assert.same(response, {
      message = "OK",
      data = "mybackend"
    })
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')) .. "/mybackend", "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')))
    return assert.same(404, code)
  end)
  it("create a backend #backend_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = {
        'rstudio.com:80'
      }
    })
  end)
  it("PUT replaces backend #backend_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('shinyapps.io:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    if response['data'] then
      table.sort(response['data'])
    end
    assert.same(200, code)
    assert.same(response, {
      message = "OK",
      data = {
        'rstudio.com:80',
        'shinyapps.io:80'
      }
    })
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('cran.rstudio.org:80')), "PUT")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = {
        'cran.rstudio.org:80'
      }
    })
  end)
  it("get 404 on invalid backend #backend_api", function()
    local response, code, headers = make_json_request("/backend/this_backend_does_not_exist")
    return assert.same(404, code)
  end)
  it("should delete a backend #backend_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('shinyapps.io:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    if response['data'] then
      table.sort(response['data'])
    end
    assert.same(200, code)
    assert.same(response, {
      message = "OK",
      data = {
        'rstudio.com:80',
        'shinyapps.io:80'
      }
    })
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = {
        'shinyapps.io:80'
      }
    })
  end)
  it("should delete all servers in a backend #backend_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('shinyapps.io:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    if response['data'] then
      table.sort(response['data'])
    end
    assert.same(200, code)
    assert.same(response, {
      message = "OK",
      data = {
        'rstudio.com:80',
        'shinyapps.io:80'
      }
    })
    response, code, headers = make_json_request("/backends/5555", "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    return assert.same(404, code)
  end)
  it("should get 400 on batch POST with no body #batch_api", function()
    local response, code, headers = make_json_request("/batch", "POST")
    return assert.same(400, code)
  end)
  it("should batch POST #batch_api", function()
    local response, code, headers = make_json_request("/batch", "POST", json_body)
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')))
    assert.same(response, {
      message = "OK",
      data = "menlobackend"
    })
    response, code, headers = make_json_request("/backends/menlobackend")
    if response['data'] then
      table.sort(response['data'])
    end
    return assert.same(response, {
      message = "OK",
      data = {
        "menloparkmuseum.org",
        "tesc.edu"
      }
    })
  end)
  it("should batch PUT #batch_api", function()
    local response, code, headers = make_json_request("/batch", "POST", json_body)
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('test.com/menlo/park')))
    assert.same(response, {
      message = "OK",
      data = "menlobackend"
    })
    response, code, headers = make_json_request("/backends/menlobackend")
    if response['data'] then
      table.sort(response['data'])
    end
    assert.same(response, {
      message = "OK",
      data = {
        "menloparkmuseum.org",
        "tesc.edu"
      }
    })
    local temp_json_body = json_body
    temp_json_body['frontends'][1]['backend_name'] = '6757'
    temp_json_body['backends'][1]['servers'] = {
      'apple.com'
    }
    response, code, headers = make_json_request("/batch", "PUT", temp_json_body)
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape(temp_json_body['frontends'][1]['url'])))
    assert.same(200, code)
    assert.same(response['data'], '6757')
    response, code, headers = make_json_request("/backends/" .. tostring(escape(temp_json_body['backends'][1]['name'])))
    assert.same(200, code)
    return assert.same(response['data'], {
      'apple.com'
    })
  end)
  it("should flush db #flush_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    assert.same(200, code)
    assert.same(response, {
      message = "OK",
      data = {
        'rstudio.com:80'
      }
    })
    response, code, headers = make_json_request("/flush", "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    return assert.same(404, code)
  end)
  return it("should test healthcheck", function()
    local response, code, headers = make_json_request("/health")
    return assert.same(200, code)
  end)
end)
