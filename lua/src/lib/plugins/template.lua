local M = { }
M.pre = function(request, session, param)
  if session['frontend'] == session['backend'] then
    return {
      status = 500,
      message = "The frontend is the backend, that makes no sense"
    }
  end
end
M.balance = function(request, session, param)
  local _list_0 = session['servers']
  for _index_0 = 1, #_list_0 do
    local server = _list_0[_index_0]
    if 'bogus' == server then
      return server
    end
  end
  return session['server']
end
M.post = function(request, session, param)
  if session['server'] then
    request.session.server = session['server']
  end
end
return M
