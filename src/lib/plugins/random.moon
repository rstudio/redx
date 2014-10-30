-- Random
-- This plugin picks a random server to proxy to

M = {}

M.pre = (request, session, param) ->
    return nil

M.balance = (request, session, param) ->
    return session['servers'][ math.random( #session['servers'] ) ]

M.post = (request, session, param) ->
    return nil

return M
