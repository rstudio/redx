local M = { }
M.balance = function(request, session, param)
  local servers = session['servers']
  if param ~= 'least' and param ~= 'most' then
    library.log_err("Weighted score requires a parameter or 'least' or 'most")
    return servers
  end
  if M.same_scores(servers) then
    return servers
  end
  if #servers == 2 then
    if param == 'least' then
      local max_score = session['config']['max_score']
      if max_score == nil then
        return servers
      else
        local _ = max_score == tonumber(max_score)
      end
    end
    local available_score = 0
    for _index_0 = 1, #servers do
      local x = servers[_index_0]
      if param == 'least' then
        x['score'] = most_score - x['score']
      end
      available_score = available_score + x['score']
    end
    local rand = math.random(1, available_score)
    if param == 'least' then
      first_server_score = (max_score - servers[1]['score'])
    else
      first_server_score = servers[1]['score']
    end
    if rand <= first_server_score then
      return servers[1]
    else
      return servers[2]
    end
  else
    local most_score, least_score, available_upstreams = nil, nil, { }
    for _index_0 = 1, #servers do
      local s = servers[_index_0]
      if most_score == nil or s['score'] > most_score then
        most_score = s['score']
      end
      if least_score == nil or s['score'] < least_score then
        least_score = s['score']
      end
      if param == 'least' then
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_1 = 1, #servers do
            s = servers[_index_1]
            if s['score'] < most_score then
              _accum_0[_len_0] = s
              _len_0 = _len_0 + 1
            end
          end
          available_upstreams = _accum_0
        end
      else
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_1 = 1, #servers do
            s = servers[_index_1]
            if s['score'] > least_score then
              _accum_0[_len_0] = s
              _len_0 = _len_0 + 1
            end
          end
          available_upstreams = _accum_0
        end
      end
    end
    if #available_upstreams > 0 then
      local available_score = 0
      for _index_0 = 1, #available_upstreams do
        local x = available_upstreams[_index_0]
        if param == 'least' then
          x['score'] = most_score - x['score']
        end
        available_score = available_score + x['score']
      end
      local rand = math.random(available_score)
      local offset = 0
      for _index_0 = 1, #available_upstreams do
        local x = available_upstreams[_index_0]
        if param == 'least' then
          x['score'] = (most_score - x['score'])
        end
        if rand <= (x['score'] + offset) then
          return {
            x
          }
        end
        offset = offset + x['score']
      end
      return servers
    else
      return servers
    end
  end
end
M.same_scores = function(servers)
  for i, s in ipairs(servers) do
    if i > 1 and s['score'] ~= servers[i - 1]['score'] then
      return false
    end
  end
  return true
end
return M
