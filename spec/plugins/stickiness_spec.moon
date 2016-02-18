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
    header: {}
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
        COOKIE: 'session'
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
        return {
            req: {
                header: headers
                parsed_url: url.parse(u)
            }
            cookies: {
                session: cookie
            }
        }

    it "should set sticky session cookie", () ->

        -- construct request
        request = new_request('http://example.com/foo/derp')

        -- construct session
        session = new_session('example.com/foo/', 12345, {{address: 'fake-server:8000'}})

        response = plugin.post(request, session, settings)

        cookie = "session=#{url.escape(base64.encode('fake-server:8000'))}; Path=/foo/; HttpOnly"
        assert.are.same(ngx.header['Set-Cookie'], cookie)

    it "should use existing sticky session cookie if its valid", () ->

        -- construct request
        request = new_request('http://example.com/foo/bar', base64.encode('fake-server:8000')) 

        -- construct a session
        session = new_session('example.com/', 12345, {{address: 'fake-server:8000'}, {address: 'another-fake-server:8000'}})

        response = plugin.post(request, session, settings)
        assert.are.same(ngx.header['Set-Cookie'], nil)

    it "should use valid servers in the sticky session cookie", () ->

        -- construct request
        request = new_request('http://example.com/', base64.encode('fake-server:8000'))

        -- construct session
        session = new_session('example.com', 12345, {{address: 'fake-server:8000'}})

        result = plugin.balance(request, session, settings)
        assert.are.same({address: 'fake-server:8000'}, result)

    it "should ignore invalid values in the session cookie", () ->

        -- construct request
        request = new_request('http://example.com/', "garbage cookie")

        -- construct session
        session = new_session('example.com', 12345, {{address: 'fake-server:8000'}})

        result = plugin.balance(request, session, settings)
        assert.are.same({{address: 'fake-server:8000'}}, result)
        assert.are.same(request.cookies['session'], nil)


    it "should ignore invalid servers in the sticky session cookie", () ->

        -- construct a request
        request = new_request('http://example.com/', base64.encode('another-fake-server:8000'))

        -- construct a session
        session = new_session('example.com', 12345, {{address: 'fake-server:8000'}})

        result = plugin.balance(request, session, settings)
        assert.are.same({{address: 'fake-server:8000'}}, result)
        assert.are.same(request.cookies['session'], nil)

