export redis = require 'redis'

lapis = require "lapis"
import respond_to from require "lapis.application"

process_request = (@) ->
    frontend = redis.fetch_frontend(@, 3)
    if frontend == nil
        ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "false")
    else
        ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "true")
        ngx.req.set_header("X-Redx-Frontend-Name", frontend['frontend_key'])
        ngx.req.set_header("X-Redx-Backend-Name", frontend['backend_key'])
        upstream = redis.fetch_upstream(@, frontend['backend_key'], false)
        if upstream == nil
            ngx.req.set_header("X-Redx-Backend-Cache-Hit", "false")
        else
            ngx.req.set_header("X-Redx-Frontend-Cache-Hit", "true")
            ngx.req.set_header("X-Redx-Upstream", upstream)
            print("UPSTREAM: " .. upstream)
            ngx.var.upstream = upstream

webserver = class extends lapis.Application
    '/': =>
        process_request(@)
        layout: false

    default_route: =>
        process_request(@)
        layout: false

lapis.serve(webserver)
