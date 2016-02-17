-- include redx path
package.path = package.path .. ";lua/src/lib/?.lua;lua/src/lib/plugins/?.lua"

url = require 'socket.url'
inspect = require 'inspect'
base64 = require 'base64'
library = require 'library'  -- from redx

-- inspect module inserted into global env
_G.inspect = inspect

-- library module inserted into global env
_G.library = library

-- fake ngx module inserted into global env
_G.ngx = {
    DEBUG: 'DEBUG'
    NOTICE: 'NOTICE'
    WARN: 'WARN'
    ERR: 'ERROR'
    headers: {}
    log: (lvl, msg) ->
        print(lvl .. ": " .. msg)
    req: {
        clear_header: (h) ->
    }
}

-- load plugin
plugin = require "stickiness"

describe "stickiness plugin", ->
    randomize!

    -- initialize plugin settings
    settings = {
        COOKIE: 'shinyapps_session'
    }

    new_session = (frontend, backend, servers) ->
        m = math.huge
        for k in pairs(servers)
            m = math.min(k, m)

        return {
            frontend: frontend
            backend: backend
            servers: servers
            server: servers[m].address
            config: {
                shinyapps_auth: users
            }
        }

    new_request = (u, cookie=nil) ->
        if cookie != nil
            cookie = base64.encode(cookie)
        return {
            req: {
                headers: headers
                parsed_url: url.parse(u)
            }
            cookies: {
                shinyapps_session: cookie
            }
        }

    it "should set sticky session cookie", () ->

        -- construct an authenticated request
        request = new_request('http://example.com/foo/derp')

        -- construct a session
        session = new_session('example.com/foo/', 12345, {{address: 'localhost:12345'}})

        response = plugin.post(request, session, settings)

        assert.are.same(request.cookies['shinyapps_session'], "#{base64.encode('localhost:12345')}; Path=/foo/; HttpOnly")


    it "should use existing sticky session cookie if its valid", () ->

        cookie = "#{base64.encode('localhost:12345')}; Path=/; HttpOnly"

        -- construct an authenticated request
        request = new_request('http://example.com/foo/bar', cookie) 

        -- construct a session
        session = new_session('example.com/', 12345, {{address: 'localhost:12345'}, {address: 'localhost:56789'}})

        response = plugin.post(request, session, settings)

        assert.are.same(request.cookies['shinyapps_session'], cookie)

    it "should use valid servers in the sticky session cookie", () ->

        -- construct an authenticated request
        request = new_request('http://example.com/', 'localhost:12345')

        -- construct a session
        session = new_session('example.com', 12345, {{address: 'localhost:12345'}})

        result = plugin.balance(request, session, settings)
        assert.are.same({address: 'localhost:12345'}, result)

    it "should ignore invalid servers in the sticky session cookie", () ->

        -- construct an authenticated request
        request = new_request('http://example.com/', 'localhost:56789')

        -- construct a session
        session = new_session('example.com', 12345, {{address: 'localhost:12345'}})

        result = plugin.balance(request, session, settings)
        assert.are.same({{address: 'localhost:12345'}}, result)
        assert.are.same(request.cookies['shinyapps_session'], nil)

