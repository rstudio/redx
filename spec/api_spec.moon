import load_test_server, close_test_server from require "lapis.spec.server"
import from_json, to_json, escape from require "lapis.util"

export inspect = require "inspect"
export http = require "socket.http"
export ltn12 = require "ltn12"

export json_body = from_json('{
    "frontends": [
        {
            "url": "localhost/search",
            "backend_name": "12345"
        },
        {
            "url": "test.com/menlo/park",
            "backend_name": "menlobackend"
        }
    ],
    "backends": [
        {
            "name": "12345",
            "servers": [
                ["duckduckgo.com:80", 10],
                ["google.com:80", 30]
            ]
        },
        {
            "name": "menlobackend",
            "servers": [
                "menloparkmuseum.org",
                "tesc.edu"
            ],
            "config": {
                "person": "Thomas Edison"
            }
        }
    ]
}')

table_length = (t) ->
  count = 0
  for item in *table
    count += 1
  return count

make_json_request = (url, method="GET", body=nil, port=8081) ->
    respbody = {}
    if body
        export body, code, headers, status = http.request {
            url: "http://localhost:#{port}#{url}",
            method: method,
            source: ltn12.source.string(to_json(json_body)),
            sink: ltn12.sink.table(respbody),
            headers: {
                'Content-Type': "application/json",
                'Content-Length': tostring(#to_json(json_body))
            }
        }
    else
        export body, code, headers, status = http.request {
            url: "http://localhost:#{port}#{url}",
            method: method,
            sink: ltn12.sink.table(respbody),
            headers: {
                'Content-Type': "application/json"
            }
        }
    response = from_json(table.concat(respbody))
    return response, code, headers

describe "redx_api", ->
    randomize!

    setup ->
        load_test_server!

    teardown ->
        make_json_request("/flush", "DELETE")
        close_test_server!

    before_each ->
        make_json_request("/flush", "DELETE")

    it "create a frontend #frontend_api", ->
        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}/mybackend", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}")
        assert.same 200, code
        assert.same response, { message: "OK", data: "mybackend" }

    it "get all frontends #frontend_api", ->
        response, code, headers = make_json_request("/batch", "POST", json_body)
        assert.same 200, code

        response, code, headers = make_json_request("/frontends")
        assert.same table_length(response['frontends']), table_length(json_body['frontends'])

    it "get 404 on invalid frontend #frontend_api", ->
        response, code, headers = make_json_request("/frontends/this_frontend_does_not_exist")
        assert.same 404, code

    it "should delete a frontend #frontend_api", ->
        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}/mybackend", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}")
        assert.same 200, code
        assert.same response, { message: "OK", data: "mybackend" }

        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}/mybackend", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}")
        assert.same 404, code

    it "create a backend #backend_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'rstudio.com:80' }, config: {} } }

    it "get all backends #backend_api", ->
        response, code, headers = make_json_request("/batch", "POST", json_body)
        assert.same 200, code

        response, code, headers = make_json_request("/backends")
        assert.same table_length(response['backends']), table_length(json_body['backends'])

    it "PUT replaces backend #backend_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/backends/5555/#{escape('shinyapps.io:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        table.sort(response['data']) if response['data']
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'rstudio.com:80', 'shinyapps.io:80' }, config: {} } }

        -- do PUT statement to replace whats in the backend with the new server
        response, code, headers = make_json_request("/backends/5555/#{escape('cran.rstudio.org:80')}", "PUT")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'cran.rstudio.org:80'}, config: {} } }

    it "get 404 on invalid backend #backend_api", ->
        response, code, headers = make_json_request("/backend/this_backend_does_not_exist")
        assert.same 404, code

    it "should delete a backend #backend_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/backends/5555/#{escape('shinyapps.io:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        table.sort(response['data']) if response['data']
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'rstudio.com:80', 'shinyapps.io:80' }, config: {} } }

        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'shinyapps.io:80'}, config: {} } }

    it "should delete all servers in a backend #backend_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/backends/5555/#{escape('shinyapps.io:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        table.sort(response['data']) if response['data']
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'rstudio.com:80', 'shinyapps.io:80' }, config: {} } }

        response, code, headers = make_json_request("/backends/5555", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 404, code

    it "should get 400 on batch POST with no body #batch_api", ->
        response, code, headers = make_json_request("/batch", "POST")
        assert.same 400, code
    
    it "should batch POST #batch_api", ->
        response, code, headers = make_json_request("/batch", "POST", json_body)
        assert.same 200, code

        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}")
        assert.same response, { message: "OK", data: "menlobackend" }

        response, code, headers = make_json_request("/backends/menlobackend")
        table.sort(response['data']) if response['data']
        assert.same response, { message: "OK", data: { servers: {"menloparkmuseum.org", "tesc.edu"}, config: { person: "Thomas Edison" } } }
        
        response, code, headers = make_json_request("/backends/menlobackend/config/person")
        assert.same 200, code
        assert.same response, { message: "OK", data: {person: "Thomas Edison"} }

    it "should batch PUT #batch_api", ->
        response, code, headers = make_json_request("/batch", "POST", json_body)
        assert.same 200, code

        -- check that the db was updated
        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}")
        assert.same response, { message: "OK", data: "menlobackend" }
        response, code, headers = make_json_request("/backends/menlobackend")
        table.sort(response['data']) if response['data']
        assert.same response, { message: "OK", data: { servers: {"menloparkmuseum.org", "tesc.edu"}, config: { person: "Thomas Edison" } } }

        -- update json_body
        temp_json_body = json_body
        temp_json_body['frontends'][1]['backend_name'] = '6757'
        temp_json_body['backends'][1]['servers'] = { 'apple.com' }

        response, code, headers = make_json_request("/batch", "PUT", temp_json_body)
        assert.same 200, code

        -- check that removed frontend and backends from json_body are not in redis db
        response, code, headers = make_json_request("/frontends/#{escape(temp_json_body['frontends'][1]['url'])}")
        assert.same 200, code
        assert.same response['data'], '6757'
        response, code, headers = make_json_request("/backends/#{escape(temp_json_body['backends'][1]['name'])}")
        assert.same 200, code
        assert.same response['data'], { servers: {'apple.com'}, config: {} }

    it "should flush db #flush_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { servers: {'rstudio.com:80'}, config: {} } }

        
        response, code, headers = make_json_request("/flush", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 404, code

    it "should test healthcheck", ->
        response, code, headers = make_json_request("/health")
        assert.same 200, code

    it "should get orphans #orphans_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/frontends/#{escape('foobar.com/path')}/foobar", "POST")
        assert.same 200, code

        response, code, headers = make_json_request("/orphans", "GET")
        assert.same 200, code
        assert.same response['data'], { backends: {{ name: '5555' }}, frontends: {{ url: 'foobar.com/path' }} }

    it "should delete orphans #orphans_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/frontends/#{escape('foobar.com/path')}/foobar", "POST")
        assert.same 200, code

        response, code, headers = make_json_request("/orphans", "DELETE")
        assert.same 200, code
        assert.same response['data'], { backends: {{ name: '5555' }}, frontends: {{ url: 'foobar.com/path' }} }

        response, code, headers = make_json_request("/backends/5555", "GET")
        assert.same 404, code
        response, code, headers = make_json_request("/frontends/#{escape('foobar.com/path')}", "GET")
        assert.same 404, code

    it "should create backend config #config_api", ->
        response, code, headers = make_json_request("/backends/5555/config/limit/5", "PUT")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555/config/limit", "GET")
        assert.same 200, code
        assert.same response['data'], { limit: '5' }

    it "Create backend and set score #score_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}/score/30", "PUT")
        assert.same 200, code
