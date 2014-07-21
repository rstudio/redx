export inspect = require('inspect')

lapis = require "lapis"
import respond_to from require "lapis.application"
import from_json, unescape from require "lapis.util"

json_response = (@) ->
    json = {}
    json['message'] = @msg if @msg
    json['data'] = @resp if @resp
    return json

webserver = class extends lapis.Application
    '/flush': respond_to {
        DELETE: =>
            redis.flush(@)
            status: @status, json: json_response(@)
    }

    '/batch': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            unless @body
                @status = 400
                @msg = "Missing json body"
        POST: =>
            redis.save_batch_data(@, @body, false) if @body
            status: @status, json: json_response(@)
        PUT: =>
            redis.save_batch_data(@, @body, true) if @body
            status: @status, json: json_response(@)
        DELETE: =>
            redis.delete_batch_data(@, @body) if @body
            status: @status, json: json_response(@)
    }

    '/:type/:name': respond_to {
        GET: =>
            redis.get_data(@, @params.type, unescape(@params.name))
            status: @status, json: json_response(@)
        DELETE: =>
            redis.delete_data(@, @params.type, unescape(@params.name))
            status: @status, json: json_response(@)
    }

    '/:type/:name/:value': respond_to {
        POST: =>
            redis.save_data(@, @params.type, unescape(@params.name), unescape(@params.value), false)
            status: @status, json: json_response(@)
        PUT: =>
            redis.save_data(@, @params.type, unescape(@params.name), unescape(@params.value), true)
            status: @status, json: json_response(@)
        DELETE: =>
            redis.delete_data(@, @params.type, unescape(@params.name), unescape(@params.value))
            status: @status, json: json_response(@)
    }

lapis.serve(webserver)
