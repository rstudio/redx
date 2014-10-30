-- Least Probabilistic Score
-- This plugin is similar to least score, but instead always picking the server
-- with the least score, it picks randomly while giving weighted probabilities
-- based on server scores (least score has highest probability)

-- This is useful when the score values aren't up to date in real time. 
-- Saying you're updating the scores routinely every 5 minutes. Least score 
-- would send all traffic to the same server for 5 minutes. Probabilistic
-- least score, will spread traffic out across the servers depending on relative
-- score levels (lowest score has highest change, highest score has lowest 
-- or no chance)

-- This load balancing algorithm requires a backend config called "max_score"
-- to be set (only if in "least" mode) . If its not set, this algorithm will 
-- be skipped (only applies in cases where there are only two servers)
-- Also required is passing "least" or "most" as a parameter

M = {}

M.pre = (request, session, param) ->
    return nil

M.balance = (request, session, param) ->
    servers = session['servers']

    -- if param is not given correct, return all servers
    return servers if param != 'least' and param != 'most'

    if M.same_scores(servers)
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
            if param == 'least'
                available_score += (max_score - x['score'])
            else
                available_score += x['score']
        -- pick random number within total available score
        rand = math.random( 1, available_score )
        if param == 'least'
            first_server_score = (max_score - servers[1]['score'])
        else
            first_server_score = servers[1]['score']
        if rand <= first_server_score
            return servers[1]
        else
            return servers[2]
    else
        -- calculate probabilities based on servers' relativeness to highest score
        -- this is so we never send traffic to the highest scored server(s)

        -- get least connection probability relative to largest score
        most_score = nil
        least_score = nil
        available_upstreams = {}
        for s in *servers
            if most_score == nil or s['score'] > most_score
                most_score = s['score']
            if least_score == nil or up['score'] < least_score
                least_score = up['score']
            if param == 'least'
                available_upstreams = [ s for s in *servers when s['score'] < most_score ]
            else
                available_upstreams = [ s for s in *servers when s['score'] > least_score ]
                
        if #available_upstreams > 0
            available_score = 0
            for x in *available_upstreams
                if param == 'least'
                    available_score += (most_score - x['score'])
                else
                    available_score += x['score']
            rand = math.random( available_score )
            offset = 0
            for x in *available_upstreams
                if param == 'least'
                    value = (most_score - x['score'])
                else
                    value = x['score']
                if rand <= (value + offset)
                    return {x}
                offset += value
            return servers
        else
            -- all servers have the same score it seems
            return servers
        
M.post = (request, session, param) ->
    return nil

M.same_scores = (servers) ->
    -- check if all scores are equal to each other
    for i, s in ipairs servers
        if i > 1 and s['score'] != servers[i-1]['score']
            return false
    return true

return M
