lapis = require "lapis"
import respond_to from require "lapis.application"
import from_json, unescape from require "lapis.util"

response = (t) ->
    -- close redis connection
    redis.finish(t['redis']) if t['redis']

    -- setup defaults
    response = status: 500, json: { message: "Unknown failure" }

    response['status'] = t['status'] if t['status']
    response['json']['message'] = t['msg'] if t['msg']
    response['json']['data'] = t['data'] if t['data']

    -- if a msg wasn't given and the status code is successful (ie 200's), assume msg is "OK"
    response['json']['message'] = "OK" if t['msg'] == nil and response['status'] < 300
    response['json']['message'] = "Entry does not exist" if t['msg'] == nil and response['status'] == 404

    -- log if theres a failure
    library.log_err(response) if response['status'] >= 300
    return response

webserver = class extends lapis.Application
    '/health': respond_to {
        GET: =>
            response(redis.test())
    }

    '/flush': respond_to {
        DELETE: =>
            response(redis.flush())
    }

    '/orphans': respond_to {
        GET: =>
            response(redis.orphans())
        DELETE: =>
            response(redis.delete_batch_data(redis.orphans()['data']))
    }

    '/batch': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @json_body = from_json(k)
        POST: =>
            return response(status: 400, msg: "Missing json body") unless @json_body
            response(redis.save_batch_data(@json_body, false))
        PUT: =>
            return response(status: 400, msg: "Missing json body") unless @json_body
            response(redis.save_batch_data(@json_body, true))
        DELETE: =>
            return response(status: 400, msg: "Missing json body") unless @json_body
            response(redis.delete_batch_data(@json_body))
    }

    '/frontends': respond_to {
        GET: =>
            response(redis.get_data('frontends', nil))
    }

    '/backends': respond_to {
        GET: =>
            response(redis.get_data('backends', nil))
    }

    '/:type/:name': respond_to {
        GET: =>
            response(redis.get_data(@params.type, unescape(@params.name)))
        DELETE: =>
            response(redis.delete_data(@params.type, unescape(@params.name)))
    }

    '/backends/:name/config/:config': respond_to {
        GET: =>
            response(redis.get_config(unescape(@params.name), unescape(@params.config)))
    }

    '/backends/:name/config/:config/:value': respond_to {
        PUT: =>
            response(redis.set_config(unescape(@params.name), unescape(@params.config), unescape(@params.value)))
    }

    '/backends/:name/:value/score/:score': respond_to {
        PUT: =>
            response(redis.save_data('backends', unescape(@params.name), unescape(@params.value), unescape(@params.score), false))
    }

    '/:type/:name/:value': respond_to {
        POST: =>
            response(redis.save_data(@params.type, unescape(@params.name), unescape(@params.value), 0, false))
        PUT: =>
            response(redis.save_data(@params.type, unescape(@params.name), unescape(@params.value), 0, true))
        DELETE: =>
            response(redis.delete_data(@params.type, unescape(@params.name), unescape(@params.value)))
    }

lapis.serve(webserver)
