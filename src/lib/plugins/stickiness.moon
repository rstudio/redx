-- Stickiness 
-- This plugin tries to send the same requester to the same backend each time by
-- saving which backend they were sent to last in a cookie.

M = {}

M.balance = (request, session, param) ->
    for server in *session['servers']
        if request.session.backend == server['address']
            return server
    return session['servers']

M.post = (request, session, param) ->
    if session['server']
        -- update cookie
        request.session.backend = session['server']

return M
