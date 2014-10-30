-- Score
-- This plugin picks the server with the least or most score value (depending
-- on configuration)

-- Requires the paramter to be either "least" or "most"

M = {}

M.pre = (request, session, param) ->
    return nil

M.balance = (request, session, param) ->
    servers = session['servers']
    return servers if param != 'least' and param != 'most'

    upstreams = {}
    score = 0
    for server in *servers
        if #upstreams == 0 or score == server['score']
            table.insert(upstreams, server)
            score = server['score']
        elseif param == 'least' and score > server['score']
            upstreams = {server}
            score = server['score']
        elseif param == 'most' and score < server['score']
            upstreams = {server}
            score = server['score']
    return upstreams

M.post = (request, session, param) ->
    return nil

return M
