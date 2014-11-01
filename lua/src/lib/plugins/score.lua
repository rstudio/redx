local M = { }
M.balance = function(request, session, param)
  local servers = session['servers']
  if param ~= 'least' and param ~= 'most' then
    return servers
  end
  local upstreams, score = { }, 0
  for _index_0 = 1, #servers do
    local server = servers[_index_0]
    if #upstreams == 0 or score == server['score'] then
      table.insert(upstreams, server)
      score = server['score']
    elseif param == 'least' and score > server['score'] then
      upstreams = {
        server
      }
      score = server['score']
    elseif param == 'most' and score < server['score'] then
      upstreams = {
        server
      }
      score = server['score']
    end
  end
  return upstreams
end
return M
