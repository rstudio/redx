-- Stickiness 
-- This plugin tries to send the same requester to the same backend each time by
-- saving which backend they were sent to last in a cookie.

M = {}

M.balance = (request, session, param) ->
    for server in *session['servers']
        if request.session.backend == M.extract_domain(server['address'])
            return server
    return session['servers']

M.post = (request, session, param) ->
    if session['server']
        -- update cookie
        request.session.backend = M.extract_domain(session['server'])

M.extract_domain = (url) ->
    if not string.match(url, '/')
        return url
    else
        location_index = string.find(url,'/')
        domain = string.sub(url, 1, (location_index - 1))
        return domain

return M
