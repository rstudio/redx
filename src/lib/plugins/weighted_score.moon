-- Weighted Score
-- This plugin is similar to score, but instead always picking the server
-- with the least/most score, it picks randomly while weighting
-- based on server scores

-- This is useful when the score values aren't kept up to date in real time. 
-- Say you're updating the scores routinely every 5 minutes. Least score 
-- would send all traffic to the same server for 5 minutes. Weighted score,
-- will spread traffic out across the servers depending on relative scores

-- This load balancing algorithm requires a backend config called "max_score"
-- to be set (only if in "least" mode). If it is not set, this algorithm will 
-- be skipped (only applies in cases where there are only two servers)

-- Required is passing "least" or "most" as a parameter

M = {}

M.balance = (request, session, param) ->
    servers = session['servers']

    -- if param is not given correct, return all servers
    if param != 'least' and param != 'most'
        library.log_err("Weighted score requires a parameter or 'least' or 'most")
        return servers

    if M.same_scores(servers)
        -- if all servers have the same score, we can't pick a weighted server
        -- because it would be equal to random, in that case, let the random plugin do it
        return servers

    if #servers == 2
        -- calculate probabilities based on servers' relativeness to max score

        if param == 'least'
            -- if max score configuration isn't set, we can't calculate the probablistic least
            max_score = session['config']['max_score']
            if max_score == nil
                return servers
            else
                max_score == tonumber(max_score)
        -- get total number of available score
        available_score = 0
        for x in *servers
            x['score'] = most_score - x['score'] if param == 'least'
            available_score += x['score']
        -- pick random number within total available score
        rand = math.random( 1, available_score )
        if param == 'least'
            export first_server_score = (max_score - servers[1]['score'])
        else
            export first_server_score = servers[1]['score']
        if rand <= first_server_score
            return servers[1]
        else
            return servers[2]
    else
        -- calculate probabilities based on servers' relativeness to highest score
        -- this is so we never send traffic to the highest scored server(s)

        -- get least connection probability relative to largest score
        most_score, least_score, available_upstreams = nil, nil, {}
        for s in *servers
            if most_score == nil or s['score'] > most_score
                most_score = s['score']
            if least_score == nil or s['score'] < least_score
                least_score = s['score']
            if param == 'least'
                available_upstreams = [ s for s in *servers when s['score'] < most_score ]
            else
                available_upstreams = [ s for s in *servers when s['score'] > least_score ]
                
        if #available_upstreams > 0
            available_score = 0
            for x in *available_upstreams
                x['score'] = most_score - x['score'] if param == 'least'
                available_score += x['score']
            rand = math.random( available_score )
            offset = 0
            for x in *available_upstreams
                x['score'] = (most_score - x['score']) if param == 'least'
                return {x} if rand <= (x['score'] + offset)
                offset += x['score']
            return servers
        else
            -- all servers have the same score it seems
            return servers
        
M.same_scores = (servers) ->
    -- check if all scores are equal to each other
    for i, s in ipairs servers
        if i > 1 and s['score'] != servers[i-1]['score']
            return false
    return true

return M
