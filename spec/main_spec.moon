import load_test_server, close_test_server from require "lapis.spec.server"
import to_json, from_json, escape from require "lapis.util"

export inspect = require "inspect"
export http = require "socket.http"
export ltn12 = require "ltn12"

export json_body = from_json('{
    "frontends": [
        {
            "url": "myserver.com/contact",
            "backend_name": "12345"
        }
    ],
    "backends": [
        {
            "name": "12345",
            "servers": [
                "apple.com:80",
                "rstudio.com:80"
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

make_request = (url, host='myserver.com', method="GET", port=8080) ->
    respbody = {}
    body, code, headers, status = http.request {
        url: "http://localhost:#{port}#{url}",
        method: method,
        sink: ltn12.sink.table(respbody),
        headers: {
            "Host": host
        }
    }
    response = table.concat(respbody)
    return response, code, headers

describe "redx_main", ->
    randomize!

    setup ->
        load_test_server!

    teardown ->
        make_json_request("/flush", "DELETE")
        close_test_server!

    before_each ->
        response, code, headers = make_json_request("/batch", "PUT", json_body)

    it "make regular request", ->
        response, code, headers = make_request("/contact")
        assert.are_not.equals 404, code

    it "make regular invalid request", ->
        response, code, headers = make_request("/bad_url")
        assert.same 502, code

    it "make request to bad host", ->
        -- replace servers with a bad server with a closed port
        json_body['backends'][1]['servers'] = { "rstudio.com:9844" }
        response, code, headers = make_json_request("/batch", "PUT", json_body)
        response, code, headers = make_request("/contact")
        assert.same 502, code
