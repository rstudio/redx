local M = { }
M.pre = function(request, session, param)
  return nil
end
M.balance = function(request, session, param)
  return session['servers'][math.random(#session['servers'])]
end
M.post = function(request, session, param)
  return nil
end
return M
