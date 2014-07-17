export redis = require 'redis'
export inspect = require('inspect')

lapis = require "lapis"
import respond_to from require "lapis.application"
import from_json from require "lapis.util"

get_data = (@, input_data) ->
    @resp = {}
    red = redis.connect(@)
    if input_data["frontends"]
        @resp['frontends'] = {}
        for frontend in *input_data['frontends'] do
            @resp['frontends']["#{frontend['name']}"] = red\get('frontend:' .. frontend['name'])
    if input_data["backends"]
        @resp['backends'] = {}
        backend['backend'] = {backend['backend']} unless type(backend['backend']) == 'table' -- ensure backends given is a table
        for backend in *input_data['backends'] do
            @resp['backends']["#{backend['name']}"] = red\smembers('backend:' .. backend["name"])
    @msg = "OK"
    @status = 200

save_data = (@, data, overwrite=false) ->
    red = redis.connect(@)
    red\init_pipeline()
    if data["frontends"]
        for frontend in *data['frontends'] do
            red\del('frontend:' .. frontend['name']) if overwrite
            unless frontend['backend'] == nil
                print('adding frontend: ' .. frontend["name"] .. ' ' .. frontend['backend'])
                red\set('frontend:' .. frontend['name'], frontend['backend'])
    if data["backends"]
        for backend in *data['backends'] do
            red\del('backend:' .. backend["name"]) if overwrite
            backend['backend'] = {backend['backend']} unless type(backend['backend']) == 'table' -- ensure backends given is a table
            for host in *backend['backend']
                unless host == nil
                    print('adding backend: ' .. backend["name"] .. ' ' .. host)
                    red\sadd('backend:' .. backend["name"], host)
    redis.commit(@, red, "failed to save data: ")

delete_data = (@, data) ->
    print('pass delete')
    return nil

format_data = (typ=nil, name=nil, value=nil, body = nil) ->
    data = {}
    if typ == nil and name == nil and value == nil
        if body
            data = body
        else
            data = {}
    elseif typ and name == nil and value == nil
        if body
            data["#{typ}"] = body
        else
            data["#{typ}"] = {}
    elseif typ and name and value == nil
        if body['backend']
            data["#{typ}"] = {{name: "#{name}", backend: body['backend']}}
        else
            data["#{typ}"] = {{name: "#{name}", backend: nil}}
    else
        data["#{typ}"] = {{name:"#{name}", backend: "#{value}"}}
    return data

json_response = (@) ->
    json = {}
    json['message'] = @msg if @msg
    json['data'] = @resp if @resp
    return json

webserver = class extends lapis.Application
    '/': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            @input_data = format_data(nil, nil, nil, @body)
        GET: =>
            get_data(@, @input_data)
            status: @status, json: json_response(@)
        POST: =>
            save_data(@, @input_data, false)
            status: @status, json: json_response(@)
        PUT: =>
            save_data(@, @input_data, true)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_data(@, @input_data)
            status: @status, json: json_response(@)
    }

    '/:type': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            @input_data = format_data(@params.type, nil, nil, @body)
        GET: =>
            get_data(@, @input_data)
            status: @status, json: json_response(@)
        POST: =>
            save_data(@, @input_data, false)
            status: @status, json: json_response(@)
        PUT: =>
            save_data(@, @input_data, true)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_data(@, @input_data)
            status: @status, json: json_response(@)
    }

    '/:type/:name': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            @input_data = format_data(@params.type, @params.name, nil, @body)
        GET: =>
            get_data(@, @input_data)
            status: @status, json: json_response(@)
        POST: =>
            save_data(@, @input_data, false)
            status: @status, json: json_response(@)
        PUT: =>
            save_data(@, @input_data, true)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_data(@, @input_data)
            status: @status, json: json_response(@)
    }

    '/:type/:name/:value': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            @input_data = format_data(@params.type, @params.name, @params.value, @body)
        POST: =>
            save_data(@, @input_data, false)
            status: @status, json: json_response(@)
        PUT: =>
            save_data(@, @input_data, true)
            status: @status, json: json_response(@)
        DELETE: =>
            delete_data(@, @input_data)
            status: @status, json: json_response(@)
    }

lapis.serve(webserver)
