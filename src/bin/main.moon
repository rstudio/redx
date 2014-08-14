lapis = require "lapis"

lapis_config = require "lapis.config"

lapis_config.config "production", ->
  session_name "redx_session"
  secret config.cookie_secret

lapis_config.config "development", ->
  session_name "redx_session"
  secret config.cookie_secret

process_request = (@) ->
    frontend = redis.fetch_frontend(@, config.max_path_length)
    if frontend == nil
        ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "false")
    else
        ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "true")
        ngx.req.set_header("X-Redx-Frontend-Name", frontend['frontend_key'])
        ngx.req.set_header("X-Redx-Backend-Name", frontend['backend_key'])
        server = redis.fetch_server(@, frontend['backend_key'], false)
        if server == nil
            ngx.req.set_header("X-Redx-Backend-Cache-Hit", "false")
        else
            ngx.req.set_header("X-Redx-Backend-Cache-Hit", "true")
            ngx.req.set_header("X-Redx-Backend-Server", server)
            library.log("SERVER: " .. server)
            ngx.var.upstream = server

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
        "Max-Age=#{config.stickiness}; Path=#{p}; HttpOnly"

    '/': =>
        process_request(@)
        layout: false

    default_route: =>
        process_request(@)
        layout: false

lapis.serve(webserver)
