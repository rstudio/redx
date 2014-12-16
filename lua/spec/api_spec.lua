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
json_body = from_json('{\n    "frontends": [\n        {\n            "url": "localhost/search",\n            "backend_name": "12345"\n        },\n        {\n            "url": "test.com/menlo/park",\n            "backend_name": "menlobackend"\n        }\n    ],\n    "backends": [\n        {\n            "name": "12345",\n            "servers": [\n                ["duckduckgo.com:80", 10],\n                ["google.com:80", 30]\n            ]\n        },\n        {\n            "name": "menlobackend",\n            "servers": [\n                "menloparkmuseum.org",\n                "tesc.edu"\n            ],\n            "config": {\n                "person": "Thomas Edison"\n            }\n        }\n    ]\n}')
local table_length
table_length = function(t)
  local count = 0
  local _list_0 = table
  for _index_0 = 1, #_list_0 do
    local item = _list_0[_index_0]
    count = count + 1
  end
  return count
end
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
  it("get all frontends #frontend_api", function()
    local response, code, headers = make_json_request("/batch", "POST", json_body)
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends")
    return assert.same(table_length(response['frontends']), table_length(json_body['frontends']))
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
        servers = {
          'rstudio.com:80'
        },
        config = { }
      }
    })
  end)
  it("get all backends #backend_api", function()
    local response, code, headers = make_json_request("/batch", "POST", json_body)
    assert.same(200, code)
    response, code, headers = make_json_request("/backends")
    return assert.same(table_length(response['backends']), table_length(json_body['backends']))
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
        servers = {
          'rstudio.com:80',
          'shinyapps.io:80'
        },
        config = { }
      }
    })
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('cran.rstudio.org:80')), "PUT")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = {
        servers = {
          'cran.rstudio.org:80'
        },
        config = { }
      }
    })
  end)
  it("get 404 on invalid backend #backend_api", function()
    local response, code, headers = make_json_request("/backends/this_backend_does_not_exist")
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
        servers = {
          'rstudio.com:80',
          'shinyapps.io:80'
        },
        config = { }
      }
    })
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = {
        servers = {
          'shinyapps.io:80'
        },
        config = { }
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
        servers = {
          'rstudio.com:80',
          'shinyapps.io:80'
        },
        config = { }
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
    assert.same(response, {
      message = "OK",
      data = {
        servers = {
          "menloparkmuseum.org",
          "tesc.edu"
        },
        config = {
          person = "Thomas Edison"
        }
      }
    })
    response, code, headers = make_json_request("/backends/menlobackend/config/person")
    assert.same(200, code)
    return assert.same(response, {
      message = "OK",
      data = "Thomas Edison"
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
        servers = {
          "menloparkmuseum.org",
          "tesc.edu"
        },
        config = {
          person = "Thomas Edison"
        }
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
      servers = {
        'apple.com'
      },
      config = { }
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
        servers = {
          'rstudio.com:80'
        },
        config = { }
      }
    })
    response, code, headers = make_json_request("/flush", "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555")
    return assert.same(404, code)
  end)
  it("should test healthcheck", function()
    local response, code, headers = make_json_request("/health")
    return assert.same(200, code)
  end)
  it("should get orphans #orphans_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('foobar.com/path')) .. "/foobar", "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/orphans", "GET")
    assert.same(200, code)
    return assert.same(response['data'], {
      backends = {
        {
          name = '5555'
        }
      },
      frontends = {
        {
          url = 'foobar.com/path'
        }
      }
    })
  end)
  it("should delete orphans #orphans_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')), "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('foobar.com/path')) .. "/foobar", "POST")
    assert.same(200, code)
    response, code, headers = make_json_request("/orphans", "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555", "GET")
    assert.same(404, code)
    response, code, headers = make_json_request("/frontends/" .. tostring(escape('foobar.com/path')), "GET")
    return assert.same(404, code)
  end)
  it("should create backend config #config_api", function()
    local response, code, headers = make_json_request("/backends/5555/config/limit/5", "PUT")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/config/limit", "GET")
    assert.same(200, code)
    return assert.same(response['data'], '5')
  end)
  it("should delete backend config #config_api", function()
    local response, code, headers = make_json_request("/backends/5555/config/limit/5", "PUT")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/config/limit", "GET")
    assert.same(200, code)
    assert.same(response['data'], '5')
    response, code, headers = make_json_request("/backends/5555/config/limit", "DELETE")
    assert.same(200, code)
    response, code, headers = make_json_request("/backends/5555/config/limit", "GET")
    return assert.same(404, code)
  end)
  return it("Create backend and set score #score_api", function()
    local response, code, headers = make_json_request("/backends/5555/" .. tostring(escape('rstudio.com:80')) .. "/score/30", "PUT")
    return assert.same(200, code)
  end)
end)
