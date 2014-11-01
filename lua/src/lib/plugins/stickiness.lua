local M = { }
M.balance = function(request, session, param)
  local _list_0 = session['servers']
  for _index_0 = 1, #_list_0 do
    local server = _list_0[_index_0]
    if request.session.backend == server['address'] then
      return server
    end
  end
  return session['servers']
end
M.post = function(request, session, param)
  if session['server'] then
    request.session.backend = session['server']
  end
end
return M
