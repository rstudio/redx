lapis = require "lapis"
import respond_to from require "lapis.application"
import from_json, unescape from require "lapis.util"

json_response = (@) ->
    json = {}
    json['message'] = @msg if @msg
    json['data'] = @resp if @resp
    return json

webserver = class extends lapis.Application
    '/health': respond_to {
        GET: =>
            redis.test(@)
            status: @status, json: json_response(@)
    }

    '/flush': respond_to {
        DELETE: =>
            redis.flush(@)
            status: @status, json: json_response(@)
    }

    '/orphans': respond_to {
        GET: =>
            redis.orphans(@)
            status: @status, json: json_response(@)
        DELETE: =>
            orphans = redis.orphans(@)
            redis.delete_batch_data(@, orphans)
            status: @status, json: json_response(@)
    }

    '/batch': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @body = from_json(k)
            unless @body
                @status = 400
                @msg = "Missing json body"
                library.log_err("Missing json body")
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

    '/backends/:name/config/:config': respond_to {
        GET: =>
            redis.get_config(@, unescape(@params.name), unescape(@params.config))
            status: @status, json: json_response(@)
    }

    '/backends/:name/config/:config/:value': respond_to {
        PUT: =>
            redis.set_config(@, unescape(@params.name), unescape(@params.config), unescape(@params.value))
            status: @status, json: json_response(@)
    }

    '/:type/:name/:value': respond_to {
        POST: =>
            redis.save_data(@, @params.type, unescape(@params.name), unescape(@params.value), 0, false)
            status: @status, json: json_response(@)
        PUT: =>
            redis.save_data(@, @params.type, unescape(@params.name), unescape(@params.value), 0, true)
            status: @status, json: json_response(@)
        DELETE: =>
            redis.delete_data(@, @params.type, unescape(@params.name), unescape(@params.value))
            status: @status, json: json_response(@)
    }

    '/:type/:name/:value/connections/:connections': respond_to {
        PUT: =>
            redis.save_data(@, @params.type, unescape(@params.name), unescape(@params.value), unescape(@params.connections), true)
            status: @status, json: json_response(@)
    }

lapis.serve(webserver)
