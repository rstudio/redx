lapis = require "lapis"
import respond_to from require "lapis.application"
import from_json, unescape from require "lapis.util"

class extends lapis.Application
    '/test': respond_to {
        GET: =>
            {'status': 200}
    }

    '/health': respond_to {
        GET: =>
            library.response(redis.test())
    }

    '/flush': respond_to {
        DELETE: =>
            library.response(redis.flush())
    }

    '/orphans': respond_to {
        GET: =>
            library.response(redis.orphans())
        DELETE: =>
            library.response(redis.delete_batch_data(redis.orphans()['data']))
    }

    '/batch': respond_to {
        before: =>
            for k,v in pairs @req.params_post do
                @json_body = from_json(k)
        POST: =>
            return library.response(status: 400, msg: "Missing json body") unless @json_body
            library.response(redis.save_batch_data(@json_body, false))
        PUT: =>
            return library.response(status: 400, msg: "Missing json body") unless @json_body
            library.response(redis.save_batch_data(@json_body, true))
        DELETE: =>
            return library.response(status: 400, msg: "Missing json body") unless @json_body
            library.response(redis.delete_batch_data(@json_body))
    }

    '/frontends': respond_to {
        GET: =>
            library.response(redis.get_data('frontends', nil))
    }

    '/backends': respond_to {
        GET: =>
            library.response(redis.get_data('backends', nil))
    }

    '/:type/:name': respond_to {
        GET: =>
            library.response(redis.get_data(@params.type, unescape(@params.name)))
        DELETE: =>
            library.response(redis.delete_data(@params.type, unescape(@params.name)))
    }

    '/backends/:name/config/:config': respond_to {
        GET: =>
            library.response(redis.get_config(unescape(@params.name), unescape(@params.config)))
        DELETE: =>
            library.response(redis.delete_config(unescape(@params.name), unescape(@params.config)))
    }

    '/backends/:name/config/:config/:value': respond_to {
        PUT: =>
            library.response(redis.set_config(unescape(@params.name), unescape(@params.config), unescape(@params.value)))
    }

    '/backends/:name/:value/score/:score': respond_to {
        PUT: =>
            library.response(redis.save_data('backends', unescape(@params.name), unescape(@params.value), unescape(@params.score), false))
    }

    '/:type/:name/:value': respond_to {
        POST: =>
            library.response(redis.save_data(@params.type, unescape(@params.name), unescape(@params.value), 0, false))
        PUT: =>
            library.response(redis.save_data(@params.type, unescape(@params.name), unescape(@params.value), 0, true))
        DELETE: =>
            library.response(redis.delete_data(@params.type, unescape(@params.name), unescape(@params.value)))
    }
