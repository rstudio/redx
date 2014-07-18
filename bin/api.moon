export redis = require 'redis'
export inspect = require('inspect')

lapis = require "lapis"
import respond_to from require "lapis.application"
import from_json from require "lapis.util"

get_data = (@, asset_type, asset_name) ->
    red = redis.connect(@)
    switch asset_type
        when 'frontends'
            @resp, @msg = red\get('frontend:' .. asset_name)
            @status = 500 unless @resp
        when 'backends'
            @resp, @msg = red\smembers('backend:' .. asset_name)
        else
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if @resp
        @resp = nil if type(@resp) == 'table' and table.getn(@resp) == 0
        @status = 200
        @msg = "OK"
    else
        @status = 500 unless @status
        @msg = 'Unknown failutre' unless @msg
    red\close()

save_data = (@, asset_type, asset_name, asset_value, overwrite=false) ->
    red = redis.connect(@)
    switch asset_type
        when 'frontends'
            ok, err = red\set('frontend:' .. asset_name, asset_value)
        when 'backends'
            red = redis.connect(@)
            red\init_pipeline() if overwrite
            red\del('backend:' .. asset_name) if overwrite
            ok, err = red\sadd('backend:' .. asset_name, asset_value)
            redis.commit(@, red, "Failed to save backend: ") if overwrite
        else
            ok = false
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if ok == nil
        @status = 200
        @msg = "OK"
    else
        @status = 500
        err = "unknown" if err == nil
        @msg = "Failed to save backend: " .. err
    red\close()

delete_data = (@, asset_type, asset_name, asset_value=nil) ->
    red = redis.connect(@)
    switch asset_type
        when 'frontends'
            resp, @msg = red\del('frontend:' .. asset_name)
            @status = 500 unless @resp
        when 'backends'
            if asset_value == nil
                resp, @msg = red\del('backend:' .. asset_name)
            else
                resp, @msg = red\srem('backend:' .. asset_name, asset_value)
        else
            @status = 400
            @msg = 'Bad asset type. Must be "frontends" or "backends"'
    if resp == nil
        @resp = nil if type(@resp) == 'table' and table.getn(@resp) == 0
        @status = 200
        @msg = "OK" unless @msg
    else
        @status = 500 unless @status
        @msg = 'Unknown failutre' unless @msg
    red\close()

save_batch_data = (@, data, overwrite=false) ->
    red = redis.connect(@)
    red\init_pipeline()
    if data['frontends']
        for frontend in *data['frontends'] do
            print(inspect(frontend))
            red\del('frontend:' .. frontend['url']) if overwrite
            unless frontend['backend_name'] == nil
                print('adding frontend: ' .. frontend['url'] .. ' ' .. frontend['backend_name'])
                red\set('frontend:' .. frontend['url'], frontend['backend_name'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if overwrite
            -- ensure upstreams are a table
            backend['upstreams'] = {backend['upstreams']} unless type(backend['upstreams']) == 'table'
            for upstream in *backend['upstreams']
                unless upstream == nil
                    print('adding backend: ' .. backend["name"] .. ' ' .. upstream)
                    red\sadd('backend:' .. backend["name"], upstream)
    redis.commit(@, red, "failed to save data: ")

json_response = (@) ->
    json = {}
    json['message'] = @msg if @msg
    json['data'] = @resp if @resp
    return json

webserver = class extends lapis.Application
    '/batch': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            print(inspect(@body))
        POST: =>
            save_batch_data(@, @body, false)
            status: @status, json: json_response(@)
        PUT: =>
            save_batch_data(@, @body, true)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_batch_data(@, @body)
            status: @status, json: json_response(@)
    }

    '/:type/:name': respond_to {
        GET: =>
            get_data(@, @params.type, @params.name)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_data(@, @params.type, @params.name)
            status: @status, json: json_response(@)
    }

    '/:type/:name/:value': respond_to {
        POST: =>
            save_data(@, @params.type, @params.name, @params.value, false)
            status: @status, json: json_response(@)
        PUT: =>
            save_data(@, @params.type, @params.name, @params.value, true)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_data(@, @params.type, @params.name, @params.value)
            status: @status, json: json_response(@)
    }

lapis.serve(webserver)
