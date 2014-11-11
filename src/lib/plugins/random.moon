-- Random
-- This plugin picks a random server to proxy to

M = {}

M.balance = (request, session, param) ->
    return session['servers'][ math.random( #session['servers'] ) ]

return M
