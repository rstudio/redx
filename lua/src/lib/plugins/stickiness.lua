local M = { }
M.balance = function(request, session, param)
  local _list_0 = session['servers']
  for _index_0 = 1, #_list_0 do
    local server = _list_0[_index_0]
    if request.session.backend == M.extract_domain(server['address']) then
      return server
    end
  end
  return session['servers']
end
M.post = function(request, session, param)
  if session['server'] then
    request.session.backend = M.extract_domain(session['server'])
  end
end
M.extract_domain = function(url)
  if not string.match(url, '/') then
    return url
  else
    local location_index = string.find(url, '/')
    local domain = string.sub(url, 1, (location_index - 1))
    return domain
  end
end
return M
