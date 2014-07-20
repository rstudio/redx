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
                "google.com:80",
                "duckduckgo.com:80"
            ]
        },
        {
            "name": "menlobackend",
            "servers": [
                "menloparkmuseum.org",
                "tesc.edu"
            ]
        }
    ]
}')

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
        assert.same response, { message: "OK", data: { 'rstudio.com:80' } }

    it "PUT replaces backend #backend_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/backends/5555/#{escape('shinyapps.io:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { 'shinyapps.io:80', 'rstudio.com:80' } }

        -- do PUT statement to replace whats in the backend with the new server
        response, code, headers = make_json_request("/backends/5555/#{escape('cran.rstudio.org:80')}", "PUT")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { 'cran.rstudio.org:80' } }

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
        assert.same 200, code
        assert.same response, { message: "OK", data: { 'shinyapps.io:80', 'rstudio.com:80' } }

        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { 'shinyapps.io:80' } }

    it "should delete all servers in a backend #backend_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code
        response, code, headers = make_json_request("/backends/5555/#{escape('shinyapps.io:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { 'shinyapps.io:80', 'rstudio.com:80' } }

        response, code, headers = make_json_request("/backends/5555", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 404, code

    it "should get 400 on batch POST with no body #batch_api", ->
        pending('disabled')
        response, code, headers = make_json_request("/batch", "POST")
        assert.same 400, code
    
    it "should batch POST #batch_api", ->
        pending('disabled')
        response, code, headers = make_json_request("/batch", "POST", json_body)
        assert.same 200, code

        response, code, headers = make_json_request("/frontends/#{escape('test.com/menlo/park')}")
        assert.same response, { message: "OK", data: "menlobackend" }

        response, code, headers = make_json_request("/backends/menlobackend")
        assert.same response, { message: "OK", data: {"tesc.edu","menloparkmuseum.org"} }

    it "should flush db #flush_api", ->
        response, code, headers = make_json_request("/backends/5555/#{escape('rstudio.com:80')}", "POST")
        assert.same 200, code

        -- check its actually in the db correctly
        response, code, headers = make_json_request("/backends/5555")
        assert.same 200, code
        assert.same response, { message: "OK", data: { 'rstudio.com:80' } }

        
        response, code, headers = make_json_request("/flush", "DELETE")
        assert.same 200, code

        response, code, headers = make_json_request("/backends/5555")
        assert.same 404, code

