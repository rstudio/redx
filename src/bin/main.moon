lapis = require "lapis"

lapis_config = require "lapis.config"

lapis_config.config "production", ->
  session_name "redx_session"
  secret config.cookie_secret

lapis_config.config "development", ->
  session_name "redx_session"
  secret config.cookie_secret

-- get request body, so we can make sure it gets forwarded to the upstream and lapis doesn't swallow it up
-- https://github.com/leafo/lapis/issues/161
ngx.req.read_body!
request_body = ngx.req.get_body_data!

process_request = (request) ->
    frontend = redis.fetch_frontend(request, config.max_path_length)
    if frontend == nil
        ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "false")
    else
        ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "true")
        ngx.req.set_header("X-Redx-Frontend-Name", frontend['frontend_key'])
        ngx.req.set_header("X-Redx-Backend-Name", frontend['backend_key'])
        backend = redis.fetch_backend(request, frontend['backend_key'])
        session = {
            frontend: frontend['frontend_key'],
            backend: frontend['backend_key'],
            servers: backend[1],
            config: backend[2],
            server: nil
        }
        if session['servers'] == nil
            ngx.req.set_header("X-Redx-Backend-Cache-Hit", "false")
        else
            -- run pre plugins
            for plugin in *plugins
                if (plugin['plugin']().pre)
                    response = plugin['plugin']().pre(request, session, plugin['param'])
                    if response != nil
                        return response

            -- run balance plugins
            for plugin in *plugins
                if (plugin['plugin']().balance)
                    session['servers'] = plugin['plugin']().balance(request, session, plugin['param'])
                    if type(session['servers']) == 'string'
                        session['server'] = session['servers']
                        break
                    elseif type(session['servers']['address']) == 'string'
                        session['server'] = session['servers']['address']
                        break
                    elseif #session['servers'] == 1
                        session['server'] = session['servers'][1]['address']
                        break
                    elseif session['servers'] == nil or #session['servers'] == 0
                        -- all servers were filterd out, do not proxy
                        session['server'] = nil
                        break

            -- run post plugin 
            for plugin in *plugins
                if (plugin['plugin']().post)
                    response = plugin['plugin']().post(request, session, plugin['param'])
                    if response != nil
                        return response

            if session['server'] != nil
                ngx.req.set_header("X-Redx-Backend-Cache-Hit", "true")
                ngx.req.set_header("X-Redx-Backend-Server", session['server'])
                library.log("SERVER: " .. session['server'])
                ngx.req.set_body_data = request_body
                request_body = nil -- clear body from memory (GC)
                ngx.var.upstream = session['server']
    return layout: false

webserver = class extends lapis.Application
    cookie_attributes: (name, value) =>
        path = @req.parsed_url['path']
        path_parts = library.split path, '/'
        p = ''
        count = 0
        for k,v in pairs path_parts do
            unless v == nil or v == ''
                if count < (config.max_path_length)
                    count += 1
                    p = p .. "/#{v}"
        if p == ''
            p = '/'
        "Max-Age=#{config.session_length}; Path=#{p}; HttpOnly"

    '/': =>
        process_request(@)

    default_route: =>
        process_request(@)

lapis.serve(webserver)
