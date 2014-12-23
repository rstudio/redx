-- Template
-- THIS IS NOT A PLUGIN
-- This should only be used to create new plugins as a template
-- DO NOT RUN THIS WITHIN REDX

-- initialize our plugin
M = {} -- required

M.pre = (request, session, param) ->
    -- run first with frontend and backend names passed
    -- can be used for things like checking headers exist or authorization
    -- If you want to exit the request with a status code and message return the table
    -- return nil (or nothing at all) if you want to continue processing the request
    if session['frontend'] == session['backend']
        return status: 500, message: "The frontend is the backend, that makes no sense"

M.balance = (request, session, param) ->
    -- processes the list of available servers to reduce or pick the servers you want to proxy to
    -- when picking a server, return that server as a string value
    for server in *session['servers']
        if 'bogus' == server
            return server
    -- if you want to take essentially no action, just return the same list of servers
    return session['server']

M.post = (request, session, param) ->
    -- this is run after all the plugins have run their balance function
    -- useful if you want to capture the server the request is being sent to
    -- so you can write something to a cookie, or save the info to a db or whatever
    -- server will be nil if none was picked
    -- Similar to pre, if you return a table, it will be used to halt the request
    if session['server']
        request.session.server = session['server']

return M  -- required
